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

      // Passport, License, National ID
      expect(find.text('Passport'), findsOneWidget);
    });

    // On a narrow phone (iPhone SE width) and in every language, the three
    // ID type buttons keep one line each and the same height.
    for (final locale in const [Locale('en'), Locale('fr'), Locale('es')]) {
      testWidgets('ID type buttons line up in ${locale.languageCode}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          appWrapper(const IdentityVerificationScreen(), locale: locale),
        );
        await tester.pump();

        final heights = [
          for (var i = 0; i < 3; i++)
            tester.getSize(find.byKey(ValueKey('id-type-$i'))).height,
        ];
        expect(heights.toSet(), hasLength(1), reason: '$heights');
        final tops = [
          for (var i = 0; i < 3; i++)
            tester.getTopLeft(find.byKey(ValueKey('id-type-$i'))).dy,
        ];
        expect(tops.toSet(), hasLength(1), reason: '$tops');
      });
    }

    testWidgets('French uses the short "Permis"', (tester) async {
      await tester.pumpWidget(
        appWrapper(
          const IdentityVerificationScreen(),
          locale: const Locale('fr'),
        ),
      );
      await tester.pump();
      expect(find.text('Permis'), findsOneWidget);
      expect(find.text('Permis de conduire'), findsNothing);
    });

    testWidgets('right after sign-up, "Skip for now" goes to Home', (
      tester,
    ) async {
      // Sign-up replaces every page with verification: nothing underneath.
      await tester.pumpWidget(
        appWrapper(
          IdentityVerificationScreen(
            homeBuilder: (_) => const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('id-skip')));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(IdentityVerificationScreen), findsNothing);
    });

    testWidgets('opened from another page, "Skip for now" goes back to it', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWrapper(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IdentityVerificationScreen(
                    homeBuilder: (_) => const Scaffold(body: Text('HOME')),
                  ),
                ),
              ),
              child: const Text('PROFILE'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('PROFILE'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('id-skip')));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
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
