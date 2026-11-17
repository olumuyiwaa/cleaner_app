import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'providers.dart';
import 'router.dart';

/// Shared by the UI and the push service so foreground notifications can
/// show a snackbar from anywhere.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Registers this phone's FCM token with the backend so dispatch and
/// managers can notify the cleaner (new job, leave decision, ...).
///
/// Push is optional: without Firebase configuration for the app
/// (google-services.json / GoogleService-Info.plist) initialisation fails
/// quietly and everything else keeps working.
class PushService {
  PushService(this._api, this._openRoute);

  final ApiClient _api;
  final void Function(String route) _openRoute;

  bool _started = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  Future<void> start() async {
    if (_started) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) await _register(token);

      _refreshSub = messaging.onTokenRefresh.listen(_register);
      _foregroundSub = FirebaseMessaging.onMessage.listen(_showForeground);
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpened(initial);

      _started = true;
    } catch (e) {
      debugPrint('Push notifications disabled: $e');
    }
  }

  Future<void> stop() async {
    final token = _token;
    await _refreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _refreshSub = _foregroundSub = _openedSub = null;
    _started = false;
    if (token != null) {
      try {
        await _api.delete('/cleaners/me/device-token', body: {'token': token});
      } catch (_) {
        // Signing out must not fail because the token could not be removed.
      }
    }
    _token = null;
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _api.post(
        '/cleaners/me/device-token',
        body: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e) {
      debugPrint('Could not register device token: $e');
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    final text = [n?.title, n?.body].whereType<String>().join(' - ');
    if (text.isEmpty) return;
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
  }

  void _handleOpened(RemoteMessage message) {
    final data = message.data;
    final bookingId = data['bookingId'];
    if (bookingId is String && bookingId.isNotEmpty) {
      _openRoute('/job/$bookingId');
    } else if (data['type'] == 'LEAVE') {
      _openRoute('/leave');
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    ref.watch(apiClientProvider),
    (route) => ref.read(routerProvider).push(route),
  );
});
