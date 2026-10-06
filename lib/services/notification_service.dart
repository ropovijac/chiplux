import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChipluxNotification {
  final String id;

  final String type;

  final String title;
  final String body;

  final String? actorUserId;

  final String? mediaType;

  final int? tmdbId;

  final int? seasonNumber;
  final int? episodeNumber;

  final String? commentId;
  final String? parentCommentId;

final String? achievementId;
final String? achievementTitle;

final bool isRead;

  final DateTime createdAt;

  const ChipluxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.actorUserId,
    required this.mediaType,
    required this.tmdbId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.commentId,
    required this.parentCommentId,
required this.achievementId,
required this.achievementTitle,
required this.isRead,
    required this.createdAt,
  });

  factory ChipluxNotification.fromMap(
    Map<String, dynamic> map,
  ) {
    final rawTmdbId = map['tmdb_id'];

    final rawSeason = map['season_number'];

    final rawEpisode = map['episode_number'];

    return ChipluxNotification(
      id: map['id']?.toString() ?? '',

      type:
          map['type']?.toString() ?? 'notification',

      title:
          map['title']?.toString() ?? 'Notification',

      body:
          map['body']?.toString() ?? '',

      actorUserId:
          map['actor_user_id']?.toString(),

      mediaType:
          map['media_type']?.toString(),

      tmdbId: rawTmdbId is num
          ? rawTmdbId.toInt()
          : null,

      seasonNumber: rawSeason is num
          ? rawSeason.toInt()
          : null,

      episodeNumber: rawEpisode is num
          ? rawEpisode.toInt()
          : null,

      commentId:
          map['comment_id']?.toString(),

      parentCommentId:
    map['parent_comment_id']?.toString(),

achievementId:
    map['achievement_id']?.toString(),

achievementTitle:
    map['achievement_title']?.toString(),

isRead:
    map['is_read'] == true,

      createdAt:
          DateTime.tryParse(
            map['created_at']?.toString() ?? '',
          )?.toLocal() ??
          DateTime.now(),
    );
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final SupabaseClient client =
      Supabase.instance.client;

  List<ChipluxNotification> _notifications = [];

  List<ChipluxNotification> get notifications =>
      List.unmodifiable(_notifications);

  bool _loading = false;

  bool get loading => _loading;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  RealtimeChannel? _channel;

  String? _subscribedUserId;

  int get unreadCount {
    return _notifications
        .where(
          (notification) =>
              !notification.isRead,
        )
        .length;
  }

  // =====================================================
  // LOAD
  // =====================================================

  Future<void> load() async {
    final user = client.auth.currentUser;

    if (user == null) {
      await clear();

      return;
    }

    if (_subscribedUserId != null &&
        _subscribedUserId != user.id) {
      if (_channel != null) {
        await _channel!.unsubscribe();
      }

      _channel = null;
      _subscribedUserId = null;

      _notifications = [];
    }

    await refresh();

    _startRealtime(user.id);
  }

  // =====================================================
  // REFRESH
  // =====================================================

  Future<void> refresh() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    _loading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final rows = await client
          .from('notifications')
          .select()
          .eq(
            'recipient_user_id',
            user.id,
          )
          .order(
            'created_at',
            ascending: false,
          )
          .limit(100);

      _notifications = rows
          .map(
            (row) =>
                ChipluxNotification.fromMap(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint(
        'Could not load notifications: $e',
      );

      _errorMessage =
          'Could not load notifications.';
    } finally {
      _loading = false;

      notifyListeners();
    }
  }

  // =====================================================
  // MARK ONE READ
  // =====================================================

  Future<void> markRead(
    String notificationId,
  ) async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    final index = _notifications.indexWhere(
      (notification) =>
          notification.id == notificationId,
    );

    if (index == -1) {
      return;
    }

    final old = _notifications[index];

    if (old.isRead) {
      return;
    }

    await client
        .from('notifications')
        .update({
          'is_read': true,
        })
        .eq(
          'id',
          notificationId,
        )
        .eq(
          'recipient_user_id',
          user.id,
        );

    await refresh();
  }

  // =====================================================
  // MARK ALL READ
  // =====================================================

  Future<void> markAllRead() async {
    final user = client.auth.currentUser;

    if (user == null) {
      return;
    }

    await client
        .from('notifications')
        .update({
          'is_read': true,
        })
        .eq(
          'recipient_user_id',
          user.id,
        )
        .eq(
          'is_read',
          false,
        );

    await refresh();
  }

  // =====================================================
  // DELETE
  // =====================================================

  Future<void> deleteNotification(
  String notificationId,
) async {
  final user = client.auth.currentUser;

  if (user == null) {
    return;
  }

  final previousNotifications =
      List<ChipluxNotification>.from(
    _notifications,
  );

  // Remove immediately from the UI.
  _notifications =
      _notifications
          .where(
            (notification) =>
                notification.id !=
                notificationId,
          )
          .toList();

  notifyListeners();

  try {
    await client
        .from('notifications')
        .delete()
        .eq(
          'id',
          notificationId,
        )
        .eq(
          'recipient_user_id',
          user.id,
        );
  } catch (e) {
    // Restore it if the database delete failed.
    _notifications =
        previousNotifications;

    _errorMessage =
        'Could not delete notification.';

    notifyListeners();

    debugPrint(
      'Could not delete notification: $e',
    );
  }
}

  // =====================================================
  // REALTIME
  // =====================================================

  void _startRealtime(String userId) {
    if (_channel != null &&
        _subscribedUserId == userId) {
      return;
    }

    if (_channel != null) {
      unawaited(
        _channel!.unsubscribe(),
      );
    }

    _subscribedUserId = userId;

    _channel = client.channel(
      'own_notifications_${userId}_$hashCode',
    );

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            final currentUser =
                client.auth.currentUser;

            if (currentUser?.id != userId) {
              return;
            }

            unawaited(refresh());
          },
        )
        .subscribe();
  }

  // =====================================================
  // CLEAR
  // =====================================================

  Future<void> clear() async {
    if (_channel != null) {
      await _channel!.unsubscribe();
    }

    _channel = null;
    _subscribedUserId = null;

    _notifications = [];

    _loading = false;
    _errorMessage = null;

    notifyListeners();
  }
}