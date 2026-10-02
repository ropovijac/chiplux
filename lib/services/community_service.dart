import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityService {
  CommunityService._();

  static final CommunityService instance = CommunityService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

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

    final follows = await client
        .from('follows')
        .select('follower_id, created_at')
        .eq('following_id', targetUserId)
        .order('created_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(follows);

    if (rows.isEmpty) {
      return [];
    }

    final ids = rows
        .map((row) => row['follower_id']?.toString())
        .whereType<String>()
        .toList();

    if (ids.isEmpty) {
      return [];
    }

    final profiles = await client
        .from('profiles')
        .select(
          'id, display_name, username, avatar_url, banner_tmdb_id, banner_media_type, banner_path',
        )
        .inFilter('id', ids);

    final profileRows = List<Map<String, dynamic>>.from(profiles);

    final byId = <String, Map<String, dynamic>>{};

    for (final profile in profileRows) {
      final id = profile['id']?.toString();

      if (id != null) {
        byId[id] = profile;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final row in rows) {
      final id = row['follower_id']?.toString();

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

    final profiles = await client
        .from('profiles')
        .select(
          'id, display_name, username, avatar_url, banner_tmdb_id, banner_media_type, banner_path',
        )
        .inFilter('id', ids);

    final profileRows = List<Map<String, dynamic>>.from(profiles);

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
    final data = await client
        .from('profiles')
        .select(
          'id, display_name, username, avatar_url, banner_tmdb_id, banner_media_type, banner_path',
        )
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  // =====================================================
  // FRIENDS WATCH
  // =====================================================

  Future<List<Map<String, dynamic>>> getFriendsWatch({int limit = 100}) async {
    final user = currentUser;

    if (user == null) {
      return [];
    }

    final activity = await client
        .from('community_activity')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    final rows = List<Map<String, dynamic>>.from(activity);

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

    final profiles = await client
        .from('profiles')
        .select('id, display_name, username, avatar_url')
        .inFilter('id', userIds);

    final profileRows = List<Map<String, dynamic>>.from(profiles);

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
  }) async {
    final user = currentUser;

    if (user == null) {
      return;
    }

    await client.from('community_activity').insert({
      'user_id': user.id,

      'activity_type': activityType,

      'media_type': mediaType,

      'tmdb_id': tmdbId,

      'media_title': mediaTitle,

      'season_number': seasonNumber,

      'episode_number': episodeNumber,

      'episode_title': episodeTitle,

      'rating_stars': ratingStars,

      'achievement_id': achievementId,

      'achievement_title': achievementTitle,
    });
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
      );
    } catch (e) {
      debugPrint('Community activity failed: $e');
    }
  }
}
