import 'dart:async';

import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/otp_screen.dart';
import 'package:carrywise_app/services/biometric_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeBiometricService bio;
  late FakeAuthService auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    bio = FakeBiometricService();
    auth = FakeAuthService()..hasSession = true;
    PreferencesService().setFaceIdEnabled(true);
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      appWrapper(
        LoginScreen(
          authService: auth,
          biometricService: bio,
          autoFaceId: false,
          homeBuilder: (_) => const Scaffold(body: Text('HOME-SCREEN')),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapFaceId(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('login-face-id')));
    await tester.pumpAndSettle();
  }

  group('opening the sign-in page', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          LoginScreen(
            authService: auth,
            biometricService: bio,
            homeBuilder: (_) => const Scaffold(body: Text('HOME-SCREEN')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('with Face ID on, asks for the face and signs in', (
      tester,
    ) async {
      await open(tester);
      expect(bio.authenticateCalls, 1);
      expect(find.text('HOME-SCREEN'), findsOneWidget);
    });

    testWidgets('with Face ID off, waits for the phone number', (tester) async {
      PreferencesService().setFaceIdEnabled(false);
      await open(tester);
      expect(bio.authenticateCalls, 0);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('without a kept session, says nothing', (tester) async {
      auth.hasSession = false;
      await open(tester);
      expect(bio.authenticateCalls, 0);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('closing the prompt leaves the page as it is', (tester) async {
      bio.result = BiometricResult.cancelled;
      await open(tester);
      expect(bio.authenticateCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('the Face ID button', () {
    testWidgets('is there, with the Face ID label', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('login-face-id')), findsOneWidget);
      expect(find.text('Face ID'), findsOneWidget);
      expect(find.byIcon(Icons.face_retouching_natural), findsOneWidget);
    });

    testWidgets('signs in with a recognised face and goes to Home', (
      tester,
    ) async {
      await pump(tester);

      await tapFaceId(tester);

      expect(bio.authenticateCalls, 1);
      expect(find.text('HOME-SCREEN'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing); // the stack is cleared
    });

    testWidgets('opened from the sign-in prompt, lands on that page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          LoginScreen(
            authService: auth,
            biometricService: bio,
            autoFaceId: false,
            homeBuilder: (_) => const Scaffold(body: Text('HOME-SCREEN')),
            afterSignIn: (_) => const Scaffold(body: Text('TRAVELER-PAGE')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapFaceId(tester);

      expect(find.text('TRAVELER-PAGE'), findsOneWidget);
      // Back from it goes to Home, not to sign in.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME-SCREEN'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('explains itself in the system prompt', (tester) async {
      await pump(tester);

      await tapFaceId(tester);

      expect(bio.lastReason, "Confirm it's you to sign in to Nata");
    });

    testWidgets('the prompt text is translated', (tester) async {
      await pump(tester, locale: const Locale('es'));
      await tapFaceId(tester);
      expect(
        bio.lastReason,
        'Confirma que eres tú para iniciar sesión en Nata',
      );

      await pump(tester, locale: const Locale('fr'));
      await tapFaceId(tester);
      expect(
        bio.lastReason,
        "Confirmez que c'est vous pour vous connecter à Nata",
      );
    });

    testWidgets('does nothing visible when the user closes the prompt', (
      tester,
    ) async {
      bio.result = BiometricResult.cancelled;
      await pump(tester);

      await tapFaceId(tester);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('HOME-SCREEN'), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('a face that is not recognised says so and stays on sign in', (
      tester,
    ) async {
      bio.result = BiometricResult.failed;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text(
          "Face ID didn't recognise you. Try again or sign in with your phone number.",
        ),
        findsOneWidget,
      );
      expect(find.text('HOME-SCREEN'), findsNothing);
    });

    testWidgets('too many attempts: tells the user to use the phone number', (
      tester,
    ) async {
      bio.result = BiometricResult.lockedOut;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text('Face ID is locked for now. Sign in with your phone number.'),
        findsOneWidget,
      );
    });

    testWidgets('a result of "not set up" after the prompt is explained', (
      tester,
    ) async {
      bio.result = BiometricResult.notEnrolled;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text('Set up Face ID in your device settings first.'),
        findsOneWidget,
      );
    });

    testWidgets('a result of "not available" after the prompt is explained', (
      tester,
    ) async {
      bio.result = BiometricResult.notAvailable;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text("Face ID isn't available on this device."),
        findsOneWidget,
      );
    });
  });

  group('when Face ID cannot be used', () {
    testWidgets('a device without Face ID says so, and never asks', (
      tester,
    ) async {
      bio.availabilityResult = BiometricAvailability.unsupported;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text("Face ID isn't available on this device."),
        findsOneWidget,
      );
      expect(bio.authenticateCalls, 0);
    });

    testWidgets('Face ID not set up on the device: points to the settings', (
      tester,
    ) async {
      bio.availabilityResult = BiometricAvailability.notEnrolled;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text('Set up Face ID in your device settings first.'),
        findsOneWidget,
      );
      expect(bio.authenticateCalls, 0);
    });

    testWidgets('nobody signed in yet: asks to sign in with the phone first', (
      tester,
    ) async {
      auth.hasSession = false;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.textContaining('sign in with your phone number first'),
        findsOneWidget,
      );
      expect(bio.authenticateCalls, 0);
      expect(find.text('HOME-SCREEN'), findsNothing);
    });

    testWidgets('signed in without "Remember me": Face ID stays off', (
      tester,
    ) async {
      PreferencesService().setFaceIdEnabled(false);
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.textContaining('sign in with your phone number first'),
        findsOneWidget,
      );
      expect(bio.authenticateCalls, 0);
    });

    testWidgets('the messages are translated', (tester) async {
      bio.availabilityResult = BiometricAvailability.unsupported;
      await pump(tester, locale: const Locale('es'));
      await tapFaceId(tester);
      expect(
        find.text('Face ID no está disponible en este dispositivo.'),
        findsOneWidget,
      );

      await pump(tester, locale: const Locale('fr'));
      await tapFaceId(tester);
      expect(
        find.text("Face ID n'est pas disponible sur cet appareil."),
        findsOneWidget,
      );
    });

    testWidgets('the device check happens before the session check', (
      tester,
    ) async {
      bio.availabilityResult = BiometricAvailability.unsupported;
      auth.hasSession = false;
      await pump(tester);

      await tapFaceId(tester);

      expect(
        find.text("Face ID isn't available on this device."),
        findsOneWidget,
      );
    });
  });

  group('while the face is being checked', () {
    testWidgets('shows a spinner and ignores a second tap', (tester) async {
      bio.gate = Completer<void>();
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('login-face-id')));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('login-face-id')));
      await tester.pump();
      expect(bio.authenticateCalls, 1);

      bio.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('HOME-SCREEN'), findsOneWidget);
    });

    testWidgets('the spinner goes away afterwards', (tester) async {
      bio.result = BiometricResult.failed;
      await pump(tester);

      await tapFaceId(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.face_retouching_natural), findsOneWidget);
    });

    testWidgets('it can be tried again after a failure', (tester) async {
      bio.result = BiometricResult.failed;
      await pump(tester);
      await tapFaceId(tester);
      expect(find.text('HOME-SCREEN'), findsNothing);

      bio.result = BiometricResult.success;
      await tapFaceId(tester);

      expect(find.text('HOME-SCREEN'), findsOneWidget);
    });
  });

  group('turning Face ID on', () {
    Future<void> signInWithPhone(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, '202 555 0123');
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(OtpScreen), findsOneWidget);
      // The one-time code was accepted.
      tester.widget<OtpScreen>(find.byType(OtpScreen)).onSuccess();
      await tester.pumpAndSettle();
    }

    testWidgets('signing in with "Remember me" ticked switches it on', (
      tester,
    ) async {
      PreferencesService().setFaceIdEnabled(false);
      await pump(tester);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

      await signInWithPhone(tester);

      expect(PreferencesService().faceIdEnabled, isTrue);
      expect(find.text('HOME-SCREEN'), findsOneWidget);
    });

    testWidgets('signing in without "Remember me" keeps it off', (
      tester,
    ) async {
      PreferencesService().setFaceIdEnabled(false);
      await pump(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

      await signInWithPhone(tester);

      expect(PreferencesService().faceIdEnabled, isFalse);
    });

    testWidgets('signing in again without "Remember me" switches it off', (
      tester,
    ) async {
      PreferencesService().setFaceIdEnabled(true);
      await pump(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      await signInWithPhone(tester);

      expect(PreferencesService().faceIdEnabled, isFalse);
    });
  });
}
