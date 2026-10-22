import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';

import 'auth_gate.dart';
import 'notification_service.dart';

/// The number on the app icon: the member's unread notifications.
///
/// Pushes set it while the app is closed (send-push puts the count in each
/// one). The app sets it again whenever the count can change: when it opens
/// or comes back, when a push arrives while it's open, when a notification is
/// read (one, all, or a chat's messages), and back to 0 on sign-out.
class AppBadge {
  AppBadge._();

  /// Replaced in tests.
  static Future<int> Function() loadUnread = () =>
      NotificationService().unreadCount();
  static Future<void> Function(int count) show = (count) =>
      AppBadgePlus.updateBadge(count);

  /// Sets the badge to the current unread count (0 when signed out).
  static Future<void> refresh() async {
    try {
      final count = AuthGate.isSignedIn() ? await loadUnread() : 0;
      await show(count < 0 ? 0 : count);
    } catch (e) {
      debugPrint('[AppBadge] refresh: $e');
    }
  }

  /// No badge (signing out).
  static Future<void> clear() async {
    try {
      await show(0);
    } catch (e) {
      debugPrint('[AppBadge] clear: $e');
    }
  }
}
