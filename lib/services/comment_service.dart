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

    // One batched lookup per metadata type, rather than one profile and one
    // likes query per comment. This includes replies in the same request.
    await _enrichCommentsInBatches(
      comments,
      likesTable: 'comment_likes',
    );

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

  // BATCHED COMMENT METADATA
  //
  // Preserve the existing safe-profile RPC and per-table RLS rules. We batch
  // only rows that a user could already read through the original queries.
  // Pagination matters: PostgREST often limits a query to 1,000 rows, and
  // truncating likes would silently display incorrect counts.
  // =====================================================

  static const int _metadataIdChunkSize = 80;
  static const int _metadataPageSize = 500;

  Future<Map<String, Map<String, dynamic>>> _loadSafeProfilesForComments(
    Set<String> userIds,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    final ids = userIds.toList();
    for (var start = 0; start < ids.length; start += _metadataIdChunkSize) {
      final end = start + _metadataIdChunkSize < ids.length
          ? start + _metadataIdChunkSize
          : ids.length;
      final raw = await client.rpc(
        'get_safe_profile_cards',
        params: {'p_user_ids': ids.sublist(start, end)},
      );
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is! Map) continue;
        final profile = Map<String, dynamic>.from(item);
        final id = profile['id']?.toString();
        if (id != null && userIds.contains(id)) result[id] = profile;
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _loadCommentLikesInBatches({
    required String table,
    required Set<String> commentIds,
  }) async {
    final allLikes = <Map<String, dynamic>>[];
    final ids = commentIds.toList();
    for (var start = 0; start < ids.length; start += _metadataIdChunkSize) {
      final end = start + _metadataIdChunkSize < ids.length
          ? start + _metadataIdChunkSize
          : ids.length;
      final chunkIds = ids.sublist(start, end);
      for (var offset = 0; ; offset += _metadataPageSize) {
        // Stable ordering across pages prevents duplicates and omissions.
        // These columns were already readable by the old per-comment query.
        final page = await client
            .from(table)
            .select('comment_id, user_id')
            .inFilter('comment_id', chunkIds)
            .order('comment_id')
            .order('user_id')
            .range(offset, offset + _metadataPageSize - 1);
        allLikes.addAll(page.map((row) => Map<String, dynamic>.from(row)));
        if (page.length < _metadataPageSize) break;
      }
    }
    return allLikes;
  }

  Future<void> _enrichCommentsInBatches(
    List<Map<String, dynamic>> comments, {
    required String likesTable,
  }) async {
    if (comments.isEmpty) return;

    final userIds = <String>{};
    final commentIds = <String>{};
    for (final comment in comments) {
      final commentId = comment['id']?.toString();
      final userId = comment['user_id']?.toString();
      if (commentId == null || userId == null) continue;
      commentIds.add(commentId);
      userIds.add(userId);
    }
    if (commentIds.isEmpty) return;

    // Both fetches are independent, and neither writes to user data.
    final results = await Future.wait<Object?>([
      _loadSafeProfilesForComments(userIds),
      _loadCommentLikesInBatches(table: likesTable, commentIds: commentIds),
    ]);
    final profiles = results[0] as Map<String, Map<String, dynamic>>;
    final likes = results[1] as List<Map<String, dynamic>>;
    final likeCounts = <String, int>{};
    final myLikes = <String>{};
    final currentUserId = client.auth.currentUser?.id;

    for (final like in likes) {
      final id = like['comment_id']?.toString();
      if (id == null || !commentIds.contains(id)) continue;
      likeCounts[id] = (likeCounts[id] ?? 0) + 1;
      if (currentUserId != null && like['user_id']?.toString() == currentUserId) {
        myLikes.add(id);
      }
    }

    for (final comment in comments) {
      final id = comment['id']?.toString();
      final userId = comment['user_id']?.toString();
      if (id == null || userId == null) continue;
      comment['profile'] = profiles[userId];
      comment['like_count'] = likeCounts[id] ?? 0;
      comment['liked_by_me'] = myLikes.contains(id);
    }
  }

  // The phase-5C RPC wraps the exact existing per-comment moderation
  // function: it performs the same permission check and 3-report threshold,
  // but sends up to 80 comment IDs in one network request. If the migration
  // has not been applied, the old authorized RPC remains the fallback.
  static const int _spoilerIdChunkSize = 80;

  Future<void> _loadAlbumSpoilerFlagsFallback(
    List<Map<String, dynamic>> comments,
  ) async {
    const concurrency = 8;
    for (var start = 0; start < comments.length; start += concurrency) {
      final end = start + concurrency < comments.length
          ? start + concurrency
          : comments.length;
      await Future.wait(comments.sublist(start, end).map((comment) async {
        final commentId = comment['id']?.toString();
        if (commentId == null) return;
        final count = await client.rpc(
          'count_music_album_comment_reports',
          params: {'p_comment_id': commentId, 'p_report_type': 'spoiler'},
        );
        comment['spoiler_hidden'] = count is num && count >= 3;
      }));
    }
  }

  Future<void> _loadAlbumSpoilerFlags(
    List<Map<String, dynamic>> comments,
  ) async {
    final byId = <String, List<Map<String, dynamic>>>{};
    for (final comment in comments) {
      final id = comment['id']?.toString();
      if (id == null || id.isEmpty) continue;
      byId.putIfAbsent(id, () => <Map<String, dynamic>>[]).add(comment);
    }
    if (byId.isEmpty) return;

    final ids = byId.keys.toList(growable: false);
    for (var start = 0; start < ids.length; start += _spoilerIdChunkSize) {
      final end = start + _spoilerIdChunkSize < ids.length
          ? start + _spoilerIdChunkSize
          : ids.length;
      final chunkIds = ids.sublist(start, end);
      final unresolved = chunkIds.toSet();

      try {
        final raw = await client.rpc(
          'chiplux_album_spoiler_flags',
          params: {'p_comment_ids': chunkIds},
        );
        if (raw is! List) {
          throw const FormatException('Invalid album spoiler response.');
        }
        for (final item in raw) {
          if (item is! Map) continue;
          final id = item['comment_id']?.toString();
          final hidden = item['spoiler_hidden'];
          if (id == null || !unresolved.contains(id) || hidden is! bool) {
            continue;
          }
          for (final comment in byId[id]!) {
            comment['spoiler_hidden'] = hidden;
          }
          unresolved.remove(id);
        }
      } on PostgrestException catch (error) {
        // Upgrade-safe for apps installed before the SQL migration. A genuine
        // permission or server failure should still surface, not silently
        // reveal comments that should be hidden by the spoiler threshold.
        if (error.code != 'PGRST202' && error.code != '42883') rethrow;
      }

      // Unexpected missing rows are checked against the authoritative old
      // function instead of defaulting to visible/unhidden.
      if (unresolved.isNotEmpty) {
        final missing = <Map<String, dynamic>>[];
        for (final id in unresolved) {
          missing.addAll(byId[id]!);
        }
        await _loadAlbumSpoilerFlagsFallback(missing);
      }
    }
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

    // HEAD/count avoids downloading every comment ID, and remains accurate
    // for albums with more than Supabase's default 1,000-row response cap.
    return await client
        .from('music_album_comments')
        .count(CountOption.exact)
        .eq('album_id', albumId);
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

    // Album comment profiles and likes share the same batch enrichment path.
    // Spoiler decisions still use the existing authorized Supabase RPC.
    await Future.wait<void>([
      _enrichCommentsInBatches(
        comments,
        likesTable: 'music_album_comment_likes',
      ),
      _loadAlbumSpoilerFlags(comments),
    ]);

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
