import 'dart:async';

import 'package:carrywise_app/services/auth_gate.dart';
import 'package:carrywise_app/services/home_search_memory.dart';
import 'package:carrywise_app/services/verify_gate.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs around every test file (picked up by `flutter test` by name).
///
/// The Home search is remembered in memory for the whole app session, so
/// without this a search picked in one test would show up in the next.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(HomeSearchMemory.clear);
  // Screens are tested as a signed-in user unless a test says otherwise.
  setUp(() => AuthGate.isSignedIn = () => true);
  // ...and as a verified one, who may post trips and send requests.
  setUp(() => VerifyGate.status = () async => 'verified');
  await testMain();
}
