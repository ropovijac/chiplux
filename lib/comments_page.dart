import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/comment_service.dart';

const Color _commentsBackground = Color(0xFF07111C);

const Color _commentsSurface = Color(0xFF111D2A);

const Color _commentsSurfaceLight = Color(0xFF162536);

const Color _commentsCyan = Color(0xFF43E8FF);

class CommentsPage extends StatefulWidget {
  final String mediaType;
  final int tmdbId;
  final Future<void> Function(String userId)? onProfileTap;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? targetCommentId;

  final String title;
  final String? subtitle;

  // TMDB backdrop_path for a movie/show,
  // or still_path for an episode.
  final String? imagePath;

  const CommentsPage({
  super.key,
  required this.mediaType,
  required this.tmdbId,
  required this.title,
  this.subtitle,
  this.imagePath,
  this.seasonNumber,
  this.episodeNumber,
  this.onProfileTap,
  this.targetCommentId,
});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class CommentCountLabel extends StatefulWidget {
  final String mediaType;
  final int tmdbId;
  final int? seasonNumber;
  final int? episodeNumber;

  const CommentCountLabel({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    this.seasonNumber,
    this.episodeNumber,
  });

  @override
  State<CommentCountLabel> createState() => _CommentCountLabelState();
}

class _CommentCountLabelState extends State<CommentCountLabel> {
  int? _count;

  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _loadCount();
    _startRealtime();
  }

  Future<void> _loadCount() async {
    try {
      final count = await CommentService.instance.countComments(
        mediaType: widget.mediaType,
        tmdbId: widget.tmdbId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _count = count;
      });
    } catch (e) {
      debugPrint('Could not load comment count: $e');
    }
  }

  void _scheduleReload() {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      unawaited(_loadCount());
    });
  }

  void _startRealtime() {
    final client = Supabase.instance.client;

    _channel = client.channel(
      'comment_count_'
      '${widget.mediaType}_'
      '${widget.tmdbId}_'
      '${widget.seasonNumber ?? 0}_'
      '${widget.episodeNumber ?? 0}_'
      '$hashCode',
    );

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'media_comments',
          callback: (payload) {
            _scheduleReload();
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _count == null ? "Let's Comment" : "Let's Comment · $_count",
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();

    if (_channel != null) {
      unawaited(_channel!.unsubscribe());
    }

    super.dispose();
  }
}

class _CommentsPageState extends State<CommentsPage> {
  final CommentService service = CommentService.instance;

  List<Map<String, dynamic>> comments = [];

  bool loading = true;
  bool canAccess = false;

  String? errorMessage;

  RealtimeChannel? _commentsChannel;

  RealtimeChannel? _likesChannel;

  Timer? _realtimeDebounce;

  final ScrollController _scrollController =
    ScrollController();

final Map<String, GlobalKey> _commentKeys =
    <String, GlobalKey>{};

Timer? _highlightTimer;

String? _highlightedCommentId;

bool _didFocusTargetComment = false;


  Future<void> _openProfile(Map<String, dynamic> comment) async {
    final userId = comment['user_id']?.toString();

    if (userId == null || userId.isEmpty || widget.onProfileTap == null) {
      return;
    }

    await widget.onProfileTap!(userId);
  }

  final Set<String> _expandedReplies = <String>{};

  GlobalKey _commentKey(String commentId) {
  return _commentKeys.putIfAbsent(
    commentId,
    () => GlobalKey(),
  );
}

void _prepareTargetComment(
  List<Map<String, dynamic>> loadedComments,
) {
  final targetId =
      widget.targetCommentId;

  if (targetId == null ||
      targetId.isEmpty ||
      _didFocusTargetComment) {
    return;
  }

  for (final comment in loadedComments) {
    final commentId =
        comment['id']?.toString();

    // Target itself is a main comment.
    if (commentId == targetId) {
      return;
    }

    final rawReplies =
        comment['replies'];

    if (rawReplies is! List) {
      continue;
    }

    for (final rawReply in rawReplies) {
      if (rawReply is! Map) {
        continue;
      }

      final replyId =
          rawReply['id']?.toString();

      if (replyId == targetId) {
        // The target is a reply,
        // so automatically open its parent.
        if (commentId != null &&
            commentId.isNotEmpty) {
          _expandedReplies.add(
            commentId,
          );
        }

        return;
      }
    }
  }
}

int? _targetMainCommentIndex() {
  final targetId =
      widget.targetCommentId;

  if (targetId == null ||
      targetId.isEmpty) {
    return null;
  }

  final sorted =
      _sortedComments;

  for (int i = 0;
      i < sorted.length;
      i++) {
    final comment = sorted[i];

    if (comment['id']?.toString() ==
        targetId) {
      return i;
    }

    final rawReplies =
        comment['replies'];

    if (rawReplies is! List) {
      continue;
    }

    for (final rawReply in rawReplies) {
      if (rawReply is Map &&
          rawReply['id']?.toString() ==
              targetId) {
        return i;
      }
    }
  }

  return null;
}

Future<void> _focusTargetComment() async {
  if (_didFocusTargetComment) {
    return;
  }

  final targetId =
      widget.targetCommentId;

  if (targetId == null ||
      targetId.isEmpty) {
    return;
  }

  final key =
      _commentKey(targetId);

  // Try several frames because a comment
  // far down the list may not be built yet.
  for (int attempt = 0;
      attempt < 5;
      attempt++) {
    await WidgetsBinding
        .instance.endOfFrame;

    if (!mounted) {
      return;
    }

    final targetContext =
    key.currentContext;

if (targetContext != null) {
  if (!targetContext.mounted) {
    continue;
  }

  _didFocusTargetComment = true;

  await Scrollable.ensureVisible(
    targetContext,

        duration:
            const Duration(
          milliseconds: 550,
        ),

        curve:
            Curves.easeOutCubic,

        alignment: 0.30,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _highlightedCommentId =
            targetId;
      });

      _highlightTimer?.cancel();

      _highlightTimer = Timer(
        const Duration(
          milliseconds: 2200,
        ),
        () {
          if (!mounted) {
            return;
          }

          setState(() {
            _highlightedCommentId =
                null;
          });
        },
      );

      return;
    }

    // If Flutter has not built the target
    // yet, move approximately to its
    // position so it enters the viewport.
    if (_scrollController.hasClients) {
      final index =
          _targetMainCommentIndex();

      final count =
          _sortedComments.length;

      if (index != null &&
          count > 0) {
        final position =
            _scrollController.position;

        final double fraction =
            count <= 1
            ? 0
            : index / (count - 1);

        final double offset =
            position.maxScrollExtent *
                fraction;

        await _scrollController
            .animateTo(
          offset.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),

          duration:
              const Duration(
            milliseconds: 220,
          ),

          curve:
              Curves.easeOut,
        );
      }
    }
  }
}

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _load();
    _startRealtime();
  }

  // =====================================================
  // REALTIME
  // =====================================================

  void _scheduleRealtimeReload() {
    _realtimeDebounce?.cancel();

    _realtimeDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      unawaited(_load());
    });
  }

  void _startRealtime() {
    final client = Supabase.instance.client;

    // =========================================
    // COMMENTS / REPLIES / EDITS / DELETES
    // =========================================

    _commentsChannel = client.channel(
      'comments_'
      '${widget.mediaType}_'
      '${widget.tmdbId}_'
      '${widget.seasonNumber ?? 0}_'
      '${widget.episodeNumber ?? 0}_'
      '$hashCode',
    );

    _commentsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'media_comments',
          callback: (payload) {
            _scheduleRealtimeReload();
          },
        )
        .subscribe();

    // =========================================
    // LOVES
    // =========================================

    _likesChannel = client.channel('comment_likes_$hashCode');

    _likesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comment_likes',
          callback: (payload) {
            _scheduleRealtimeReload();
          },
        )
        .subscribe();
  }

  // =====================================================
  // LOAD
  // =====================================================

  Future<void> _load({bool showLoader = false}) async {
    if (showLoader && mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final allowed = await service.canAccess(
        mediaType: widget.mediaType,
        tmdbId: widget.tmdbId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );

      if (!mounted) {
        return;
      }

      if (!allowed) {
        setState(() {
          canAccess = false;
          loading = false;

          errorMessage = widget.mediaType == 'episode'
              ? 'Comments are locked until you watch this episode.'
              : 'Comments are locked until you finish this title.';
        });

        return;
      }

      final loadedComments = await service.loadComments(
        mediaType: widget.mediaType,
        tmdbId: widget.tmdbId,
        seasonNumber: widget.seasonNumber,
        episodeNumber: widget.episodeNumber,
      );

      if (!mounted) {
        return;
      }

      setState(() {
  canAccess = true;

  comments = loadedComments;

  _prepareTargetComment(
    loadedComments,
  );

  loading = false;

  errorMessage = null;
});

if (!_didFocusTargetComment &&
    widget.targetCommentId != null) {
  WidgetsBinding.instance
      .addPostFrameCallback(
    (_) {
      unawaited(
        _focusTargetComment(),
      );
    },
  );
}
    } catch (e) {
      debugPrint('Could not load comments: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        loading = false;

        errorMessage = 'Could not load comments.';
      });
    }
  }

  int _commentLikes(Map<String, dynamic> comment) {
    final value = comment['like_count'];

    return value is num ? value.toInt() : 0;
  }

  DateTime _commentDate(Map<String, dynamic> comment) {
    return DateTime.tryParse(comment['created_at']?.toString() ?? '') ??
        DateTime(1970);
  }

  List<Map<String, dynamic>> get _sortedComments {
    final sorted = List<Map<String, dynamic>>.from(comments);

    sorted.sort((a, b) {
      final likeCompare = _commentLikes(b).compareTo(_commentLikes(a));

      if (likeCompare != 0) {
        return likeCompare;
      }

      // Same number of likes:
      // newest one first.
      return _commentDate(b).compareTo(_commentDate(a));
    });

    return sorted;
  }

  // =====================================================
  // COMPOSER
  // =====================================================

  Future<void> _openComposer({
    Map<String, dynamic>? parentComment,
    Map<String, dynamic>? editingComment,
  }) async {
    final isEditing = editingComment != null;

    final isReply = parentComment != null;

    final controller = TextEditingController(
      text: editingComment?['body']?.toString() ?? '',
    );

    String? composerError;

    final result = await showModalBottomSheet<bool>(
      context: context,

      isScrollControlled: true,

      // IMPORTANT:
      // Don't let Flutter drag-dismiss the
      // focused TextField route.
      enableDrag: false,

      isDismissible: false,

      useSafeArea: true,

      backgroundColor: _commentsSurface,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      builder: (sheetContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> closeSheet([bool? result]) async {
              // Release TextField / keyboard
              // before removing the route.
              FocusManager.instance.primaryFocus?.unfocus();

              // Give Flutter one frame to
              // detach keyboard dependencies.
              await Future<void>.delayed(const Duration(milliseconds: 80));

              if (!sheetContext.mounted) {
                return;
              }

              Navigator.pop(sheetContext, result);
            }

            Future<void> submit() async {
              if (saving) {
                return;
              }

              final text = controller.text.trim();

              if (text.isEmpty) {
                setSheetState(() {
                  composerError = isReply
                      ? 'Write a reply first.'
                      : 'Write a comment first.';
                });

                return;
              }

              setSheetState(() {
                saving = true;
                composerError = null;
              });

              try {
                if (isEditing) {
                  await service.editComment(
                    commentId: editingComment['id'].toString(),
                    body: text,
                  );
                } else if (isReply) {
                  await service.addReply(
                    parentCommentId: parentComment['id'].toString(),

                    mediaType: widget.mediaType,

                    tmdbId: widget.tmdbId,

                    seasonNumber: widget.seasonNumber,

                    episodeNumber: widget.episodeNumber,

                    body: text,
                  );
                } else {
                  await service.addComment(
                    mediaType: widget.mediaType,

                    tmdbId: widget.tmdbId,

                    seasonNumber: widget.seasonNumber,

                    episodeNumber: widget.episodeNumber,

                    body: text,
                  );
                }

                if (!sheetContext.mounted) {
                  return;
                }

                await closeSheet(true);
              } catch (e) {
                debugPrint('Could not save comment: $e');

                if (!sheetContext.mounted) {
                  return;
                }

                setSheetState(() {
                  saving = false;

                  composerError = 'Could not save. Please try again.';
                });
              }
            }

            String title = 'Add Comment';

            if (isEditing) {
              title = 'Edit Comment';
            } else if (isReply) {
              title = 'Reply';
            }

            return PopScope(
              // Don't allow Android back gesture
              // while the database request is saving.
              canPop: !saving,

              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,

                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                ),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,

                            style: const TextStyle(
                              color: Colors.white,

                              fontSize: 20,

                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: saving
                              ? null
                              : () {
                                  closeSheet();
                                },

                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),

                    if (isReply) ...[
                      const SizedBox(height: 4),

                      Text(
                        'Replying to '
                        '${_displayName(parentComment)}',

                        style: const TextStyle(
                          color: Colors.white54,

                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    TextField(
                      controller: controller,

                      autofocus: true,

                      minLines: 3,

                      maxLines: 8,

                      maxLength: 4000,

                      enabled: !saving,

                      textCapitalization: TextCapitalization.sentences,

                      decoration: InputDecoration(
                        hintText: isReply
                            ? 'Write a reply...'
                            : 'Share your thoughts...',

                        filled: true,

                        fillColor: _commentsSurfaceLight,

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),

                          borderSide: BorderSide.none,
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),

                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),

                          borderSide: BorderSide(
                            color: _commentsCyan.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),

                    if (composerError != null) ...[
                      const SizedBox(height: 8),

                      Text(
                        composerError!,

                        style: const TextStyle(
                          color: Colors.redAccent,

                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,

                      height: 48,

                      child: ElevatedButton(
                        onPressed: saving ? null : submit,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: _commentsCyan,

                          foregroundColor: Colors.black,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),

                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,

                                child: CircularProgressIndicator(
                                  strokeWidth: 2,

                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Save Changes'
                                    : isReply
                                    ? 'Post Reply'
                                    : 'Post Comment',

                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // The modal route is completely gone
    // before disposing its controller.
    await Future<void>.delayed(Duration.zero);

    controller.dispose();

    if (result == true) {
      if (isReply) {
        final parentId = parentComment['id']?.toString();

        if (parentId != null && parentId.isNotEmpty && mounted) {
          setState(() {
            _expandedReplies.add(parentId);
          });
        }
      }

      if (mounted) {
        await _load();
      }
    }
  }

  // =====================================================
  // DELETE
  // =====================================================

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _commentsSurface,

          title: const Text('Delete comment?'),

          content: const Text(
            'This will permanently delete '
            'this comment, all of its replies, '
            'and all likes.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },

              child: const Text(
                'Delete',

                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await service.deleteComment(commentId: comment['id'].toString());

      await _load();
    } catch (e) {
      debugPrint('Could not delete comment: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete comment.')),
      );
    }
  }

  // =====================================================
  // LOVE
  // =====================================================

  Future<void> _toggleLove(Map<String, dynamic> comment) async {
    final wasLiked = comment['liked_by_me'] == true;

    final previousCount = comment['like_count'] is num
        ? (comment['like_count'] as num).toInt()
        : 0;

    final optimisticLiked = !wasLiked;

    final optimisticCount = optimisticLiked
        ? previousCount + 1
        : (previousCount - 1).clamp(0, 999999999);

    setState(() {
      comment['liked_by_me'] = optimisticLiked;

      comment['like_count'] = optimisticCount;
    });

    try {
      final actualLiked = await service.toggleLike(
        commentId: comment['id'].toString(),
      );

      if (!mounted) {
        return;
      }

      if (actualLiked != optimisticLiked) {
        setState(() {
          comment['liked_by_me'] = actualLiked;

          comment['like_count'] = actualLiked
              ? previousCount + 1
              : previousCount;
        });
      }
    } catch (e) {
      debugPrint('Could not love comment: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        comment['liked_by_me'] = wasLiked;

        comment['like_count'] = previousCount;
      });
    }
  }

  // =====================================================
  // PROFILE HELPERS
  // =====================================================

  String _displayName(Map<String, dynamic>? comment) {
    if (comment == null) {
      return 'Chiplux User';
    }

    final profile = comment['profile'];

    if (profile is! Map) {
      return 'Chiplux User';
    }

    final displayName = profile['display_name']?.toString().trim() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final username = profile['username']?.toString().trim() ?? '';

    if (username.isNotEmpty) {
      return username;
    }

    return 'Chiplux User';
  }

  String? _username(Map<String, dynamic> comment) {
    final profile = comment['profile'];

    if (profile is! Map) {
      return null;
    }

    final username = profile['username']?.toString().trim();

    if (username == null || username.isEmpty) {
      return null;
    }

    return username;
  }

  String? _avatarUrl(Map<String, dynamic> comment) {
    final profile = comment['profile'];

    if (profile is! Map) {
      return null;
    }

    final value = profile['avatar_url']?.toString();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  // =====================================================
  // TIME
  // =====================================================

  String _timeAgo(Map<String, dynamic> comment) {
    final raw = comment['created_at']?.toString();

    if (raw == null) {
      return '';
    }

    final date = DateTime.tryParse(raw)?.toLocal();

    if (date == null) {
      return '';
    }

    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // =====================================================
  // COMMENT
  // =====================================================

  Widget _buildComment(Map<String, dynamic> comment, {bool isReply = false}) {
    final isOwn = service.isOwnComment(comment);

    final liked = comment['liked_by_me'] == true;

    final likeCount = comment['like_count'] is num
        ? (comment['like_count'] as num).toInt()
        : 0;

    final name = _displayName(comment);

    final username = _username(comment);

    final avatarUrl = _avatarUrl(comment);

    final body = comment['body']?.toString() ?? '';

    final edited = comment['edited_at'] != null;

    final rawReplies = comment['replies'];

    final replies = rawReplies is List
        ? rawReplies.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final commentId =
    comment['id']?.toString() ?? '';

final bool isHighlighted =
    commentId.isNotEmpty &&
    _highlightedCommentId ==
        commentId;

final repliesExpanded =
    _expandedReplies.contains(commentId);

    final canOpenProfile = widget.onProfileTap != null;

    Widget avatar;

    if (avatarUrl != null) {
      avatar = CircleAvatar(
        radius: isReply ? 15 : 17,

        backgroundColor: _commentsSurfaceLight,

        backgroundImage: NetworkImage(avatarUrl),
      );
    } else {
      avatar = CircleAvatar(
        radius: isReply ? 15 : 17,

        backgroundColor: _commentsSurfaceLight,

        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',

          style: const TextStyle(
            color: _commentsCyan,

            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 20 : 0, bottom: isReply ? 5 : 9),

      child: AnimatedContainer(
  key: commentId.isEmpty
      ? null
      : _commentKey(commentId),

  duration:
      const Duration(
    milliseconds: 300,
  ),

  curve:
      Curves.easeOutCubic,

  padding: EdgeInsets.all(
    isReply ? 9 : 11,
  ),

  decoration: BoxDecoration(
    color: isHighlighted
        ? _commentsCyan.withValues(
            alpha: 0.08,
          )
        : isReply
        ? _commentsSurfaceLight
            .withValues(
              alpha: 0.55,
            )
        : _commentsSurface,

    borderRadius:
        BorderRadius.circular(14),

    border: Border.all(
      color: isHighlighted
          ? _commentsCyan
          : Colors.white.withValues(
              alpha: 0.06,
            ),

      width:
          isHighlighted
          ? 1.6
          : 1,
    ),

    boxShadow: isHighlighted
        ? [
            BoxShadow(
              color: _commentsCyan
                  .withValues(
                alpha: 0.28,
              ),

              blurRadius: 20,

              spreadRadius: 1,
            ),
          ]
        : const [],
  ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // =====================================
            // USER
            // =====================================

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(30),

                  onTap: canOpenProfile
                      ? () {
                          unawaited(_openProfile(comment));
                        }
                      : null,

                  child: avatar,
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      InkWell(
                        onTap: canOpenProfile
                            ? () {
                                unawaited(_openProfile(comment));
                              }
                            : null,

                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                                style: TextStyle(
                                  color: isReply
                                      ? Colors.white70
                                      : Colors.white,

                                  fontSize: isReply ? 13 : 14,

                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            if (isOwn) ...[
                              const SizedBox(width: 7),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),

                                decoration: BoxDecoration(
                                  color: _commentsCyan.withValues(alpha: 0.10),

                                  borderRadius: BorderRadius.circular(6),

                                  border: Border.all(
                                    color: _commentsCyan.withValues(
                                      alpha: 0.30,
                                    ),
                                  ),
                                ),

                                child: const Text(
                                  'You',

                                  style: TextStyle(
                                    color: _commentsCyan,

                                    fontSize: 9,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 2),

                      Row(
                        children: [
                          if (username != null) ...[
                            Flexible(
                              child: InkWell(
                                onTap: canOpenProfile
                                    ? () {
                                        unawaited(_openProfile(comment));
                                      }
                                    : null,

                                child: Text(
                                  '@$username',

                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    color: Colors.white38,

                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 7),
                          ],

                          Text(
                            _timeAgo(comment),

                            style: const TextStyle(
                              color: Colors.white30,

                              fontSize: 11,
                            ),
                          ),

                          if (edited) ...[
                            const SizedBox(width: 6),

                            const Text(
                              '• edited',

                              style: TextStyle(
                                color: Colors.white30,

                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // =================================
                // OWN COMMENT MENU
                // =================================
                if (isOwn)
                  PopupMenuButton<String>(
                    color: _commentsSurfaceLight,

                    icon: const Icon(
                      Icons.more_horiz_rounded,

                      color: Colors.white54,
                    ),

                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _openComposer(editingComment: comment);
                      }

                      if (value == 'delete') {
                        await _deleteComment(comment);
                      }
                    },

                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'edit',

                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 19),

                              SizedBox(width: 10),

                              Text('Edit'),
                            ],
                          ),
                        ),

                        PopupMenuItem(
                          value: 'delete',

                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,

                                size: 19,

                                color: Colors.redAccent,
                              ),

                              SizedBox(width: 10),

                              Text(
                                'Delete',

                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // =====================================
            // COMMENT TEXT
            // =====================================
            _ExpandableCommentText(text: body),

            const SizedBox(height: 6),

            // =====================================
            // LOVE / REPLY
            // =====================================
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),

                  onTap: () {
                    _toggleLove(comment);
                  },

                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,

                      vertical: 5,
                    ),

                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),

                          child: Icon(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,

                            key: ValueKey(liked),

                            size: 18,

                            color: liked ? Colors.pinkAccent : Colors.white54,
                          ),
                        ),

                        const SizedBox(width: 4),

                        Text(
                          '$likeCount',

                          style: TextStyle(
                            color: liked ? Colors.pinkAccent : Colors.white54,

                            fontSize: 12,

                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (!isReply) ...[
                  const SizedBox(width: 10),

                  TextButton.icon(
                    onPressed: () {
                      _openComposer(parentComment: comment);
                    },

                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,

                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),

                    icon: const Icon(Icons.reply_rounded, size: 16),

                    label: const Text('Reply', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),

            // =====================================
            // COLLAPSIBLE REPLIES
            // =====================================
            if (!isReply && replies.isNotEmpty) ...[
              const SizedBox(height: 5),

              InkWell(
                borderRadius: BorderRadius.circular(12),

                onTap: () {
                  setState(() {
                    if (repliesExpanded) {
                      _expandedReplies.remove(commentId);
                    } else {
                      _expandedReplies.add(commentId);
                    }
                  });
                },

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,

                    horizontal: 3,
                  ),

                  child: Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,

                        size: 16,

                        color: _commentsCyan.withValues(alpha: 0.8),
                      ),

                      const SizedBox(width: 7),

                      Text(
                        repliesExpanded
                            ? 'Hide replies'
                            : 'View ${replies.length} '
                                  '${replies.length == 1 ? 'reply' : 'replies'}',

                        style: const TextStyle(
                          color: _commentsCyan,

                          fontSize: 12,

                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const Spacer(),

                      Icon(
                        repliesExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,

                        color: Colors.white38,

                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),

              if (repliesExpanded) ...[
                Divider(color: Colors.white.withValues(alpha: 0.08)),

                const SizedBox(height: 6),

                ...replies.map((reply) => _buildComment(reply, isReply: true)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // =====================================================
  // HEADER
  // =====================================================

  Widget _buildHeader() {
    final imageUrl = widget.imagePath != null && widget.imagePath!.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w780'
              '${widget.imagePath}'
        : null;

    int totalComments = comments.length;

    for (final comment in comments) {
      final replies = comment['replies'];

      if (replies is List) {
        totalComments += replies.length;
      }
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),

          child: AspectRatio(
            aspectRatio: 16 / 9,

            child: imageUrl != null
                ? Image.network(
                    imageUrl,

                    fit: BoxFit.cover,

                    errorBuilder: (context, error, stackTrace) {
                      return _imageFallback();
                    },
                  )
                : _imageFallback(),
          ),
        ),

        const SizedBox(height: 18),

        Text(
          widget.title,

          textAlign: TextAlign.center,

          style: const TextStyle(
            color: Colors.white,

            fontSize: 23,

            fontWeight: FontWeight.bold,
          ),
        ),

        if (widget.subtitle != null && widget.subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 5),

          Text(
            widget.subtitle!,

            textAlign: TextAlign.center,

            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],

        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Discussion',

                    style: TextStyle(
                      color: Colors.white,

                      fontSize: 20,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    totalComments == 1
                        ? '1 comment'
                        : '$totalComments comments',

                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),

          ],
        ),

        const SizedBox(height: 14),
      ],
    );
  }

  Widget _imageFallback() {
    return Container(
      color: _commentsSurface,

      alignment: Alignment.center,

      child: const Icon(
        Icons.movie_filter_outlined,

        color: Colors.white24,

        size: 48,
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _commentsBackground,

      appBar: AppBar(
        backgroundColor: _commentsBackground,

        elevation: 0,

        title: const Text(
          'Comments',

          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      floatingActionButton: canAccess
          ? FloatingActionButton.extended(
              tooltip: 'Add comment',

              backgroundColor: _commentsCyan,

              foregroundColor: Colors.black,

              onPressed: () {
                _openComposer();
              },

              icon: const Icon(Icons.add_rounded),

              label: const Text(
                'Comment',

                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,

                      color: Colors.white38,

                      size: 45,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      errorMessage!,

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        color: Colors.white70,

                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextButton(
                      onPressed: () {
                        _load(showLoader: true);
                      },

                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,

              child: ListView(
  controller:
      _scrollController,

  physics:
      const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),

                children: [
                  _buildHeader(),

                  if (comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,

                        vertical: 38,
                      ),

                      decoration: BoxDecoration(
                        color: _commentsSurface,

                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),

                      child: const Column(
                        children: [
                          Icon(
                            Icons.forum_outlined,

                            color: Colors.white24,

                            size: 45,
                          ),

                          SizedBox(height: 12),

                          Text(
                            'No comments yet',

                            style: TextStyle(
                              color: Colors.white70,

                              fontSize: 16,

                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(
                            'Be the first to start the discussion.',

                            textAlign: TextAlign.center,

                            style: TextStyle(
                              color: Colors.white38,

                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._sortedComments.map((comment) => _buildComment(comment)),
                ],
              ),
            ),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _highlightTimer?.cancel();

_scrollController.dispose();
    _realtimeDebounce?.cancel();

    if (_commentsChannel != null) {
      unawaited(_commentsChannel!.unsubscribe());
    }

    if (_likesChannel != null) {
      unawaited(_likesChannel!.unsubscribe());
    }

    super.dispose();
  }
}

// =======================================================
// COLLAPSIBLE COMMENT TEXT
// =======================================================

class _ExpandableCommentText extends StatefulWidget {
  final String text;

  const _ExpandableCommentText({required this.text});

  @override
  State<_ExpandableCommentText> createState() => _ExpandableCommentTextState();
}

class _ExpandableCommentTextState extends State<_ExpandableCommentText> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.white70, fontSize: 14, height: 1.45);

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),

          maxLines: 4,

          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        final canExpand = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            GestureDetector(
              onTap: canExpand
                  ? () {
                      setState(() {
                        expanded = !expanded;
                      });
                    }
                  : null,

              child: Text(
                widget.text,

                maxLines: expanded ? null : 4,

                overflow: expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,

                style: style,
              ),
            ),

            if (canExpand) ...[
              const SizedBox(height: 3),

              InkWell(
                onTap: () {
                  setState(() {
                    expanded = !expanded;
                  });
                },

                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),

                  child: Text(
                    expanded ? 'less' : 'more',

                    style: const TextStyle(
                      color: _commentsCyan,

                      fontSize: 12,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
