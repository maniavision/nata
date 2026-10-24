import 'package:supabase_flutter/supabase_flutter.dart';

/// What each tab page last showed (requests, trips, conversations, profile
/// figures...), kept in memory for the app session.
///
/// Switching tabs builds the page again; with this it shows what it had
/// straight away and refreshes quietly behind it, instead of a spinner each
/// time. Home also fills it for the other tabs once it opens, so even a
/// first visit is ready.
///
/// The values belong to the signed-in user: a different user (or nobody)
/// finds the cache empty, and signing out clears it.
class ScreenCache {
  ScreenCache._();

  static final Map<String, Object?> _values = {};
  static String? _owner;

  /// Who is signed in; replaced in tests.
  static String? Function() userId = () {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  };

  static bool _ownedByCurrentUser() {
    final uid = userId();
    if (uid == null) {
      _values.clear();
      _owner = null;
      return false;
    }
    if (_owner != uid) {
      _values.clear();
      _owner = uid;
    }
    return true;
  }

  /// The value last kept under [key] for the signed-in user, if any.
  static T? read<T>(String key) {
    if (!_ownedByCurrentUser()) return null;
    final v = _values[key];
    return v is T ? v : null;
  }

  /// Keeps [value] under [key] for the signed-in user.
  static void write(String key, Object? value) {
    if (!_ownedByCurrentUser()) return;
    _values[key] = value;
  }

  /// Forgets everything (signing out).
  static void clear() {
    _values.clear();
    _owner = null;
  }
}
