import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacySettingsService extends ChangeNotifier {
  PrivacySettingsService._();

  static final PrivacySettingsService instance = PrivacySettingsService._();

  SupabaseClient get client => Supabase.instance.client;

  String profileVisibility = 'everyone';
  bool appearInSearch = true;

  bool showActivity = true;
  bool showWatchActivity = true;
  bool showRatingsActivity = true;
  bool showAchievementsActivity = true;

  bool showWatchStats = true;
  bool showGenreStats = true;
  bool showRatingStats = true;
  bool showProfileAchievements = true;
  bool showConnections = true;

  String followPermission = 'everyone';
  bool allowCommentReplies = true;
  bool featureSuggestionAttribution = true;

  bool loading = false;

  String? _loadedUserId;

  Future<void> ensureLoaded() async {
    final userId = client.auth.currentUser?.id;

    if (userId == null) {
      clear();
      return;
    }

    if (_loadedUserId == userId) {
      return;
    }

    await load();
  }

  Future<void> load() async {
    final user = client.auth.currentUser;

    if (user == null) {
      clear();
      return;
    }

    loading = true;
    notifyListeners();

    try {
      final row = await client
          .from('profiles')
          .select(
            'privacy_profile_visibility, '
            'privacy_appear_in_search, '
            'privacy_show_activity, '
            'privacy_show_watch_activity, '
            'privacy_show_ratings_activity, '
            'privacy_show_achievements_activity, '
            'privacy_show_watch_stats, '
            'privacy_show_genre_stats, '
            'privacy_show_rating_stats, '
            'privacy_show_profile_achievements, '
            'privacy_show_connections, '
            'privacy_follow_permission, '
            'privacy_allow_comment_replies, '
            'privacy_feature_suggestion_attribution',
          )
          .eq('id', user.id)
          .maybeSingle();

      profileVisibility =
          row?['privacy_profile_visibility']?.toString() ?? 'everyone';

      appearInSearch = row?['privacy_appear_in_search'] != false;

      showActivity = row?['privacy_show_activity'] != false;

      showWatchActivity = row?['privacy_show_watch_activity'] != false;

      showRatingsActivity = row?['privacy_show_ratings_activity'] != false;

      showAchievementsActivity =
          row?['privacy_show_achievements_activity'] != false;

      showWatchStats = row?['privacy_show_watch_stats'] != false;

      showGenreStats = row?['privacy_show_genre_stats'] != false;

      showRatingStats = row?['privacy_show_rating_stats'] != false;

      showProfileAchievements =
          row?['privacy_show_profile_achievements'] != false;

      showConnections = row?['privacy_show_connections'] != false;

      followPermission =
          row?['privacy_follow_permission']?.toString() ?? 'everyone';

      allowCommentReplies = row?['privacy_allow_comment_replies'] != false;

      featureSuggestionAttribution =
          row?['privacy_feature_suggestion_attribution'] != false;

      _loadedUserId = user.id;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _update(String column, Object? value) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    await client.from('profiles').update({column: value}).eq('id', user.id);
  }

  Future<void> setProfileVisibility(String value) async {
    if (!const {'everyone', 'followers', 'private'}.contains(value)) {
      throw Exception('Invalid profile visibility.');
    }

    await _update('privacy_profile_visibility', value);
    profileVisibility = value;
    notifyListeners();
  }

  Future<void> setAppearInSearch(bool value) async {
    await _update('privacy_appear_in_search', value);
    appearInSearch = value;
    notifyListeners();
  }

  Future<void> setShowActivity(bool value) async {
    await _update('privacy_show_activity', value);
    showActivity = value;
    notifyListeners();
  }

  Future<void> setShowWatchActivity(bool value) async {
    await _update('privacy_show_watch_activity', value);
    showWatchActivity = value;
    notifyListeners();
  }

  Future<void> setShowRatingsActivity(bool value) async {
    await _update('privacy_show_ratings_activity', value);
    showRatingsActivity = value;
    notifyListeners();
  }

  Future<void> setShowAchievementsActivity(bool value) async {
    await _update('privacy_show_achievements_activity', value);
    showAchievementsActivity = value;
    notifyListeners();
  }

  Future<void> setShowWatchStats(bool value) async {
    await _update('privacy_show_watch_stats', value);
    showWatchStats = value;
    notifyListeners();
  }

  Future<void> setShowGenreStats(bool value) async {
    await _update('privacy_show_genre_stats', value);
    showGenreStats = value;
    notifyListeners();
  }

  Future<void> setShowRatingStats(bool value) async {
    await _update('privacy_show_rating_stats', value);
    showRatingStats = value;
    notifyListeners();
  }

  Future<void> setShowProfileAchievements(bool value) async {
    await _update('privacy_show_profile_achievements', value);
    showProfileAchievements = value;
    notifyListeners();
  }

  Future<void> setShowConnections(bool value) async {
    await _update('privacy_show_connections', value);
    showConnections = value;
    notifyListeners();
  }

  Future<void> setFollowPermission(String value) async {
    if (!const {'everyone', 'people_i_follow', 'nobody'}.contains(value)) {
      throw Exception('Invalid follow permission.');
    }

    await _update('privacy_follow_permission', value);
    followPermission = value;
    notifyListeners();
  }

  Future<void> setAllowCommentReplies(bool value) async {
    await _update('privacy_allow_comment_replies', value);
    allowCommentReplies = value;
    notifyListeners();
  }

  Future<void> setFeatureSuggestionAttribution(bool value) async {
    await _update('privacy_feature_suggestion_attribution', value);
    featureSuggestionAttribution = value;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final rows = await client
        .from('user_blocks')
        .select('blocked_id, created_at')
        .eq('blocker_id', user.id)
        .order('created_at', ascending: false);

    final blockRows = List<Map<String, dynamic>>.from(rows);

    if (blockRows.isEmpty) {
      return [];
    }

    final ids = blockRows
        .map((row) => row['blocked_id']?.toString())
        .whereType<String>()
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final profiles = await client
        .from('profiles')
        .select('id, display_name, username, avatar_url')
        .inFilter('id', ids);

    final profileRows = List<Map<String, dynamic>>.from(profiles);

    final byId = <String, Map<String, dynamic>>{
      for (final profile in profileRows)
        if (profile['id'] != null) profile['id'].toString(): profile,
    };

    final result = <Map<String, dynamic>>[];

    for (final block in blockRows) {
      final id = block['blocked_id']?.toString();

      if (id == null) {
        continue;
      }

      final profile = byId[id];

      if (profile == null) {
        continue;
      }

      result.add({...profile, 'blocked_at': block['created_at']});
    }

    return result;
  }

  Future<void> blockUser(String userId) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    if (user.id == userId) {
      return;
    }

    await client.from('user_blocks').upsert({
      'blocker_id': user.id,
      'blocked_id': userId,
    });
  }

  Future<void> unblockUser(String userId) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    await client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', user.id)
        .eq('blocked_id', userId);
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    if (user.id == userId) {
      return;
    }

    await client.from('user_reports').insert({
      'reporter_id': user.id,
      'reported_user_id': userId,
      'reason': reason.trim(),
      'details': details?.trim(),
    });
  }

  Future<bool> canFollowUser(String userId) async {
    final result = await client.rpc(
      'can_follow_user',
      params: {'p_target_user_id': userId},
    );

    return result == true;
  }

  void clear() {
    profileVisibility = 'everyone';
    appearInSearch = true;

    showActivity = true;
    showWatchActivity = true;
    showRatingsActivity = true;
    showAchievementsActivity = true;

    showWatchStats = true;
    showGenreStats = true;
    showRatingStats = true;
    showProfileAchievements = true;
    showConnections = true;

    followPermission = 'everyone';
    allowCommentReplies = true;
    featureSuggestionAttribution = true;

    loading = false;
    _loadedUserId = null;

    notifyListeners();
  }
}
