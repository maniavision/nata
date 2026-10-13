import 'package:camera/camera.dart';
import 'package:carrywise_app/services/face_verification_service.dart';
import 'package:carrywise_app/widgets/face_scan_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late int done;
  late int back;

  Future<void> pump(
    WidgetTester tester, {
    Locale? locale,
    Object cameraError = 'no camera',
  }) async {
    done = 0;
    back = 0;
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: FaceScanStep(
            service: FaceVerificationService(),
            onDone: () => done++,
            onBack: () => back++,
            cameras: () async => throw cameraError,
          ),
        ),
        locale: locale ?? const Locale('en'),
      ),
    );
    await tester.pump();
  }

  String status(WidgetTester t) =>
      t.widget<Text>(find.byKey(const ValueKey('face-scan-status'))).data!;

  testWidgets('explains the scan before starting the camera', (tester) async {
    await pump(tester);

    expect(find.text('3D Biometric Face Scan'), findsOneWidget);
    expect(status(tester), contains('blink and turn your head'));
    expect(find.text('Start Biometric Scan'), findsOneWidget);
    expect(find.byKey(const ValueKey('face-scan-skip')), findsNothing);
  });

  testWidgets('says the selfie is sent to the verification service', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('compared with your ID photo'), findsOneWidget);
    expect(find.textContaining('processed locally'), findsNothing);
  });

  testWidgets('back goes back', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('face-scan-back')));

    expect(back, 1);
  });

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('face-scan-action')));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a camera error: a retry and a way on', (tester) async {
    await pump(tester);

    await start(tester);

    expect(status(tester), 'Something went wrong. Please try again.');
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('face-scan-skip')));

    expect(done, 1);
  });

  testWidgets('camera access denied: says how to allow it', (tester) async {
    await pump(
      tester,
      cameraError: CameraException('CameraAccessDenied', 'denied'),
    );

    await start(tester);

    expect(
      status(tester),
      'Allow camera access in Settings to scan your face.',
    );
  });

  testWidgets('try again starts over', (tester) async {
    await pump(tester);
    await start(tester);

    await start(tester);

    expect(status(tester), 'Something went wrong. Please try again.');
    expect(done, 0);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, locale: const Locale('fr'));

    expect(status(tester), contains('cligner des yeux'));
  });
}
