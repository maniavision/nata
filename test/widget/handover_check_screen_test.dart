import 'dart:typed_data';

import 'package:carrywise_app/screens/handover_check_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The sender hands the item to the traveler: they check the traveler's
/// face from the ID check and can take a photo of them with the item.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  late int picks;

  setUp(() {
    service = FakeRequestService();
    picks = 0;
  });

  Future<void> pump(WidgetTester tester, {Uint8List? photo}) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final request = sampleSentRequest(status: 'paid');
    await tester.pumpWidget(
      appWrapper(
        HandoverCheckScreen(
          request: request,
          service: service,
          photoPicker: (_) async {
            picks++;
            return photo;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String name() => sampleSentRequest(status: 'paid').trip.firstName;

  testWidgets('shows the traveler face from the ID check', (tester) async {
    service.handoverFace = const HandoverFace(
      selfieUrl: 'https://x/selfie.jpg',
      verified: true,
    );
    await pump(tester);

    expect(
      find.byKey(const ValueKey('handover-traveler-face')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('handover-traveler-verified')),
      findsOneWidget,
    );
    expect(find.text("Check it's ${name()}"), findsOneWidget);
    expect(find.textContaining("face from their ID check"), findsOneWidget);
  });

  testWidgets('without an ID photo, the profile photo and a note', (
    tester,
  ) async {
    service.handoverFace = const HandoverFace(verified: true);
    await pump(tester);

    expect(find.byKey(const ValueKey('handover-traveler-face')), findsNothing);
    expect(
      find.byKey(const ValueKey('handover-traveler-avatar')),
      findsOneWidget,
    );
    expect(find.textContaining("no ID photo to show"), findsOneWidget);
  });

  testWidgets('unverified traveler shows no verified badge', (tester) async {
    service.handoverFace = const HandoverFace(selfieUrl: 'https://x/s.jpg');
    await pump(tester);

    expect(
      find.byKey(const ValueKey('handover-traveler-verified')),
      findsNothing,
    );
  });

  testWidgets('the photo is optional: Done leaves without one', (tester) async {
    await pump(tester);

    expect(find.text('Optional'), findsOneWidget);
    expect(find.byKey(const ValueKey('handover-sender-photo')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('handover-done')));
    await tester.pumpAndSettle();
    expect(find.byType(HandoverCheckScreen), findsNothing);
    expect(service.senderPhotos, isEmpty);
  });

  testWidgets('taking a photo uploads it and shows it', (tester) async {
    await pump(tester, photo: kTransparentPng);

    await tester.tap(find.byKey(const ValueKey('handover-take-photo')));
    await tester.pumpAndSettle();

    expect(picks, 1);
    expect(service.senderPhotos, ['req-1']);
    expect(find.byKey(const ValueKey('handover-sender-photo')), findsOneWidget);
    expect(find.text('Photo saved'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets('a failed upload says so and shows no photo', (tester) async {
    service.failSenderPhoto = const RequestException(RequestFailure.other);
    await pump(tester, photo: kTransparentPng);

    await tester.tap(find.byKey(const ValueKey('handover-take-photo')));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save the photo. Please try again."),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('handover-sender-photo')), findsNothing);
  });

  testWidgets('cancelling the camera uploads nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('handover-take-photo')));
    await tester.pumpAndSettle();

    expect(picks, 1);
    expect(service.senderPhotos, isEmpty);
  });

  testWidgets('a photo taken before shows, with Retake', (tester) async {
    service.senderPhotoUrl = 'https://x/sender.jpg';
    await pump(tester);

    expect(find.byKey(const ValueKey('handover-sender-photo')), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
  });

  testWidgets('French', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        HandoverCheckScreen(
          request: sampleSentRequest(status: 'paid'),
          service: service,
        ),
        locale: const Locale('fr'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remettre votre article'), findsOneWidget);
    expect(find.text('Facultatif'), findsOneWidget);
  });
}
