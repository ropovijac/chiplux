import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
      PushNotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenSubscription;

  bool _initialized = false;

  bool get _supportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform ==
            TargetPlatform.android ||
        defaultTargetPlatform ==
            TargetPlatform.iOS;
  }

  String get _platformName {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';

      case TargetPlatform.iOS:
        return 'ios';

      default:
        return 'unknown';
    }
  }

  Future<void> initialize() async {
    if (_initialized ||
        !_supportedPlatform) {
      return;
    }

    _initialized = true;

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _tokenSubscription =
          _messaging.onTokenRefresh.listen(
        (token) {
          unawaited(
            _saveToken(token),
          );
        },
        onError: (error) {
          debugPrint(
            'FCM token refresh error: $error',
          );
        },
      );

      await registerCurrentToken();
    } catch (e) {
      debugPrint(
        'Could not initialize push notifications: $e',
      );
    }
  }

  Future<void> registerCurrentToken() async {
    if (!_supportedPlatform) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

        debugPrint(
  'Push registration user: ${user?.id}',
);

    if (user == null) {
      return;
    }

    try {
      final token =
          await _messaging.getToken();

          debugPrint(
  'Push token available: ${token != null}',
);

      if (token == null ||
          token.trim().isEmpty) {
        debugPrint(
          'FCM token is not available.',
        );

        return;
      }

      await _saveToken(token);

      debugPrint(
        'Push device registered.',
      );
    } catch (e) {
      debugPrint(
        'Could not register push token: $e',
      );
    }
  }

  Future<void> _saveToken(
    String token,
  ) async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null ||
        token.trim().isEmpty) {
      return;
    }

    await Supabase.instance.client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform':
            _platformName,
      },
    );
  }

  Future<void> unregisterCurrentToken() async {
    if (!_supportedPlatform) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final token =
          await _messaging.getToken();

      if (token == null ||
          token.trim().isEmpty) {
        return;
      }

      await Supabase.instance.client.rpc(
        'unregister_push_token',
        params: {
          'p_token': token,
        },
      );
    } catch (e) {
      debugPrint(
        'Could not unregister push token: $e',
      );
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();

    _tokenSubscription = null;

    _initialized = false;
  }
}