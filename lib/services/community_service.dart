import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'privacy_settings_service.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;


  Future<List<Map<String, dynamic>>> _loadSafeProfiles(
    Iterable<String> userIds,
  ) async {
    final ids = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final raw = await client.rpc(
      'get_safe_profile_cards',
      params: {'p_user_ids': ids},
    );

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // =====================================================

  // FOLLOW / UNFOLLOW

  // =====================================================

  Future<bool> isFollowing(String userId) async {
    final user = currentUser;

    if (user == null) {
      return false;
    }

    final data = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', user.id)
        .eq('following_id', userId)
        .maybeSingle();

    return data != null;
  }

  Future<void> followUser(String userId) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    if (user.id == userId) {
      return;
    }

    await client.from('follows').upsert({
      'follower_id': user.id,

      'following_id': userId,
    });
  }

  Future<void> unfollowUser(String userId) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    await client
        .from('follows')
        .delete()
        .eq('follower_id', user.id)
        .eq('following_id', userId);
  }

  // =====================================================

  // FOLLOWERS

  // =====================================================

  Future<List<Map<String, dynamic>>> getFollowers({String? userId}) async {
    final targetUserId = userId ?? currentUser?.id;

    if (targetUserId == null) {
      return [];
    }

    final result = await client.rpc(
      'get_visible_followers',
      params: {'p_user_id': targetUserId},
    );

    if (result is! List) {
      return [];
    }

    return result
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // =====================================================

  // FOLLOWING

  // =====================================================

  Future<List<Map<String, dynamic>>> getFollowing() async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    final follows = await client
        .from('follows')
        .select('following_id, created_at')
        .eq('follower_id', user.id)
        .order('created_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(follows);

    if (rows.isEmpty) {
      return [];
    }

    final ids = rows
        .map((row) => row['following_id']?.toString())
        .whereType<String>()
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final profileRows = await _loadSafeProfiles(ids);

    final byId = <String, Map<String, dynamic>>{};

    for (final profile in profileRows) {
      final id = profile['id']?.toString();

      if (id != null) {
        byId[id] = profile;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      final id = row['following_id']?.toString();

      if (id == null) {
        continue;
      }

      final profile = byId[id];

      if (profile == null) {
        continue;
      }

      result.add({...profile, 'followed_at': row['created_at']});
    }

    return result;
  }

  // =====================================================

  // PROFILE LOOKUP

  // =====================================================

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final profiles = await _loadSafeProfiles([userId]);

    if (profiles.isEmpty) {
      return null;
    }

    return profiles.first;
  }

  // =====================================================

  // FRIENDS WATCH

  // =====================================================

  Future<List<Map<String, dynamic>>> getFriendsWatch({int limit = 100}) async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    final activity = await client.rpc(
      'get_visible_community_activity_v2',
      params: {'p_limit': limit},
    );

    if (activity is! List) {
      return [];
    }

    final rows = activity
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    if (rows.isEmpty) {
      return [];
    }

    final userIds = rows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    if (userIds.isEmpty) {
      return [];
    }

    final profileRows = await _loadSafeProfiles(userIds);

    final byId = <String, Map<String, dynamic>>{};

    for (final profile in profileRows) {
      final id = profile['id']?.toString();

      if (id != null) {
        byId[id] = profile;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      final id = row['user_id']?.toString();

      if (id == null) {
        continue;
      }

      result.add({...row, 'profile': byId[id]});
    }

    return result;
  }

  // =====================================================

  // CREATE ACTIVITY

  // =====================================================

  Future<void> createActivity({
    required String activityType,

    String? mediaType,

    int? tmdbId,

    String? mediaTitle,

    int? seasonNumber,

    int? episodeNumber,

    String? episodeTitle,

    int? ratingStars,

    String? achievementId,

    String? achievementTitle,

    String? externalId,

    String? parentExternalId,

    String? externalArtistId,

    String? externalArtistName,

    String? externalParentTitle,

    String? externalYear,

    List<String>? externalGenres,
  }) async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    final privacy = PrivacySettingsService.instance;

    await privacy.ensureLoaded();

    if (!privacy.showActivity) {
      return;
    }

    if (activityType == 'rated' && !privacy.showRatingsActivity) {
      return;
    }

    if (activityType == 'achievement_unlocked' &&
        !privacy.showAchievementsActivity) {
      return;
    }

    if (activityType != 'rated' &&
        activityType != 'achievement_unlocked' &&
        !privacy.showWatchActivity) {
      return;
    }

    await client.rpc(
      'record_my_community_activity',
      params: {
        'p_activity_type': activityType,
        'p_media_type': mediaType,
        'p_tmdb_id': tmdbId,
        'p_media_title': mediaTitle,
        'p_season_number': seasonNumber,
        'p_episode_number': episodeNumber,
        'p_episode_title': episodeTitle,
        'p_rating_stars': ratingStars,
        'p_achievement_id': achievementId,
        'p_achievement_title': achievementTitle,
        'p_external_id': externalId,
        'p_parent_external_id': parentExternalId,
        'p_external_artist_id': externalArtistId,
        'p_external_artist_name': externalArtistName,
        'p_external_parent_title': externalParentTitle,
        'p_external_year': externalYear,
        'p_external_genres': externalGenres ?? const <String>[],
      },
    );
  }

  // =====================================================

  // REMOVE MATCHING ACTIVITY

  // =====================================================

  Future<void> deleteActivity({
    required String activityType,

    String? mediaType,

    int? tmdbId,

    int? seasonNumber,

    int? episodeNumber,

    String? achievementId,

    String? externalId,

    String? parentExternalId,

    bool titleLevelOnly = false,
  }) async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    var query = client
        .from('community_activity')
        .delete()
        .eq('user_id', user.id)
        .eq('activity_type', activityType);

    if (mediaType != null) {
      query = query.eq('media_type', mediaType);
    }

    if (tmdbId != null) {
      query = query.eq('tmdb_id', tmdbId);
    }

    if (seasonNumber != null) {
      query = query.eq('season_number', seasonNumber);
    }

    if (episodeNumber != null) {
      query = query.eq('episode_number', episodeNumber);
    }

    if (titleLevelOnly) {
      query = query
          .isFilter('season_number', null)
          .isFilter('episode_number', null);
    }

    if (achievementId != null) {
      query = query.eq('achievement_id', achievementId);
    }

    if (externalId != null) {
      query = query.eq('external_id', externalId);
    }

    if (parentExternalId != null) {
      query = query.eq('parent_external_id', parentExternalId);
    }

    await query;
  }

  // =====================================================

  // SAFE BACKGROUND ACTIVITY

  // =====================================================

  Future<void> tryCreateActivity({
    required String activityType,

    String? mediaType,

    int? tmdbId,

    String? mediaTitle,

    int? seasonNumber,

    int? episodeNumber,

    String? episodeTitle,

    int? ratingStars,

    String? achievementId,

    String? achievementTitle,

    String? externalId,

    String? parentExternalId,

    String? externalArtistId,

    String? externalArtistName,

    String? externalParentTitle,

    String? externalYear,

    List<String>? externalGenres,
  }) async {
    try {
      await createActivity(
        activityType: activityType,

        mediaType: mediaType,

        tmdbId: tmdbId,

        mediaTitle: mediaTitle,

        seasonNumber: seasonNumber,

        episodeNumber: episodeNumber,

        episodeTitle: episodeTitle,

        ratingStars: ratingStars,

        achievementId: achievementId,

        achievementTitle: achievementTitle,

        externalId: externalId,

        parentExternalId: parentExternalId,

        externalArtistId: externalArtistId,

        externalArtistName: externalArtistName,

        externalParentTitle: externalParentTitle,

        externalYear: externalYear,

        externalGenres: externalGenres,
      );
    } catch (e) {
      debugPrint('Community activity failed: $e');
    }
  }
}
