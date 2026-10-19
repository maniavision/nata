import 'package:camera/camera.dart';
import 'package:carrywise_app/widgets/camera_denied_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('isCameraDenied', () {
    test('image picker: access denied or restricted', () {
      expect(
        isCameraDenied(PlatformException(code: 'camera_access_denied')),
        isTrue,
      );
      expect(
        isCameraDenied(PlatformException(code: 'camera_access_restricted')),
        isTrue,
      );
      expect(isCameraDenied(PlatformException(code: 'no_camera')), isFalse);
    });

    test('camera plugin: access denied', () {
      expect(
        isCameraDenied(CameraException('CameraAccessDenied', null)),
        isTrue,
      );
      expect(
        isCameraDenied(
          CameraException('CameraAccessDeniedWithoutPrompt', null),
        ),
        isTrue,
      );
      expect(isCameraDenied(CameraException('cameraNotFound', null)), isFalse);
    });

    test('anything else is not a denial', () {
      expect(isCameraDenied(Exception('boom')), isFalse);
    });
  });

  testWidgets('the sheet explains the fix and opens Settings', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCameraDeniedSheet(
                context,
                openSettings: () async => opened++,
              ),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Camera access is off'), findsOneWidget);
    expect(find.text('Settings > Nata Delivery > Camera'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-denied-settings')));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.byKey(const ValueKey('camera-denied')), findsNothing);
  });
}
