import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A small, READ-ONLY, per-account library preview for the startup screen.
///
/// The normal LibraryService and Supabase remain the source of truth. This
/// snapshot must never be uploaded or used to initialize account state.
class StartupLibraryPreviewService {
  StartupLibraryPreviewService._();
  static final instance = StartupLibraryPreviewService._();

  static const _ownerKey = 'chiplux_startup_preview_verified_owner_v1';
  static const _snapshotPrefix = 'chiplux_startup_preview_v1_';
  static const _maxEntries = 250;

  Timer? _debounce;
  int _generation = 0;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> readForSignedInUser(String userId) async {
    if (_currentUserId != userId) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      // A snapshot belongs only to this verified authenticated user.
      if (_currentUserId != userId) return const [];
      final raw = prefs.getString('$_snapshotPrefix$userId');
      if (raw == null) return const [];
      final value = jsonDecode(raw);
      if (value is! List) return const [];
      return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (error) {
      debugPrint('Startup library preview unavailable: $error');
      return const [];
    }
  }

  Future<bool> hasSnapshotForUser(String userId) async {
    if (_currentUserId != userId) return false;
    final prefs = await SharedPreferences.getInstance();
    return _currentUserId == userId &&
        prefs.containsKey('$_snapshotPrefix$userId');
  }

  /// Populate the NEXT launch's read-only preview from cloud data when an
  /// account has no previous trusted snapshot. Do NOT claim local-data
  /// ownership: cloud read != reconciliation of unsynced local edits.
  Future<void> seedReadOnlyFromCloud(
    String userId, List<Map<String, dynamic>> entries,
  ) async {
    if (_currentUserId != userId) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId != userId ||
          prefs.containsKey('$_snapshotPrefix$userId')) {
        return;
      }
      await prefs.setString('$_snapshotPrefix$userId', jsonEncode(_limited(entries)));
    } catch (error) {
      debugPrint('Could not seed startup library preview: $error');
    }
  }

  // Called ONLY after cloud library/episode synchronization succeeds. This is
  // the trust boundary for an existing user's legacy, unscoped local data.
  Future<void> saveAfterVerifiedCloudSync(
    String userId,
    List<Map<String, dynamic>> entries,
  ) async {
    _debounce?.cancel();
    _generation++;
    if (_currentUserId != userId) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUserId != userId) return;
      await prefs.setString('$_snapshotPrefix$userId', jsonEncode(_limited(entries)));
      // Only this successful cloud sync establishes ownership of the local data.
      await prefs.setString(_ownerKey, userId);
    } catch (error) {
      debugPrint('Could not save verified library preview: $error');
    }
  }

  // Subsequent local edits can refresh the preview, but only for the account
  // previously verified via a completed cloud sync. Debouncing keeps it cheap.
  void scheduleForLocalEdit(List<Map<String, dynamic>> Function() snapshot) {
    final userId = _currentUserId;
    if (userId == null) return;
    _debounce?.cancel();
    final generation = ++_generation;
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_currentUserId != userId ||
            generation != _generation ||
            prefs.getString(_ownerKey) != userId) {
          return;
        }
        final json = jsonEncode(_limited(snapshot()));
        if (_currentUserId != userId || generation != _generation) return;
        await prefs.setString('$_snapshotPrefix$userId', json);
      } catch (error) {
        debugPrint('Could not refresh startup library preview: $error');
      }
    });
  }

  Future<void> removeForDeletedAccount(String? userId) async {
    if (userId == null) return;
    _debounce?.cancel();
    _generation++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_snapshotPrefix$userId');
    if (prefs.getString(_ownerKey) == userId) await prefs.remove(_ownerKey);
  }

  static List<Map<String, dynamic>> _limited(List<Map<String, dynamic>> entries) {
    final result = entries.toList()
      ..sort((a, b) => (int.tryParse(b['addedAt']?.toString() ?? '') ?? 0)
          .compareTo(int.tryParse(a['addedAt']?.toString() ?? '') ?? 0));
    return result.take(_maxEntries).toList();
  }
}
