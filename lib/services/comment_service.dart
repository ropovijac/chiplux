import 'package:supabase_flutter/supabase_flutter.dart';

class CommentService {
  CommentService._();

  static final CommentService instance = CommentService._();

  final SupabaseClient client = Supabase.instance.client;


  Future<Map<String, dynamic>?> _loadSafeProfile(String userId) async {
    final raw = await client.rpc(
      'get_safe_profile_cards',
      params: {
        'p_user_ids': [userId],
      },
    );

    if (raw is! List || raw.isEmpty) {
      return null;
    }

    final first = raw.first;

    if (first is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(first);
  }

  String get _userId {
    final user = client.auth.currentUser;

    if (user == null) {
      throw Exception('You must be signed in.');
    }

    return user.id;
  }

  // =====================================================

  // ACCESS

  // =====================================================

  Future<bool> canAccess({
    required String mediaType,

    required int tmdbId,

    int? seasonNumber,

    int? episodeNumber,
  }) async {
    final result = await client.rpc(
      'can_access_media_comments',

      params: {
        'p_media_type': mediaType,

        'p_tmdb_id': tmdbId,

        'p_season_number': seasonNumber,

        'p_episode_number': episodeNumber,
      },
    );

    return result == true;
  }

  Future<int> countComments({
    required String mediaType,
    required int tmdbId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final result = await client.rpc(
      'count_visible_media_comments',
      params: {
        'p_media_type': mediaType,
        'p_tmdb_id': tmdbId,
        'p_season_number': seasonNumber,
        'p_episode_number': episodeNumber,
      },
    );

    return result is num ? result.toInt() : 0;
  }

  // =====================================================

  // LOAD COMMENTS

  // =====================================================

  Future<List<Map<String, dynamic>>> loadComments({
    required String mediaType,
    required int tmdbId,
    int? seasonNumber,
    int? episodeNumber,
  }) async {
    final raw = await client.rpc(
      'get_visible_media_comments',
      params: {
        'p_media_type': mediaType,
        'p_tmdb_id': tmdbId,
        'p_season_number': seasonNumber,
        'p_episode_number': episodeNumber,
      },
    );

    final comments = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          comments.add(Map<String, dynamic>.from(item));
        }
      }
    }

    await Future.wait(comments.map(_enrichComment));

    final byId = <String, Map<String, dynamic>>{};

    for (final comment in comments) {
      comment['replies'] = <Map<String, dynamic>>[];
      final id = comment['id']?.toString();
      if (id != null) byId[id] = comment;
    }

    final mainComments = <Map<String, dynamic>>[];

    for (final comment in comments) {
      final parentId = comment['parent_comment_id']?.toString();

      if (parentId == null || parentId.isEmpty) {
        mainComments.add(comment);
        continue;
      }

      final parent = byId[parentId];
      if (parent == null) continue;

      final replies = parent['replies'];
      if (replies is List<Map<String, dynamic>>) {
        replies.add(comment);
      }
    }

    mainComments.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime(1970);
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime(1970);
      return bDate.compareTo(aDate);
    });

    for (final comment in mainComments) {
      final replies = comment['replies'];
      if (replies is List<Map<String, dynamic>>) {
        replies.sort((a, b) {
          final aDate =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(1970);
          final bDate =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(1970);
          return aDate.compareTo(bDate);
        });
      }
    }

    return mainComments;
  }

  // =====================================================

  // PROFILE + LIKES

  // =====================================================

  Future<void> _enrichComment(Map<String, dynamic> comment) async {
    final commentId = comment['id']?.toString();

    final userId = comment['user_id']?.toString();

    if (commentId == null || userId == null) {
      return;
    }

    final profileFuture = _loadSafeProfile(userId);

    final likesFuture = client
        .from('comment_likes')
        .select('user_id')
        .eq('comment_id', commentId);

    final profile = await profileFuture;

    final likes = await likesFuture;

    final currentUserId = client.auth.currentUser?.id;

    comment['profile'] = profile != null
        ? Map<String, dynamic>.from(profile)
        : null;

    comment['like_count'] = likes.length;

    comment['liked_by_me'] =
        currentUserId != null &&
        likes.any((row) => row['user_id']?.toString() == currentUserId);
  }

  // =====================================================

  // ADD COMMENT

  // =====================================================

  Future<Map<String, dynamic>> addComment({
    required String mediaType,

    required int tmdbId,

    required String body,

    int? seasonNumber,

    int? episodeNumber,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    if (text.length > 4000) {
      throw Exception('Comment is too long.');
    }

    final row = await client
        .from('media_comments')
        .insert({
          'user_id': _userId,

          'media_type': mediaType,

          'tmdb_id': tmdbId,

          'season_number': mediaType == 'episode' ? seasonNumber : null,

          'episode_number': mediaType == 'episode' ? episodeNumber : null,

          'parent_comment_id': null,

          'body': text,
        })
        .select()
        .single();

    final comment = Map<String, dynamic>.from(row);

    await _enrichComment(comment);

    comment['replies'] = <Map<String, dynamic>>[];

    return comment;
  }

  // =====================================================

  // ADD REPLY

  // =====================================================

  Future<Map<String, dynamic>> addReply({
    required String parentCommentId,

    required String mediaType,

    required int tmdbId,

    required String body,

    int? seasonNumber,

    int? episodeNumber,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Reply cannot be empty.');
    }

    if (text.length > 4000) {
      throw Exception('Reply is too long.');
    }

    final row = await client
        .from('media_comments')
        .insert({
          'user_id': _userId,

          'media_type': mediaType,

          'tmdb_id': tmdbId,

          'season_number': mediaType == 'episode' ? seasonNumber : null,

          'episode_number': mediaType == 'episode' ? episodeNumber : null,

          'parent_comment_id': parentCommentId,

          'body': text,
        })
        .select()
        .single();

    final reply = Map<String, dynamic>.from(row);

    await _enrichComment(reply);

    reply['replies'] = <Map<String, dynamic>>[];

    return reply;
  }

  // =====================================================

  // EDIT

  // =====================================================

  Future<void> editComment({
    required String commentId,

    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    if (text.length > 4000) {
      throw Exception('Comment is too long.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await client
        .from('media_comments')
        .update({'body': text, 'updated_at': now, 'edited_at': now})
        .eq('id', commentId)
        .eq('user_id', _userId);
  }

  // =====================================================

  // DELETE

  // =====================================================

  Future<void> deleteComment({required String commentId}) async {
    await client
        .from('media_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId);
  }

  // =====================================================

  // LOVE / UNLOVE

  // =====================================================

  Future<bool> toggleLike({required String commentId}) async {
    final userId = _userId;

    final existing = await client
        .from('comment_likes')
        .select('comment_id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);

      return false;
    }

    await client.from('comment_likes').insert({
      'comment_id': commentId,

      'user_id': userId,
    });

    return true;
  }

  Future<int> reportComment({
    required String commentId,
    required String reportType,
    String? details,
  }) async {
    final result = await client.rpc(
      'report_comment',
      params: {
        'p_comment_id': commentId,
        'p_report_type': reportType,
        'p_details': details,
      },
    );

    return result is num ? result.toInt() : 0;
  }

  // =====================================================

  // MUSIC ALBUM COMMENTS

  // Only listened albums are accessible. Songs, artists and bands never
  // use this comment path.

  // =====================================================

  Future<bool> canAccessMusicAlbumComments({required String albumId}) async {
    final user = client.auth.currentUser;

    if (user == null || albumId.trim().isEmpty) {
      return false;
    }

    final row = await client
        .from('music_user_data')
        .select('entity_id')
        .eq('user_id', user.id)
        .eq('entity_type', 'album')
        .eq('entity_id', albumId)
        .eq('is_listened', true)
        .maybeSingle();

    return row != null;
  }

  Future<int> countMusicAlbumComments({required String albumId}) async {
    if (!await canAccessMusicAlbumComments(albumId: albumId)) {
      return 0;
    }

    final rows = await client
        .from('music_album_comments')
        .select('id')
        .eq('album_id', albumId);

    return rows.length;
  }

  Future<List<Map<String, dynamic>>> loadMusicAlbumComments({
    required String albumId,
  }) async {
    if (!await canAccessMusicAlbumComments(albumId: albumId)) {
      return <Map<String, dynamic>>[];
    }

    final raw = await client
        .from('music_album_comments')
        .select()
        .eq('album_id', albumId);

    final comments = <Map<String, dynamic>>[];

    for (final item in raw) {
      comments.add(Map<String, dynamic>.from(item));
    }

    await Future.wait(comments.map(_enrichMusicAlbumComment));

    final byId = <String, Map<String, dynamic>>{};

    for (final comment in comments) {
      comment['replies'] = <Map<String, dynamic>>[];
      final id = comment['id']?.toString();
      if (id != null) {
        byId[id] = comment;
      }
    }

    final mainComments = <Map<String, dynamic>>[];

    for (final comment in comments) {
      final parentId = comment['parent_comment_id']?.toString();

      if (parentId == null || parentId.isEmpty) {
        mainComments.add(comment);
        continue;
      }

      final parent = byId[parentId];
      if (parent == null) {
        continue;
      }

      final replies = parent['replies'];
      if (replies is List<Map<String, dynamic>>) {
        replies.add(comment);
      }
    }

    mainComments.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    for (final comment in mainComments) {
      final replies = comment['replies'];
      if (replies is List<Map<String, dynamic>>) {
        replies.sort((a, b) {
          final aDate =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(1970);
          final bDate =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(1970);
          return aDate.compareTo(bDate);
        });
      }
    }

    return mainComments;
  }

  Future<void> _enrichMusicAlbumComment(Map<String, dynamic> comment) async {
    final commentId = comment['id']?.toString();
    final userId = comment['user_id']?.toString();

    if (commentId == null || userId == null) {
      return;
    }

    final profileFuture = _loadSafeProfile(userId);

    final likesFuture = client
        .from('music_album_comment_likes')
        .select('user_id')
        .eq('comment_id', commentId);

    final spoilerCountFuture = client.rpc(
      'count_music_album_comment_reports',
      params: {
        'p_comment_id': commentId,
        'p_report_type': 'spoiler',
      },
    );

    final profile = await profileFuture;
    final likes = await likesFuture;
    final spoilerCountRaw = await spoilerCountFuture;
    final currentUserId = client.auth.currentUser?.id;

    comment['profile'] = profile != null
        ? Map<String, dynamic>.from(profile)
        : null;
    comment['like_count'] = likes.length;
    comment['liked_by_me'] =
        currentUserId != null &&
        likes.any((row) => row['user_id']?.toString() == currentUserId);
    final spoilerCount =
        spoilerCountRaw is num ? spoilerCountRaw.toInt() : 0;
    comment['spoiler_hidden'] = spoilerCount >= 3;
  }

  Future<Map<String, dynamic>> addMusicAlbumComment({
    required String albumId,
    required String albumTitle,
    required String artistName,
    required String? coverUrl,
    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    if (text.length > 4000) {
      throw Exception('Comment is too long.');
    }

    if (!await canAccessMusicAlbumComments(albumId: albumId)) {
      throw Exception('Comments are locked until you listen to this album.');
    }

    final row = await client
        .from('music_album_comments')
        .insert({
          'user_id': _userId,
          'album_id': albumId,
          'album_title': albumTitle,
          'artist_name': artistName,
          'cover_url': coverUrl,
          'parent_comment_id': null,
          'body': text,
        })
        .select()
        .single();

    final comment = Map<String, dynamic>.from(row);
    await _enrichMusicAlbumComment(comment);
    comment['replies'] = <Map<String, dynamic>>[];
    return comment;
  }

  Future<Map<String, dynamic>> addMusicAlbumReply({
    required String parentCommentId,
    required String albumId,
    required String albumTitle,
    required String artistName,
    required String? coverUrl,
    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Reply cannot be empty.');
    }

    if (text.length > 4000) {
      throw Exception('Reply is too long.');
    }

    if (!await canAccessMusicAlbumComments(albumId: albumId)) {
      throw Exception('Comments are locked until you listen to this album.');
    }

    final row = await client
        .from('music_album_comments')
        .insert({
          'user_id': _userId,
          'album_id': albumId,
          'album_title': albumTitle,
          'artist_name': artistName,
          'cover_url': coverUrl,
          'parent_comment_id': parentCommentId,
          'body': text,
        })
        .select()
        .single();

    final reply = Map<String, dynamic>.from(row);
    await _enrichMusicAlbumComment(reply);
    reply['replies'] = <Map<String, dynamic>>[];
    return reply;
  }

  Future<void> editMusicAlbumComment({
    required String commentId,
    required String body,
  }) async {
    final text = body.trim();

    if (text.isEmpty) {
      throw Exception('Comment cannot be empty.');
    }

    if (text.length > 4000) {
      throw Exception('Comment is too long.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await client
        .from('music_album_comments')
        .update({'body': text, 'updated_at': now, 'edited_at': now})
        .eq('id', commentId)
        .eq('user_id', _userId);
  }

  Future<void> deleteMusicAlbumComment({required String commentId}) async {
    await client
        .from('music_album_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId);
  }

  Future<bool> toggleMusicAlbumCommentLike({
    required String commentId,
  }) async {
    final userId = _userId;

    final existing = await client
        .from('music_album_comment_likes')
        .select('comment_id')
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await client
          .from('music_album_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
      return false;
    }

    await client.from('music_album_comment_likes').insert({
      'comment_id': commentId,
      'user_id': userId,
    });

    return true;
  }

  Future<int> reportMusicAlbumComment({
    required String commentId,
    required String reportType,
    String? details,
  }) async {
    if (client.auth.currentUser == null) {
      throw Exception('You must be signed in.');
    }

    final count = await client.rpc(
      'report_music_album_comment',
      params: {
        'p_comment_id': commentId,
        'p_report_type': reportType,
        'p_details': details,
      },
    );

    return count is num ? count.toInt() : 0;
  }

  // =====================================================

  // OWNERSHIP

  // =====================================================

  bool isOwnComment(Map<String, dynamic> comment) {
    final currentUserId = client.auth.currentUser?.id;

    return currentUserId != null &&
        comment['user_id']?.toString() == currentUserId;
  }
}
