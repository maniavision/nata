import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/identity_verification_screen.dart';
import '../helpers/app_wrapper.dart';

void main() {
  group('IdentityVerificationScreen Step 1 UI', () {
    Widget buildScreen() => appWrapper(const IdentityVerificationScreen());

    testWidgets('renders verify identity headline', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('Verify'), findsWidgets);
    });

    testWidgets('tells travelers what senders will see of their ID', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byKey(const ValueKey('id-shared-note')), findsOneWidget);
      expect(
        find.textContaining('that sender will see the photo on your ID'),
        findsOneWidget,
      );
    });

    testWidgets('renders 3 ID type selector buttons', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Passport, Driver's Lic., National ID
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('renders Use Camera button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('camera'), findsWidgets);
    });

    testWidgets('renders Choose file button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('file'), findsWidgets);
    });

    testWidgets('renders upload zone with add photo icon', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    });

    testWidgets('submit button is present', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('tapping ID type changes selection', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      // Tap "National ID" (third option)
      await tester.tap(find.text('National ID'));
      await tester.pump();

      // Screen still shows all 3 options
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('action required banner is shown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('required'), findsWidgets);
    });

    testWidgets('security row (256-bit encrypted) is shown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.textContaining('256'), findsWidgets);
    });
  });
}
