import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataExportService {
  DataExportService._();
  static final DataExportService instance = DataExportService._();
  static const _cadenceKey = 'chiplux_backup_cadence_v1';
  static const _lastBackupKey = 'chiplux_last_backup_v1';
  SupabaseClient get client => Supabase.instance.client;

  Future<String> getCadence() async =>
      (await SharedPreferences.getInstance()).getString(_cadenceKey) ?? 'off';
  Future<void> setCadence(String value) async {
    if (!const {'off', 'daily', 'weekly', 'monthly'}.contains(value)) {
      throw Exception('Invalid backup frequency.');
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_cadenceKey, value);
    if (value == 'off') {
      await p.remove(_lastBackupKey);
    }
  }

  Future<Map<String, dynamic>> buildExport() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in.');
    }
    Future<List<dynamic>> rows(String table, String column) async =>
        List<dynamic>.from(
          await client.from(table).select().eq(column, user.id),
        );
    final profile = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final r = await Future.wait([
      rows('library_items', 'user_id'),
      rows('watched_episodes', 'user_id'),
      rows('media_user_data', 'user_id'),
      rows('episode_ratings', 'user_id'),
      rows('media_comments', 'user_id'),
      rows('comment_likes', 'user_id'),
      rows('community_activity', 'user_id'),
      rows('follows', 'follower_id'),
      rows('follows', 'following_id'),
      rows('user_blocks', 'blocker_id'),
      rows('notifications', 'recipient_user_id'),
      rows('user_reports', 'reporter_id'),
      rows('comment_reports', 'reporter_id'),
      rows('bug_reports', 'user_id'),
      rows('feature_suggestions', 'user_id'),
      rows('feature_suggestion_likes', 'user_id'),
      rows('feature_suggestion_comments', 'user_id'),
      rows('feature_suggestion_submission_state', 'user_id'),
    ]);
    return {
      'format': 'chiplux-export-v1',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'account': {'id': user.id, 'email': user.email},
      'profile': profile,
      'library_items': r[0],
      'watched_episodes': r[1],
      'media_user_data': r[2],
      'episode_ratings': r[3],
      'my_comments': r[4],
      'my_comment_likes': r[5],
      'my_activity': r[6],
      'following': r[7],
      'followers': r[8],
      'blocked_users': r[9],
      'notifications': r[10],
      'my_user_reports': r[11],
      'my_comment_reports': r[12],
      'my_bug_reports': r[13],
      'my_feature_suggestions': r[14],
      'my_feature_suggestion_likes': r[15],
      'my_feature_suggestion_updates': r[16],
      'feature_suggestion_submission_state': r[17],
    };
  }

  Future<File> createBackupFile() async {
    final data = await buildExport();
    final dir = await getApplicationDocumentsDirectory();
    final backup = Directory(
      '${dir.path}${Platform.pathSeparator}chiplux_backups',
    );
    if (!await backup.exists()) {
      await backup.create(recursive: true);
    }
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final f = File(
      '${backup.path}${Platform.pathSeparator}chiplux_export_$stamp.json',
    );
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    final p = await SharedPreferences.getInstance();
    await p.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
    return f;
  }

  Future<void> exportAndShare({
    required String subject,
    required String text,
  }) async {
    final f = await createBackupFile();
    await SharePlus.instance.share(
      ShareParams(subject: subject, text: text, files: [XFile(f.path)]),
    );
  }

  Future<void> maybeRunAutomaticBackup() async {
    if (client.auth.currentUser == null) {
      return;
    }
    final p = await SharedPreferences.getInstance();
    final c = p.getString(_cadenceKey) ?? 'off';
    if (c == 'off') {
      return;
    }
    final last = p.getInt(_lastBackupKey);
    final days = c == 'daily'
        ? 1
        : c == 'weekly'
        ? 7
        : c == 'monthly'
        ? 30
        : 0;
    if (days == 0) {
      return;
    }
    if (last != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
            Duration(days: days)) {
      return;
    }
    await createBackupFile();
  }
}
