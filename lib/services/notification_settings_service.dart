import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsService {
  NotificationSettingsService._();

  static final NotificationSettingsService instance =
      NotificationSettingsService._();

  final SupabaseClient client = Supabase.instance.client;

  bool newEpisodes = true;
  bool releaseReminders = true;
  bool commentsReplies = true;
  bool commentLikeMilestones = true;
  bool newFollowers = true;
  bool achievements = true;
  bool chipluxUpdates = true;

  Future<void> load() async {
    final user = client.auth.currentUser;

    if (user == null) {
      _setDefaults();
      return;
    }

    final row = await client
        .from('profiles')
        .select(
          'notify_new_episodes, '
          'notify_release_reminders, '
          'notify_comments_replies, '
          'notify_comment_like_milestones, '
          'notify_new_followers, '
          'notify_achievements, '
          'notify_chiplux_updates',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      _setDefaults();
      return;
    }

    newEpisodes =
        row['notify_new_episodes'] as bool? ?? true;

    releaseReminders =
        row['notify_release_reminders'] as bool? ?? true;

    commentsReplies =
        row['notify_comments_replies'] as bool? ?? true;

    commentLikeMilestones =
        row['notify_comment_like_milestones'] as bool? ?? true;

    newFollowers =
        row['notify_new_followers'] as bool? ?? true;

    achievements =
        row['notify_achievements'] as bool? ?? true;

    chipluxUpdates =
        row['notify_chiplux_updates'] as bool? ?? true;
  }

  void _setDefaults() {
    newEpisodes = true;
    releaseReminders = true;
    commentsReplies = true;
    commentLikeMilestones = true;
    newFollowers = true;
    achievements = true;
    chipluxUpdates = true;
  }

  Future<void> _update(
    String column,
    bool value,
  ) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    await client
        .from('profiles')
        .update({
          column: value,
        })
        .eq('id', user.id);
  }

  Future<void> setNewEpisodes(bool value) async {
    await _update(
      'notify_new_episodes',
      value,
    );

    newEpisodes = value;
  }

  Future<void> setReleaseReminders(bool value) async {
    await _update(
      'notify_release_reminders',
      value,
    );

    releaseReminders = value;
  }

  Future<void> setCommentsReplies(bool value) async {
    await _update(
      'notify_comments_replies',
      value,
    );

    commentsReplies = value;
  }

  Future<void> setCommentLikeMilestones(
    bool value,
  ) async {
    await _update(
      'notify_comment_like_milestones',
      value,
    );

    commentLikeMilestones = value;
  }

  Future<void> setNewFollowers(bool value) async {
    await _update(
      'notify_new_followers',
      value,
    );

    newFollowers = value;
  }

  Future<void> setAchievements(bool value) async {
    await _update(
      'notify_achievements',
      value,
    );

    achievements = value;
  }

  Future<void> setChipluxUpdates(bool value) async {
    await _update(
      'notify_chiplux_updates',
      value,
    );

    chipluxUpdates = value;
  }
}