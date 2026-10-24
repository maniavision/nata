import 'package:flutter/foundation.dart';

import 'auth_gate.dart';
import 'message_service.dart';

/// How many chat messages the member hasn't read yet, across all their
/// conversations: the count on the Messages tab.
///
/// Refreshed with the app icon's badge (AppBadge.refresh: when the app opens
/// or comes back, when a push arrives while it's open, when a chat is read),
/// and whenever the Messages list loads; 0 when signed out.
class UnreadMessages {
  UnreadMessages._();

  static final ValueNotifier<int> count = ValueNotifier(0);

  /// The member's conversations; replaced in tests.
  static Future<List<ConversationSummary>> Function() loadConversations = () =>
      MessageService().conversations();

  /// Asks for the member's conversations and adds up what is unread.
  static Future<void> refresh() async {
    try {
      if (!AuthGate.isSignedIn()) {
        count.value = 0;
        return;
      }
      update(await loadConversations());
    } catch (e) {
      debugPrint('[UnreadMessages] refresh: $e');
    }
  }

  /// From conversations already loaded (the Messages list).
  static void update(List<ConversationSummary> conversations) {
    count.value = conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  /// Nothing unread (signing out).
  static void clear() => count.value = 0;
}
