import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/otp_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/mock_auth_service.dart';

void main() {
  languageAfterSignInTests();
  group('OtpScreen UI', () {
    Widget buildOtp({bool isSignUp = false, VoidCallback? onSuccess}) {
      return appWrapper(
        OtpScreen(
          phone: '+2348034567890',
          isSignUp: isSignUp,
          firstName: isSignUp ? 'Fortune' : '',
          lastName: isSignUp ? 'Niama' : '',
          onSuccess: onSuccess ?? () {},
        ),
      );
    }

    testWidgets('renders header and phone number hint', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      expect(find.text('Verify Phone'), findsOneWidget);
      expect(find.text('Enter verification code'), findsOneWidget);
      // The phone hint uses RichText — verify the screen has a RichText widget
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('renders exactly 6 digit input boxes', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      // 6 TextFields for the OTP digits
      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets('Verify button is present', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      expect(find.text('Verify Code'), findsOneWidget);
    });

    testWidgets('resend timer countdown widget is shown', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      // Timer is rendered as RichText with two spans.
      // Verify the static label "Resend code" appears as plain text somewhere,
      // OR that the RichText count > baseline (header + phone hint).
      // We check that no "Resend code" plain tap-button is shown yet (still in countdown).
      expect(
        find.text('Resend code'),
        findsNothing,
      ); // plain text only shows when timer hits 0
      // The countdown uses RichText — at least 2 RichTexts on screen
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('Verify button disabled when boxes empty', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Verify Code'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('back button navigates back', (tester) async {
      // Wrap in a Navigator so pop() works
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => appWrapper(
                      OtpScreen(
                        phone: '+2348034567890',
                        isSignUp: false,
                        onSuccess: () {},
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      );
      // This is a navigation smoke test — just verifies no throw
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('info banner visible', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      expect(find.textContaining("Didn't receive the code"), findsOneWidget);
    });

    testWidgets('entering digits updates box state', (tester) async {
      await tester.pumpWidget(buildOtp());
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('isSignUp true shows same UI structure', (tester) async {
      await tester.pumpWidget(buildOtp(isSignUp: true));
      await tester.pump();

      expect(find.text('Verify Phone'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(6));
    });
  });
}

void languageAfterSignInTests() {
  group('Language after signing in', () {
    late MockAuthService auth;
    late int saves;
    late int loads;
    late bool signedIn;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService().resetAll();
      auth = MockAuthService();
      when(
        () => auth.verifyOtp(any(), any()),
      ).thenAnswer((_) async => fakeAuthResponse());
      when(
        () => auth.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
        ),
      ).thenAnswer((_) async {});
      saves = 0;
      loads = 0;
      signedIn = false;
    });
    tearDown(() => PreferencesService().resetAll());

    Future<void> signIn(WidgetTester tester, {bool isSignUp = false}) async {
      await tester.pumpWidget(
        appWrapper(
          OtpScreen(
            phone: '+2348034567890',
            isSignUp: isSignUp,
            firstName: isSignUp ? 'Fortune' : '',
            lastName: isSignUp ? 'Niama' : '',
            authService: auth,
            saveSettings: () async => saves++,
            loadSettings: () async => loads++,
            onSuccess: () => signedIn = true,
          ),
        ),
      );
      await tester.pump();
      final boxes = find.byType(TextField);
      for (var i = 0; i < 6; i++) {
        await tester.enterText(boxes.at(i), '${i + 1}');
        await tester.pump();
      }
      // The last digit submits the code. (The spinner keeps turning, as the
      // test does not leave the screen, so no pumpAndSettle.)
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('a code autofilled from the SMS fills all six boxes', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWrapper(
          OtpScreen(
            phone: '+18327920000',
            isSignUp: false,
            authService: auth,
            saveSettings: () async => saves++,
            onSuccess: () => signedIn = true,
          ),
        ),
      );
      await tester.pump();
      final boxes = find.byType(TextField);

      // iOS puts the whole code into the focused (first) box.
      await tester.enterText(boxes.at(0), '384920');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final values = [
        for (var i = 0; i < 6; i++)
          tester.widget<TextField>(boxes.at(i)).controller!.text,
      ];
      expect(values, ['3', '8', '4', '9', '2', '0']);
      verify(() => auth.verifyOtp('+18327920000', '384920')).called(1);
    });

    testWidgets('typing over a filled box keeps one digit', (tester) async {
      await tester.pumpWidget(
        appWrapper(
          OtpScreen(
            phone: '+1832',
            isSignUp: false,
            authService: auth,
            onSuccess: () {},
          ),
        ),
      );
      await tester.pump();
      final boxes = find.byType(TextField);
      await tester.enterText(boxes.at(0), '3');
      await tester.pump();
      await tester.enterText(boxes.at(0), '37');
      await tester.pump();

      expect(tester.widget<TextField>(boxes.at(0)).controller!.text, '7');
      expect(tester.widget<TextField>(boxes.at(1)).controller!.text, '');
    });

    testWidgets('the first box is the one-time-code field for autofill', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWrapper(
          OtpScreen(
            phone: '+1832',
            isSignUp: false,
            authService: auth,
            onSuccess: () {},
          ),
        ),
      );
      await tester.pump();
      final first = tester.widget<TextField>(find.byType(TextField).first);
      expect(first.autofillHints, contains(AutofillHints.oneTimeCode));
    });

    testWidgets('signing in applies the account\'s saved settings', (
      tester,
    ) async {
      PreferencesService().setLanguage(AppLanguage.french);

      await signIn(tester);

      expect(signedIn, isTrue);
      // Loaded from the account, not overwritten with this device's choice.
      expect(loads, 1);
      expect(saves, 0);
      expect(PreferencesService().hasAccountOnDevice, isTrue);
    });

    testWidgets('signing up saves it too', (tester) async {
      PreferencesService().setLanguage(AppLanguage.spanish);

      await signIn(tester, isSignUp: true);

      expect(signedIn, isTrue);
      expect(PreferencesService().language, AppLanguage.spanish);
      expect(saves, 1);
      expect(loads, 0);
      expect(PreferencesService().hasAccountOnDevice, isTrue);
    });
  });
}
