/// Which chat is on screen, so a message arriving for it doesn't also show
/// as a banner (PushService). Chats set it while they're shown.
class ChatPresence {
  ChatPresence._();

  static String? _current;

  /// The chat on screen: 'conversation:<id>' or 'recipient:<request id>'.
  static String? get current => _current;

  static String conversation(String id) => 'conversation:$id';
  static String recipient(String requestId) => 'recipient:$requestId';

  static void enter(String key) => _current = key;

  /// Leaving [key] (only clears it if no other chat took its place).
  static void leave(String key) {
    if (_current == key) _current = null;
  }
}
