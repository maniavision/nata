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
import '../screens/chat_thread_screen.dart';
import '../screens/traveler_results_screen.dart';
import 'app_badge.dart';
import 'push_registrar.dart';

/// Push notifications (20240155_push_notifications.sql, send-push).
///
/// While someone is signed in, the device's Firebase token is registered for
/// them ([PushRegistrar]: at launch, sign-in, a refreshed session and each
/// return to the app, so a phone that missed it once is caught up); on
/// sign-out it is removed. Pushes carry a visible notification, so the
/// phone shows them even when the app is closed. Tapping a push opens
/// Requests on the right side, or the notifications list. If Firebase
/// can't start it does nothing and the app works as before.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  PushRegistrar? _registrar;
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
    // The permission prompt at most once per launch; after that the answer
    // is only read, so coming back to the app never asks again.
    var asked = false;
    _registrar = PushRegistrar(
      requestPermission: () async {
        final settings = asked
            ? await messaging.getNotificationSettings()
            : await messaging.requestPermission();
        asked = true;
        return settings.authorizationStatus != AuthorizationStatus.denied;
      },
      apnsToken: Platform.isIOS ? messaging.getAPNSToken : null,
      fcmToken: messaging.getToken,
      save: _register,
      userId: () => _client.auth.currentUser?.id,
    );
    // Listen first, so a sign-in during the setup below isn't missed.
    _auth = _client.auth.onAuthStateChange.listen((s) {
      if (s.session != null) unawaited(_enable());
    });
    _refresh = messaging.onTokenRefresh.listen(
      (token) => _registrar?.tokenChanged(token),
    );
    if (_client.auth.currentUser != null) unawaited(_enable());
    // iOS: show the banner even while the app is open.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    // A push while the app is open: the badge follows the new count.
    FirebaseMessaging.onMessage.listen((_) => AppBadge.refresh());
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Let the first screen settle before opening another on top.
      Future.delayed(const Duration(seconds: 1), () => _open(initial));
    }
  }

  /// Back in the app: register this phone if it still isn't.
  void resumed() {
    if (_client.auth.currentUser != null) unawaited(_enable());
  }

  Future<void> _enable() async {
    final registrar = _registrar;
    if (!_ready || registrar == null) return;
    final ok = await registrar.ensure();
    if (!ok) debugPrint('[Push] not registered yet; tried again later');
    await AppBadge.refresh();
  }

  /// Saves [token] for the signed-in member (throws when it can't, so it is
  /// tried again).
  Future<void> _register(String token) async {
    if (_client.auth.currentUser == null) return;
    await _client.rpc(
      'register_push_token',
      params: {
        'p_token': token,
        'p_platform': Platform.isIOS ? 'ios' : 'android',
      },
    );
  }

  /// Call before signing out, while the session can still remove it.
  Future<void> signingOut() async {
    _registrar?.forget();
    await AppBadge.clear();
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
    final event = message.data['event'] as String?;
    if (event == 'trip_match') {
      final results = resultsForRouteAlert(message.data);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => results ?? const NotificationsScreen(),
        ),
      );
      return;
    }
    final chat = message.data['conversation_id'] as String?;
    if (event == 'message_new' && chat != null && chat.isNotEmpty) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatFromNotification(conversationId: chat),
        ),
      );
      return;
    }
    final tab = requestsTabForEvent(event);
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
