import 'package:carrywise_app/screens/checkout_escrow_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Checkout: the sender checks the traveler's flight ticket (step 1) before
/// the pay button unlocks.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  final now = DateTime(2030, 6, 21, 12);

  setUp(() => service = FakeRequestService());

  SentRequest accepted({
    String? ticket = 'traveler-1/ticket.pdf',
    DateTime? checkedAt,
    DateTime? idCheckedAt,
    bool verified = true,
    DateTime? expiresAt,
  }) => sampleSentRequest(
    status: 'accepted',
    displayCurrency: 'XOF',
    displayCost: 59126,
    displayFee: 6440,
    displayTotal: 65566,
    expiresAt: expiresAt ?? now.add(const Duration(hours: 23, minutes: 48)),
    ticketCheckedAt: checkedAt,
    idCheckedAt: idCheckedAt,
    travelerVerified: verified,
    ticketReceiptPath: ticket,
    bookingReference: 'X7KQ9R',
  );

  Future<void> pump(WidgetTester tester, SentRequest request) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        CheckoutEscrowScreen(
          request: request,
          service: service,
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder ticketStatus(String text) => find.descendant(
    of: find.byKey(const ValueKey('ticket-status')),
    matching: find.text(text),
  );

  Finder idStatus(String text) => find.descendant(
    of: find.byKey(const ValueKey('id-status')),
    matching: find.text(text),
  );

  ElevatedButton payButton(WidgetTester t) =>
      t.widget<ElevatedButton>(find.byKey(const ValueKey('checkout-pay')));

  testWidgets('shows the real request, its fixed price and deadline', (
    tester,
  ) async {
    await pump(tester, accepted());

    expect(find.text('Amara Kalu'), findsWidgets);
    expect(find.textContaining('Lagos → London'), findsWidgets);
    expect(find.text('AirPods Max'), findsOneWidget);
    expect(find.text('0.9 kg'), findsOneWidget);
    expect(find.text('XOF 59,126'), findsOneWidget);
    expect(find.text('XOF 6,440'), findsOneWidget);
    expect(find.text('XOF 65,566'), findsOneWidget);
    expect(
      find.textContaining('Request expires in 23h 48m', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('23:48:00'), findsOneWidget);
    // No sample data left.
    expect(find.textContaining('MacBook'), findsNothing);
    expect(find.textContaining(r'$50.00'), findsNothing);
  });

  testWidgets('step 1 shows the ticket and its details', (tester) async {
    await pump(tester, accepted());

    expect(find.text('STEP 1 · VALIDATE FLIGHT TICKET'), findsOneWidget);
    expect(ticketStatus('Not validated'), findsOneWidget);
    expect(find.text('Flight ticket (PDF)'), findsOneWidget);
    expect(find.text('View full ticket'), findsOneWidget);
    expect(find.text('X7KQ9R'), findsOneWidget);
    expect(find.text('Jun 22, 2030'), findsOneWidget);
    expect(
      find.textContaining('Amara uploaded their flight ticket'),
      findsOneWidget,
    );
  });

  testWidgets('payment stays locked until the ticket and the ID are checked', (
    tester,
  ) async {
    await pump(tester, accepted());

    expect(payButton(tester).onPressed, isNull);
    expect(
      find.text('Validate ticket and ID to unlock payment'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ticket-confirm')));
    await tester.pump();
    await tester.pump();

    expect(service.ticketChecks, ['req-1']);
    expect(ticketStatus('Checked'), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-confirm')), findsNothing);
    // The ID is still to be checked.
    expect(payButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('id-confirm')));
    await tester.pump();
    await tester.pump();

    expect(service.idChecks, ['req-1']);
    expect(idStatus('Checked'), findsOneWidget);
    expect(payButton(tester).onPressed, isNotNull);
    expect(find.text('Pay XOF 65,566 into Escrow'), findsOneWidget);
  });

  testWidgets('a ticket checked on an earlier visit stays checked', (
    tester,
  ) async {
    await pump(
      tester,
      accepted(
        checkedAt: DateTime(2030, 6, 21, 9),
        idCheckedAt: DateTime(2030, 6, 21, 9),
      ),
    );

    expect(ticketStatus('Checked'), findsOneWidget);
    expect(idStatus('Checked'), findsOneWidget);
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('paying says payments are not live yet, and charges nothing', (
    tester,
  ) async {
    await pump(
      tester,
      accepted(
        checkedAt: DateTime(2030, 6, 21, 9),
        idCheckedAt: DateTime(2030, 6, 21, 9),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('checkout-pay')));
    await tester.pump();

    expect(
      find.text(
        "Payments aren't available yet. You'll be able to pay here soon.",
      ),
      findsOneWidget,
    );
    expect(find.byType(CheckoutEscrowScreen), findsOneWidget);
  });

  testWidgets('no ticket uploaded: payment stays locked and says why', (
    tester,
  ) async {
    await pump(tester, accepted(ticket: null));

    expect(find.byKey(const ValueKey('ticket-missing')), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-confirm')), findsNothing);
    expect(payButton(tester).onPressed, isNull);
  });

  testWidgets('a ticket that fails to load can be retried', (tester) async {
    service.failTicketUrl = true;
    await pump(tester, accepted());

    expect(find.byKey(const ValueKey('ticket-error')), findsOneWidget);
    // It can't be confirmed without being seen.
    final confirm = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('ticket-confirm')),
    );
    expect(confirm.onPressed, isNull);

    service.failTicketUrl = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('ticket-error')), findsNothing);
    expect(find.text('Flight ticket (PDF)'), findsOneWidget);
  });

  testWidgets('refused by the database: explained, not checked', (
    tester,
  ) async {
    service.failTicket = const RequestException(RequestFailure.notPayable);
    await pump(tester, accepted());

    await tester.tap(find.byKey(const ValueKey('ticket-confirm')));
    await tester.pump();
    await tester.pump();

    expect(find.text('This request can no longer be paid.'), findsOneWidget);
    expect(ticketStatus('Not validated'), findsOneWidget);
    expect(payButton(tester).onPressed, isNull);
  });

  testWidgets('past the deadline it can no longer be paid', (tester) async {
    await pump(
      tester,
      accepted(
        checkedAt: DateTime(2030, 6, 21, 9),
        idCheckedAt: DateTime(2030, 6, 21, 9),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
    );

    expect(find.byKey(const ValueKey('checkout-expired')), findsOneWidget);
    expect(payButton(tester).onPressed, isNull);
  });

  testWidgets('is translated', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        CheckoutEscrowScreen(
          request: accepted(),
          service: service,
          now: () => now,
        ),
        locale: const Locale('fr'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("ÉTAPE 1 · VÉRIFIER LE BILLET D'AVION"), findsOneWidget);
    expect(find.text("J'ai vérifié ce billet"), findsOneWidget);
    expect(
      find.textContaining('23 h 48 min', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Pay Escrow on Requests opens checkout for that request', (
    tester,
  ) async {
    service.mine = [accepted()];
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        RequestsScreen(
          requestService: service,
          exchangeRates: FakeExchangeRateService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('requests-tab-1')));
    await tester.pumpAndSettle();
    final listsBefore = service.listCalls;

    await tester.tap(find.byKey(const ValueKey('sent-request-pay-req-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CheckoutEscrowScreen), findsOneWidget);
    expect(find.text('XOF 65,566'), findsWidgets);

    // Coming back refreshes the list.
    Navigator.of(tester.element(find.byType(CheckoutEscrowScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.listCalls, listsBefore + 1);
  });

  group('Step 2 · traveler ID', () {
    testWidgets('shows the ID photo and verified name, not the document', (
      tester,
    ) async {
      await pump(tester, accepted());

      expect(find.text('STEP 2 · VERIFY TRAVELER ID'), findsOneWidget);
      expect(idStatus('Not validated'), findsOneWidget);
      expect(service.idPhotoCalls, ['req-1']);
      expect(find.byKey(const ValueKey('id-photo')), findsOneWidget);
      expect(find.text('Identity verified'), findsOneWidget);
      expect(find.text('Name on ID'), findsOneWidget);
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text('May 2, 2030'), findsOneWidget);
      expect(
        find.text('Only the photo is shown. The rest of the ID stays private.'),
        findsOneWidget,
      );
      expect(find.text('STEP 3 · SELECT PAYMENT METHOD'), findsOneWidget);
    });

    testWidgets('an unverified traveler: no photo asked for, payment locked', (
      tester,
    ) async {
      await pump(
        tester,
        accepted(verified: false, checkedAt: DateTime(2030, 6, 21, 9)),
      );

      expect(find.byKey(const ValueKey('id-not-verified')), findsOneWidget);
      expect(service.idPhotoCalls, isEmpty);
      expect(find.byKey(const ValueKey('id-confirm')), findsNothing);
      expect(payButton(tester).onPressed, isNull);
    });

    testWidgets('no photo available: it says so and can be retried', (
      tester,
    ) async {
      service.idPhoto = null; // the server found none
      await pump(tester, accepted());

      expect(find.byKey(const ValueKey('id-photo-error')), findsOneWidget);
      final confirm = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('id-confirm')),
      );
      expect(confirm.onPressed, isNull);

      service.idPhoto = TravelerIdPhoto(
        url: 'https://example.test/signed/id_photo.jpg',
      );
      await tester.tap(find.byKey(const ValueKey('id-photo-retry')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('id-photo')), findsOneWidget);
    });

    testWidgets('a failure to load is explained, not a crash', (tester) async {
      service.failIdPhoto = true;
      await pump(tester, accepted());

      expect(find.byKey(const ValueKey('id-photo-error')), findsOneWidget);
    });

    testWidgets('an ID check refused by the database is explained', (
      tester,
    ) async {
      service.failId = const RequestException(RequestFailure.notPayable);
      await pump(tester, accepted());

      await tester.tap(find.byKey(const ValueKey('id-confirm')));
      await tester.pump();
      await tester.pump();

      expect(find.text('This request can no longer be paid.'), findsOneWidget);
      expect(idStatus('Not validated'), findsOneWidget);
    });
  });
}
