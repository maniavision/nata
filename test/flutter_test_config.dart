import 'dart:async';

import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/services/auth_gate.dart';
import 'package:carrywise_app/services/home_search_memory.dart';
import 'package:carrywise_app/services/screen_cache.dart';
import 'package:carrywise_app/services/support_service.dart';
import 'package:carrywise_app/services/verify_gate.dart';
import 'package:carrywise_app/widgets/coach_tips.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs around every test file (picked up by `flutter test` by name).
///
/// The Home search is remembered in memory for the whole app session, so
/// without this a search picked in one test would show up in the next.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(HomeSearchMemory.clear);
  // Pages start empty in each test, as for a user signed in just now.
  setUp(() {
    ScreenCache.clear();
    ScreenCache.userId = () => 'test-user';
    // Home doesn't reach for the real services to preload the other tabs.
    HomeScreen.tabPreloads = [];
    // ...nor covers itself with first-visit tips.
    CoachTips.enabled = false;
  });
  // Screens are tested as a signed-in user unless a test says otherwise.
  setUp(() => AuthGate.isSignedIn = () => true);
  // ...and as a verified one, who may post trips and send requests.
  setUp(() => VerifyGate.status = () async => 'verified');
  // ...who isn't Nata staff.
  setUp(() => SupportAccess.isAdmin = () async => false);
  await testMain();
}
