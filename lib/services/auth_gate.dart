import 'package:flutter/material.dart';

import '../l10n/l10n_ext.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

/// Browsing works signed out: Home and searching travelers. Anything further
/// (opening a traveler, the other tabs, notifications, adding a trip) asks
/// the visitor to sign in or create an account first.
class AuthGate {
  AuthGate._();

  /// Whether someone is signed in. Replaced in tests.
  static bool Function() isSignedIn = () => AuthService().isSignedIn;

  /// True when signed in. Otherwise opens Sign In (with a way back) and
  /// returns false, so the caller stops there.
  static bool check(BuildContext context) {
    if (isSignedIn()) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.signInToContinue)));
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
    return false;
  }
}
