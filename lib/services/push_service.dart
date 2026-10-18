import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';
import '../l10n/notification_text.dart' show requestsTabForEvent;
import '../screens/notifications_screen.dart';
import '../screens/requests_screen.dart';

/// Push notifications (20240155_push_notifications.sql, send-push).
///
/// After sign-in the device's Firebase token is registered for the user;
/// on sign-out it is removed. Tapping a push opens Requests on the right
/// side, or the notifications list. If Firebase can't start it does
/// nothing and the app works as before.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  GlobalKey<NavigatorState>? _navigator;
  StreamSubscription<AuthState>? _auth;
  StreamSubscription<String>? _refresh;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> start(GlobalKey<NavigatorState> navigator) async {
    _navigator = navigator;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
    } catch (e) {
      debugPrint('[Push] Firebase not set up: $e');
      return;
    }
    final messaging = FirebaseMessaging.instance;
    // iOS: show the banner even while the app is open.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Let the first screen settle before opening another on top.
      Future.delayed(const Duration(seconds: 1), () => _open(initial));
    }
    _refresh = messaging.onTokenRefresh.listen(_register);
    _auth = _client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn ||
          s.event == AuthChangeEvent.initialSession && s.session != null) {
        unawaited(_enable());
      }
    });
  }

  Future<void> _enable() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isIOS && await messaging.getAPNSToken() == null) {
        // The APNs token arrives a moment after permission on first launch.
        await Future.delayed(const Duration(seconds: 2));
      }
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('[Push] enable: $e');
    }
  }

  Future<void> _register(String token) async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'register_push_token',
        params: {
          'p_token': token,
          'p_platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e) {
      debugPrint('[Push] register: $e');
    }
  }

  /// Call before signing out, while the session can still remove it.
  Future<void> signingOut() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _client.rpc('unregister_push_token', params: {'p_token': token});
      }
    } catch (e) {
      debugPrint('[Push] unregister: $e');
    }
  }

  void _open(RemoteMessage message) {
    final navigator = _navigator?.currentState;
    if (navigator == null || _client.auth.currentUser == null) return;
    final tab = requestsTabForEvent(message.data['event'] as String?);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => tab == null
            ? const NotificationsScreen()
            : RequestsScreen(initialTab: tab),
      ),
    );
  }

  Future<void> dispose() async {
    await _auth?.cancel();
    await _refresh?.cancel();
  }
}
