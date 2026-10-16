import 'package:carrywise_app/screens/incoming_request_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The Incoming tab: requests made on the traveler's own trips.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;

  setUp(() {
    service = FakeRequestService()
      ..incoming = [
        sampleIncoming(
          id: 'acc',
          status: 'paid',
          firstName: 'Sarah',
          lastName: 'Adeleke',
          payoutUsd: 38,
        ),
        sampleIncoming(id: 'p1'),
        sampleIncoming(
          id: 'p2',
          firstName: 'Tunde',
          lastName: 'Adeleke',
          payoutUsd: 26.5,
          senderDeliveries: 2,
          photoPaths: const [],
        ),
      ];
  });

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        RequestsScreen(
          requestService: service,
          exchangeRates: FakeExchangeRateService(),
        ),
        locale: locale ?? const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Incoming tab', () {
    testWidgets('loads the requests made on the traveler\'s trips', (
      tester,
    ) async {
      await pump(tester);

      expect(service.incomingCalls, 1);
      expect(find.text('Sarah Adeleke'), findsOneWidget);
      expect(find.text('Chioma Eze'), findsOneWidget);
      expect(find.text('Tunde Adeleke'), findsOneWidget);
      // No sample data left.
      expect(find.textContaining('iPad Mini'), findsNothing);
    });

    testWidgets('shows the accepted request above the pending ones', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('ACCEPTED & IN PROGRESS'), findsOneWidget);
      expect(find.text('1 Active'), findsOneWidget);
      expect(find.text('PENDING REQUESTS (2)'), findsOneWidget);
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(
        top('ACCEPTED & IN PROGRESS'),
        lessThan(top('PENDING REQUESTS (2)')),
      );
    });

    testWidgets('the accepted card: status, payout, trip, item, next step', (
      tester,
    ) async {
      await pump(tester);

      final card = find.byKey(const ValueKey('accepted-request-card'));
      Finder inCard(String text) =>
          find.descendant(of: card, matching: find.text(text));

      expect(inCard('Sarah Adeleke'), findsOneWidget);
      expect(inCard('Paid'), findsOneWidget);
      expect(inCard('Sender · Escrow Funded'), findsOneWidget);
      expect(inCard(r'$38'), findsOneWidget);
      expect(inCard('Your payout'), findsOneWidget);
      expect(inCard('Lagos → London'), findsOneWidget);
      expect(inCard('Apple Watch Series 9 (0.45 kg)'), findsOneWidget);
      expect(inCard('Pick up the item'), findsOneWidget);
      expect(inCard('Manage Delivery & Attach Proof'), findsOneWidget);
    });

    testWidgets('an accepted request not paid yet waits for payment', (
      tester,
    ) async {
      service.incoming = [sampleIncoming(id: 'a', status: 'accepted')];
      await pump(tester);

      expect(find.text('Sender · Awaiting payment'), findsOneWidget);
      expect(find.text("Wait for the sender's payment"), findsOneWidget);
      expect(find.text('View Request'), findsOneWidget);
    });

    testWidgets('the badge counts accepted and pending', (tester) async {
      await pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('requests-tab-0')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a pending card shows the sender, trip, item and photos', (
      tester,
    ) async {
      await pump(tester);

      final card = find.byKey(const ValueKey('incoming-request-p1'));
      Finder inCard(String text) =>
          find.descendant(of: card, matching: find.text(text));
      expect(inCard('Sender · 5 deliveries'), findsOneWidget);
      expect(inCard(r'$32'), findsOneWidget);
      expect(inCard('Jun 22, 2030'), findsOneWidget);
      expect(inCard('0.45 kg · 15 x 8 x 4 cm'), findsOneWidget);
      expect(inCard('1 factory-sealed photo attached'), findsOneWidget);
    });

    testWidgets('empty, and a failure with Retry', (tester) async {
      service.incoming = [];
      await pump(tester);
      expect(find.byKey(const ValueKey('incoming-empty')), findsOneWidget);

      service.failIncoming = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester);
      expect(find.byKey(const ValueKey('incoming-error')), findsOneWidget);

      service.failIncoming = false;
      service.incoming = [sampleIncoming()];
      await tester.tap(find.byKey(const ValueKey('incoming-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Chioma Eze'), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('ACCEPTÉES ET EN COURS'), findsOneWidget);
      expect(find.text('Votre paiement'), findsOneWidget);
      expect(find.text('Récupérer l\'article'), findsOneWidget);
    });
  });

  group('Accept and Decline', () {
    testWidgets('Accept answers the request and refreshes the list', (
      tester,
    ) async {
      await pump(tester);
      final before = service.incomingCalls;

      await tester.tap(find.byKey(const ValueKey('incoming-accept-p1')));
      await tester.pumpAndSettle();

      expect(service.accepted, ['p1']);
      expect(service.incomingCalls, before + 1);
      expect(
        find.text('Request accepted. The sender has 24 hours to pay.'),
        findsOneWidget,
      );
      expect(find.text('2 Active'), findsOneWidget);
      expect(find.text('PENDING REQUESTS (1)'), findsOneWidget);
    });

    testWidgets('Decline asks first, with an optional reason', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('incoming-decline-p2')));
      await tester.pumpAndSettle();
      expect(find.text('Decline this request?'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('decline-reason')),
        'Bag is full',
      );
      await tester.tap(find.byKey(const ValueKey('decline-confirm')));
      await tester.pumpAndSettle();

      expect(service.declined.single, (id: 'p2', reason: 'Bag is full'));
      expect(find.text('Tunde Adeleke'), findsNothing);
      expect(find.text('Request declined.'), findsOneWidget);
    });

    testWidgets('Keep it leaves the request as it was', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('incoming-decline-p2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('decline-keep')));
      await tester.pumpAndSettle();

      expect(service.declined, isEmpty);
      expect(find.text('Tunde Adeleke'), findsOneWidget);
    });

    for (final c in {
      RequestFailure.rateUnavailable:
          "The exchange rate isn't available right now, so the price can't be fixed. Please try again later.",
      RequestFailure.notPending: 'This request has already been answered.',
      RequestFailure.other: 'Could not accept the request. Please try again.',
    }.entries) {
      testWidgets('accept refused (${c.key.name}) is explained', (
        tester,
      ) async {
        service.failAnswer = RequestException(c.key);
        await pump(tester);

        await tester.tap(find.byKey(const ValueKey('incoming-accept-p1')));
        await tester.pumpAndSettle();

        expect(find.text(c.value), findsOneWidget);
      });
    }

    testWidgets('tapping a card opens its details', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Tunde Adeleke'));
      await tester.pumpAndSettle();

      expect(find.byType(IncomingRequestScreen), findsOneWidget);
    });
  });
}
