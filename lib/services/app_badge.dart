import 'dart:async';

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

import 'auth_gate.dart';
import 'notification_service.dart';
import 'unread_messages.dart';

/// The number on the app icon: the member's unread notifications.
///
/// Pushes set it while the app is closed (send-push puts the count in each
/// one). The app sets it again whenever the count can change: when it opens
/// or comes back, when a push arrives while it's open, when a notification is
/// read (one, all, or a chat's messages), and back to 0 on sign-out.
/// [unread] holds the same count for the bell on Home. Each refresh also
/// updates the unread chat messages on the Messages tab (UnreadMessages).
class AppBadge {
  AppBadge._();

  /// The last unread count, for the app's own badges (Home's bell).
  static final ValueNotifier<int> unread = ValueNotifier(0);

  /// Replaced in tests.
  static Future<int> Function() loadUnread = () =>
      NotificationService().unreadCount();
  static Future<void> Function(int count) show = (count) =>
      AppBadgePlus.updateBadge(count);

  /// Sets the badge to the current unread count (0 when signed out).
  static Future<void> refresh() async {
    unawaited(UnreadMessages.refresh());
    try {
      final count = AuthGate.isSignedIn() ? await loadUnread() : 0;
      unread.value = count < 0 ? 0 : count;
      await show(unread.value);
    } catch (e) {
      debugPrint('[AppBadge] refresh: $e');
    }
  }

  /// No badge (signing out).
  static Future<void> clear() async {
    unread.value = 0;
    UnreadMessages.clear();
    try {
      await show(0);
    } catch (e) {
      debugPrint('[AppBadge] clear: $e');
    }
  }
}
