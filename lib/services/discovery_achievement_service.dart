import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_service.dart';
import 'music_user_data_service.dart';

/// Records discovery provenance separately from a media item's library status.
/// An item qualifies only after it has been opened from the indicated section
/// and subsequently completed/listened to. Repeated opens never add progress.
class DiscoveryAchievementService extends ChangeNotifier {
  DiscoveryAchievementService._() {
    LibraryService.instance.addListener(_reconcileCompletion);
    MusicUserDataService.instance.addListener(_reconcileCompletion);
  }

  static final DiscoveryAchievementService instance =
      DiscoveryAchievementService._();

  static const forYouMovies = 'for_you_movies';
  static const forYouAlbums = 'for_you_albums';
  static const birthdays = 'birthdays_checked';
  static const memorials = 'memorials_checked';
  static const allTimeMovies = 'all_time_movies';
  static const allTimeTv = 'all_time_tv';
  static const genreAlbums = 'genre_top_albums';

  static const Set<String> categories = {
    forYouMovies, forYouAlbums, birthdays, memorials,
    allTimeMovies, allTimeTv, genreAlbums,
  };

  final Map<String, Map<String, bool>> _entries = {};
  String? _accountId;
  SharedPreferences? _preferences;
  Future<void> _writeQueue = Future<void>.value();

  String? get _signedInId => Supabase.instance.client.auth.currentUser?.id;
  String _storageKey(String account) => 'chiplux_discovery_progress_v1:$account';

  int progress(String group) {
    if (_accountId == null || _accountId != _signedInId) return 0;
    return _entries[group]?.values.where((v) => v).length ?? 0;
  }

  Future<void> load() async {
    final userId = _signedInId;
    _accountId = userId;
    _entries.clear();
    _preferences = await SharedPreferences.getInstance();
    if (userId == null || _accountId != userId) {
      notifyListeners();
      return;
    }
    final local = _preferences?.getString(_storageKey(userId));
    if (local != null) {
      try {
        final decoded = jsonDecode(local);
        if (decoded is Map) {
          for (final groupEntry in decoded.entries) {
            final group = groupEntry.key.toString();
            if (!categories.contains(group) || groupEntry.value is! Map) continue;
            for (final entry in (groupEntry.value as Map).entries) {
              final id = entry.key.toString();
              if (id.isNotEmpty) {
                _entries.putIfAbsent(group, () => {})[id] = entry.value == true;
              }
            }
          }
        }
      } catch (_) {
        debugPrint('Discovery achievements: ignoring damaged local state.');
      }
    }
    notifyListeners();
    _reconcileCompletion();
    unawaited(_hydrateCloud(userId));
  }

  Future<void> _hydrateCloud(String userId) async {
    try {
      // Paginate: the default PostgREST result limit is 1000 rows.
      for (var offset = 0; ; offset += 500) {
        final rows = await Supabase.instance.client
            .from('chiplux_discovery_achievement_events')
            .select('group_id,entity_id,qualified')
            .eq('user_id', userId)
            .order('group_id')
            .order('entity_id')
            .range(offset, offset + 499);
        if (_accountId != userId || _signedInId != userId) return;
        for (final row in rows) {
          final group = row['group_id']?.toString() ?? '';
          final id = row['entity_id']?.toString() ?? '';
          if (categories.contains(group) && id.isNotEmpty) {
            final groupRows = _entries.putIfAbsent(group, () => {});
            groupRows[id] = (groupRows[id] == true) || row['qualified'] == true;
          }
        }
        if (rows.length < 500) break;
      }
    } catch (error) {
      // A not-yet-deployed migration or offline session must not break UI.
      debugPrint('Discovery achievements: cloud read unavailable: $error');
    }
    if (_accountId != userId || _signedInId != userId) return;
    _reconcileCompletion();
    notifyListeners();
    unawaited(_saveLocal());
    // Retry locally saved events that may not have reached Supabase.
    for (final group in _entries.keys.toList()) {
      for (final entry in _entries[group]!.entries.toList()) {
        _enqueueCloud(userId, group, entry.key, entry.value);
      }
    }
  }

  bool _completed(String group, String id) {
    if (group == forYouAlbums || group == genreAlbums) {
      return MusicUserDataService.instance.albumState(id).isListened;
    }
    final mediaType = group == allTimeTv ? 'tv' : 'movie';
    final mediaId = int.tryParse(id);
    if (mediaId == null) return false;
    return LibraryService.instance.getItem(mediaId, mediaType)?.status == 'completed';
  }

  /// Call when opening an eligible recommendation/list item, before navigating.
  void recordSource(String group, String id) {
    final userId = _signedInId;
    if (_accountId != userId || userId == null || id.isEmpty ||
        !categories.contains(group) || group == birthdays || group == memorials) {
      return;
    }
    final rows = _entries.putIfAbsent(group, () => {});
    if (rows.containsKey(id) || _completed(group, id)) return;
    rows[id] = false;
    unawaited(_saveLocal());
    _enqueueCloud(userId, group, id, false);
  }

  /// A spotlight counts once per unique TMDB person, not per tap or date.
  void recordSpotlight(String group, int personId) {
    final userId = _signedInId;
    if (_accountId != userId ||
    userId == null ||
    personId <= 0 ||
    (group != birthdays && group != memorials)) {
  return;
}
    final id = personId.toString();
    final rows = _entries.putIfAbsent(group, () => {});
    if (rows[id] == true) return;
    rows[id] = true;
    notifyListeners();
    unawaited(_saveLocal());
    _enqueueCloud(userId, group, id, true);
  }

  void _reconcileCompletion() {
    if (_accountId == null || _accountId != _signedInId) return;
    var changed = false;
    for (final group in [forYouMovies, forYouAlbums, allTimeMovies, allTimeTv, genreAlbums]) {
      final rows = _entries[group];
      if (rows == null) continue;
      for (final id in rows.keys.toList()) {
        if (rows[id] == false && _completed(group, id)) {
          rows[id] = true;
          changed = true;
          _enqueueCloud(_accountId!, group, id, true);
        }
      }
    }
    if (changed) {
      notifyListeners();
      unawaited(_saveLocal());
    }
  }

  Future<void> _saveLocal() async {
    final userId = _accountId;
    if (userId == null || userId != _signedInId) return;
    await _preferences?.setString(_storageKey(userId), jsonEncode(_entries));
  }

  void _enqueueCloud(String userId, String group, String id, bool qualified) {
    _writeQueue = _writeQueue.then((_) async {
      if (_signedInId != userId || _accountId != userId) return;
      // Use the latest state, never revert a completed item to pending.
      final latest = _entries[group]?[id] == true;
      try {
        await Supabase.instance.client.rpc('chiplux_record_discovery_achievement',
          params: {
            'p_group_id': group,
            'p_entity_id': id,
            'p_qualified': qualified || latest,
          });
      } catch (error) {
        debugPrint('Discovery achievement sync postponed: $error');
      }
    }).catchError((Object error) {
      debugPrint('Discovery achievement queue error: $error');
    });
  }
}
