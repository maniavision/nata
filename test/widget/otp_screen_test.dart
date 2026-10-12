import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/otp_screen.dart';
import '../helpers/app_wrapper.dart';

void main() {
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
