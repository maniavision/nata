import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tells open pages that something about the member changed, so Requests and
/// My Trips reload on their own instead of waiting to be opened again.
///
/// Every change to a request writes a notification for the person it
/// concerns (nata.notify_request_change), so a new notification is the
/// signal. It arrives three ways: Supabase Realtime on nata.notifications
/// (migration 20240214), a push while the app is open, and coming back to the
/// app.
class LiveUpdates {
  LiveUpdates._();

  /// Goes up by one each time; pages listen and reload.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static RealtimeChannel? _channel;
  static String? _userId;
  static StreamSubscription<AuthState>? _auth;

  /// Something changed: open pages reload.
  static void ping() => changes.value++;

  /// Follows the signed-in member's notifications from now on.
  static void start() {
    try {
      final client = Supabase.instance.client;
      _auth ??= client.auth.onAuthStateChange.listen(
        (s) => _follow(client, s.session?.user.id),
      );
      _follow(client, client.auth.currentUser?.id);
    } catch (e) {
      debugPrint('[LiveUpdates] start: $e');
    }
  }

  static void _follow(SupabaseClient client, String? userId) {
    if (userId == _userId) return;
    final old = _channel;
    _channel = null;
    _userId = userId;
    if (old != null) unawaited(client.removeChannel(old));
    if (userId == null) return;
    try {
      _channel = client.channel('notifications:$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'nata',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => ping(),
        )
        ..subscribe();
    } catch (e) {
      debugPrint('[LiveUpdates] follow: $e');
    }
  }
}

/// Calls [reload] when [LiveUpdates] signals a change, at most once per
/// [wait] (several notifications often arrive together).
class LiveReload {
  final VoidCallback reload;
  final Duration wait;
  Timer? _timer;

  LiveReload(this.reload, {this.wait = const Duration(milliseconds: 600)}) {
    LiveUpdates.changes.addListener(_changed);
  }

  void _changed() {
    _timer?.cancel();
    _timer = Timer(wait, reload);
  }

  void dispose() {
    _timer?.cancel();
    LiveUpdates.changes.removeListener(_changed);
  }
}
