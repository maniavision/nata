import 'package:flutter/material.dart';

import '../widgets/sign_in_prompt_sheet.dart';
import 'auth_service.dart';

/// Browsing works signed out: Home and searching travelers. Anything further
/// (opening a traveler, the other tabs, notifications, adding a trip) asks
/// the visitor to sign in or create an account first.
class AuthGate {
  AuthGate._();

  /// Whether someone is signed in. Replaced in tests.
  static bool Function() isSignedIn = () => AuthService().isSignedIn;

  /// True when signed in. Otherwise shows the sign-in prompt, with [message]
  /// saying what the visitor was trying to do, and returns false so the
  /// caller stops there. [next] is the page they were opening: after signing
  /// in they land on it (above Home) instead of on Home.
  static bool check(
    BuildContext context, {
    String? message,
    WidgetBuilder? next,
  }) {
    if (isSignedIn()) return true;
    showSignInPrompt(context, message: message, next: next);
    return false;
  }
}
