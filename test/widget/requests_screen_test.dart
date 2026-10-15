import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(const RequestsScreen(), locale: locale ?? const Locale('en')),
    );
    await tester.pump();
  }

  group('Incoming tab', () {
    testWidgets('shows the accepted request above the pending ones', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('ACCEPTED & IN PROGRESS'), findsOneWidget);
      expect(find.text('1 Active'), findsOneWidget);
      expect(find.text('PENDING REQUESTS (2)'), findsOneWidget);
      expect(find.text('Awaiting your response'), findsOneWidget);

      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(
        top('ACCEPTED & IN PROGRESS'),
        lessThan(top('PENDING REQUESTS (2)')),
      );
    });

    testWidgets('the accepted card: payout, trip, item and next action', (
      tester,
    ) async {
      await pump(tester);

      final card = find.byKey(const ValueKey('accepted-request-card'));
      Finder inCard(String text) =>
          find.descendant(of: card, matching: find.text(text));

      expect(inCard('Sarah Adeleke'), findsOneWidget);
      expect(inCard('Accepted'), findsOneWidget);
      expect(inCard('Sender · Escrow Funded'), findsOneWidget);
      expect(inCard('\$38'), findsOneWidget);
      expect(inCard('Your payout'), findsOneWidget);
      expect(inCard('Lagos (LOS) → London (LHR)'), findsOneWidget);
      expect(inCard('iPad Mini (Sealed Box · 0.6 kg)'), findsOneWidget);
      expect(inCard('Attach Received Photo'), findsOneWidget);
      expect(inCard('Manage Delivery & Attach Proof'), findsOneWidget);
    });

    testWidgets('the incoming badge counts accepted and pending', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('requests-tab-0')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pending requests keep Accept and Decline', (tester) async {
      await pump(tester);

      expect(find.text('Chioma Eze'), findsOneWidget);
      expect(find.text('Tunde Adeleke'), findsOneWidget);
      expect(find.text('Accept Request'), findsNWidgets(2));
      expect(find.text('Decline'), findsNWidgets(2));
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('ACCEPTÉES ET EN COURS'), findsOneWidget);
      expect(find.text('Votre paiement'), findsOneWidget);
    });
  });
}
