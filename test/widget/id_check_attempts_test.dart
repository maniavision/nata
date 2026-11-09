import 'package:carrywise_app/screens/identity_verification_screen.dart';
import 'package:carrywise_app/services/id_document_check_service.dart';
import 'package:carrywise_app/services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// An ID check that always fails the same way.
class _FailingCheck extends IdDocumentCheckService {
  _FailingCheck(this.result)
    : super(
        readText: (_, _) async => '',
        detectFace: (_, _) async => true,
        loadProfile: () async => null,
      );
  final IdCheckResult result;

  @override
  Future<IdCheckResult> check({
    required Uint8List bytes,
    required String fileName,
    required IdDocumentType idType,
  }) async => result;
}

/// Counts failures like the server and records what was sent.
class _FakeVerification extends VerificationService {
  _FakeVerification() : super.test();
  int failures = 0;
  bool countFails = false;
  final uploads = <String>[];
  final submitted = <IdDocumentType>[];
  final sentForReview = <String>[];

  @override
  Future<int> recordIdCheckFailure() async {
    if (countFails) throw Exception('offline');
    return ++failures;
  }

  @override
  Future<String> uploadDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    uploads.add(fileName);
    return 'me/$fileName';
  }

  @override
  Future<void> submitVerification({
    required IdDocumentType idType,
    required String documentPath,
  }) async => submitted.add(idType);

  @override
  Future<void> sendIdForReview(String reason) async =>
      sentForReview.add(reason);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeVerification verification;
  late FakeEmergencyContactService contacts;

  setUp(() {
    verification = _FakeVerification();
    contacts = FakeEmergencyContactService();
  });

  Future<void> pump(
    WidgetTester tester, {
    IdCheckResult result = IdCheckResult.notAnId,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        IdentityVerificationScreen(
          idCheck: _FailingCheck(result),
          verificationService: verification,
          emergencyService: contacts,
          initialDocument: (Uint8List.fromList([1, 2, 3]), 'id.jpg'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Submit for Verification'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
  }

  bool shows(String text) => find.textContaining(text).evaluate().isNotEmpty;

  testWidgets('help grows with each failed photo', (tester) async {
    await pump(tester);

    await submit(tester);
    expect(shows("This doesn't look like an ID document"), isTrue);
    expect(shows('Tips: use good light'), isFalse);
    expect(shows('better camera'), isFalse);

    await submit(tester);
    expect(shows('Tips: use good light'), isTrue);
    expect(shows('better camera'), isFalse);

    await submit(tester);
    expect(shows('Tips: use good light'), isTrue);
    expect(shows('better camera'), isTrue);
    expect(shows("we'll send your ID to our team"), isFalse);

    await submit(tester);
    expect(shows('better camera'), isTrue);
    expect(shows("we'll send your ID to our team"), isTrue);

    // Nothing sent yet.
    expect(verification.uploads, isEmpty);
    expect(verification.sentForReview, isEmpty);
  });

  testWidgets('the 5th failed photo sends the ID to the team', (tester) async {
    await pump(tester, result: IdCheckResult.noFace);
    for (var i = 0; i < 5; i++) {
      await submit(tester);
    }

    expect(verification.uploads, ['id_document.jpg']);
    expect(verification.submitted, [IdDocumentType.passport]);
    expect(verification.sentForReview, ['no_face']);

    // No face scan: on to the emergency contact, then "being reviewed".
    await tester.enterText(
      find.byKey(const ValueKey('contact-name')),
      'Jane Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contact-phone')),
      '+44 7700 900123',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contact-finish')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('verification-done-title')))
          .data,
      'Your ID is being reviewed',
    );
  });

  testWidgets('a failure count that cannot be saved still counts locally', (
    tester,
  ) async {
    verification.countFails = true;
    await pump(tester);
    await submit(tester);
    await submit(tester);
    expect(shows('Tips: use good light'), isTrue);
  });
}
