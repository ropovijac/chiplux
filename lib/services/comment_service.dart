import 'package:supabase_flutter/supabase_flutter.dart';


class CommentService {

  CommentService._();


  static final CommentService instance = CommentService._();


  final SupabaseClient client = Supabase.instance.client;


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

    late final List<dynamic> rows;


    if (mediaType == 'episode') {

      if (seasonNumber == null || episodeNumber == null) {

        return 0;

      }


      rows = await client

          .from('media_comments')

          .select('id')

          .eq('media_type', 'episode')

          .eq('tmdb_id', tmdbId)

          .eq('season_number', seasonNumber)

          .eq('episode_number', episodeNumber);

    } else {

      rows = await client

          .from('media_comments')

          .select('id')

          .eq('media_type', mediaType)

          .eq('tmdb_id', tmdbId);

    }


    return rows.length;

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

    late final List<dynamic> rawComments;


    if (mediaType == 'episode') {

      rawComments = await client

          .from('media_comments')

          .select()

          .eq('media_type', 'episode')

          .eq('tmdb_id', tmdbId)

          .eq('season_number', seasonNumber!)

          .eq('episode_number', episodeNumber!)

          .order('created_at', ascending: true);

    } else {

      rawComments = await client

          .from('media_comments')

          .select()

          .eq('media_type', mediaType)

          .eq('tmdb_id', tmdbId)

          .order('created_at', ascending: true);

    }


    final comments = <Map<String, dynamic>>[];


    for (final raw in rawComments) {

      comments.add(Map<String, dynamic>.from(raw));

    }


    await Future.wait(comments.map(_enrichComment));


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


    // Main comments:

    // newest first.

    mainComments.sort((a, b) {

      final aDate =

          DateTime.tryParse(a['created_at']?.toString() ?? '') ??

          DateTime(1970);


      final bDate =

          DateTime.tryParse(b['created_at']?.toString() ?? '') ??

          DateTime(1970);


      return bDate.compareTo(aDate);

    });


    // Replies:

    // oldest first.

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


    final profileFuture = client

    .from('profiles')

    .select(

      'id, '

      'display_name, '

      'username, '

      'avatar_url, '
      'is_developer, '
      'privacy_allow_comment_replies',

    )

        .eq('id', userId)

        .maybeSingle();


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


  // =====================================================

  // OWNERSHIP

  // =====================================================


  bool isOwnComment(Map<String, dynamic> comment) {

    final currentUserId = client.auth.currentUser?.id;


    return currentUserId != null &&

        comment['user_id']?.toString() == currentUserId;

  }

}
