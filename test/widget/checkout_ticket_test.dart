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
    bool? onFile,
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
    hasTicket: onFile,
    hasBookingReference: true,
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
    // The booking reference is never shown, only a blurred placeholder.
    expect(find.text('X7KQ9R'), findsNothing);
    expect(
      find.byKey(const ValueKey('ticket-booking-ref-hidden')),
      findsOneWidget,
    );
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

  group('paying with Flutterwave', () {
    final opened = <Uri>[];
    var closed = 0;
    bool? popped;

    /// Checkout over a host page, with both checks done, so leaving it can
    /// be seen.
    Future<void> pumpPayable(WidgetTester tester) async {
      opened.clear();
      closed = 0;
      popped = null;
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => CheckoutEscrowScreen(
                        request: accepted(
                          checkedAt: DateTime(2030, 6, 21, 9),
                          idCheckedAt: DateTime(2030, 6, 21, 9),
                        ),
                        service: service,
                        now: () => now,
                        openPaymentPage: (link) async {
                          opened.add(link);
                          return true;
                        },
                        closePaymentPage: () async => closed++,
                        pollInterval: const Duration(seconds: 3),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> pay(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('checkout-pay')));
      await tester.tap(find.byKey(const ValueKey('checkout-pay')));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('opens Flutterwave for the chosen way to pay', (tester) async {
      await pumpPayable(tester);
      await tester.tap(find.text('Credit or Debit Card'));
      await tester.pump();

      await pay(tester);

      expect(service.paymentsStarted.single.id, 'req-1');
      expect(service.paymentsStarted.single.method, PayMethod.card);
      expect(opened, [service.nextPayment.link]);
      expect(
        find.byKey(const ValueKey('checkout-payment-in-progress')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('checkout-pay')), findsNothing);
    });

    testWidgets('an account without an email gives one before paying', (
      tester,
    ) async {
      service.payerEmailValue = null;
      await pumpPayable(tester);
      await tester.tap(find.text('Credit or Debit Card'));
      await tester.pump();

      expect(find.byKey(const ValueKey('checkout-email')), findsOneWidget);
      expect(find.text('Enter your email to pay'), findsOneWidget);
      expect(payButton(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('checkout-email')),
        ' Ama@Example.com ',
      );
      await tester.pump();
      await pay(tester);

      expect(service.paymentsStarted.single.email, 'Ama@Example.com');
      expect(opened, [service.nextPayment.link]);
    });

    testWidgets('an account with an email is not asked for one', (
      tester,
    ) async {
      await pumpPayable(tester);
      await tester.tap(find.text('Credit or Debit Card'));
      await tester.pump();

      expect(find.byKey(const ValueKey('checkout-email')), findsNothing);
      await pay(tester);
      expect(service.paymentsStarted.single.email, isNull);
    });

    testWidgets('asks for an email when the server needs one', (tester) async {
      service.failStartPayment = RequestException(RequestFailure.emailRequired);
      await pumpPayable(tester);
      await tester.tap(find.text('Credit or Debit Card'));
      await tester.pump();

      await pay(tester);

      expect(find.text('Enter your email to pay.'), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-email')), findsOneWidget);
    });

    testWidgets('once paid, it closes Flutterwave and goes back', (
      tester,
    ) async {
      service.paymentStatuses = [
        PaymentStatus.pending,
        PaymentStatus.successful,
      ];
      await pumpPayable(tester);
      await pay(tester);

      await tester.pump(const Duration(seconds: 3)); // pending
      expect(popped, isNull);
      await tester.pump(const Duration(seconds: 3)); // successful
      await tester.pumpAndSettle();

      expect(service.paymentChecks, ['nata-req-1-tx', 'nata-req-1-tx']);
      expect(closed, 1);
      expect(popped, isTrue);
      expect(find.textContaining('Payment received'), findsOneWidget);
    });

    testWidgets('a failed payment can be tried again', (tester) async {
      service.paymentStatuses = [PaymentStatus.failed];
      await pumpPayable(tester);
      await pay(tester);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(closed, 1);
      expect(popped, isNull);
      expect(find.textContaining("didn't go through"), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
    });

    testWidgets('"I\'ve paid" checks now and says if it isn\'t there yet', (
      tester,
    ) async {
      await pumpPayable(tester);
      await pay(tester);

      await tester.tap(find.byKey(const ValueKey('checkout-check-payment')));
      await tester.pump();
      await tester.pump();

      expect(service.paymentChecks, hasLength(1));
      expect(
        find.textContaining("haven't received the payment yet"),
        findsOneWidget,
      );
    });

    testWidgets('the page can be opened again, or another way chosen', (
      tester,
    ) async {
      await pumpPayable(tester);
      await pay(tester);

      await tester.tap(find.byKey(const ValueKey('checkout-open-payment')));
      await tester.pump();
      expect(opened, hasLength(2));

      await tester.tap(find.byKey(const ValueKey('checkout-abandon-payment')));
      await tester.pump();
      expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);

      // No longer watched.
      await tester.pump(const Duration(seconds: 10));
      expect(service.paymentChecks, isEmpty);
    });

    testWidgets('mobile money: charged in the wallet country\'s currency', (
      tester,
    ) async {
      await pumpPayable(tester);
      await tester.tap(find.text('Mobile Money'));
      await tester.pump();
      await tester.pump();

      // The phone's country is suggested, with the converted amount.
      expect(find.text('Kenya · KES'), findsOneWidget);
      expect(find.textContaining('KES 14,230'), findsWidgets);
      expect(find.text('Pay KES 14,230 into Escrow'), findsOneWidget);

      await pay(tester);
      expect(service.paymentsStarted.single.method, PayMethod.mobileMoney);
      expect(service.paymentsStarted.single.country, 'KE');
    });

    testWidgets('bank transfer: charged in naira at today\'s rate', (
      tester,
    ) async {
      await pumpPayable(tester);
      await tester.ensureVisible(find.text('Bank Transfer'));
      await tester.tap(find.text('Bank Transfer'));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('bank-transfer-charge')),
        findsOneWidget,
      );
      expect(find.text('Pay NGN 178,381 into Escrow'), findsOneWidget);

      await pay(tester);
      expect(service.paymentsStarted.single.method, PayMethod.bankTransfer);
    });

    testWidgets('a bank transfer amount that fails to load can be retried', (
      tester,
    ) async {
      service.failBankQuote = true;
      await pumpPayable(tester);
      await tester.ensureVisible(find.text('Bank Transfer'));
      await tester.tap(find.text('Bank Transfer'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('bank-transfer-error')), findsOneWidget);
      expect(payButton(tester).onPressed, isNull);

      service.failBankQuote = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Pay NGN 178,381 into Escrow'), findsOneWidget);
    });

    testWidgets('mobile money waits for a country when none is suggested', (
      tester,
    ) async {
      service.mobileOptions = const [
        MobileMoneyOption(
          countryCode: 'GH',
          countryName: 'Ghana',
          currency: 'GHS',
          amount: 1210,
        ),
      ];
      await pumpPayable(tester);
      await tester.tap(find.text('Mobile Money'));
      await tester.pump();
      await tester.pump();

      expect(payButton(tester).onPressed, isNull);
      expect(find.text('Choose a country'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('mobile-money-country')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghana · GHS').last);
      await tester.pumpAndSettle();

      expect(find.text('Pay GHS 1,210 into Escrow'), findsOneWidget);
      expect(payButton(tester).onPressed, isNotNull);
    });

    testWidgets('mobile money countries that fail to load can be retried', (
      tester,
    ) async {
      service.failMobileOptions = true;
      await pumpPayable(tester);
      await tester.tap(find.text('Mobile Money'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('mobile-money-error')), findsOneWidget);
      expect(payButton(tester).onPressed, isNull);

      service.failMobileOptions = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Pay KES 14,230 into Escrow'), findsOneWidget);
    });

    testWidgets('payments not set up yet: said plainly', (tester) async {
      service.failStartPayment = const RequestException(
        RequestFailure.paymentsUnavailable,
      );
      await pumpPayable(tester);
      await pay(tester);

      expect(opened, isEmpty);
      expect(find.textContaining("Payments aren't available"), findsOneWidget);
      expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
    });
  });

  testWidgets('no ticket uploaded: payment stays locked and says why', (
    tester,
  ) async {
    await pump(tester, accepted(ticket: null));

    expect(find.byKey(const ValueKey('ticket-missing')), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-confirm')), findsNothing);
    expect(payButton(tester).onPressed, isNull);
  });

  testWidgets('a ticket without a blurred copy is described, not shown', (
    tester,
  ) async {
    await pump(tester, accepted(ticket: null, onFile: true));

    expect(find.byKey(const ValueKey('ticket-image-hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-preview')), findsNothing);
    expect(find.byKey(const ValueKey('ticket-missing')), findsNothing);

    // The checked details are enough to confirm it.
    await tester.tap(find.byKey(const ValueKey('ticket-confirm')));
    await tester.pumpAndSettle();
    expect(service.ticketChecks, ['req-1']);
    expect(ticketStatus('Checked'), findsOneWidget);
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

    testWidgets('no photo given: it says so and can be retried', (
      tester,
    ) async {
      service.idPhoto = null; // the server says the traveler isn't verified
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

    testWidgets('verified but no photo: the details can still be confirmed', (
      tester,
    ) async {
      service.idPhoto = TravelerIdPhoto(
        idDocumentType: 'passport',
        verifiedAt: DateTime(2030, 5, 2),
      );
      await pump(tester, accepted());

      expect(find.byKey(const ValueKey('id-photo-error')), findsNothing);
      expect(find.byKey(const ValueKey('id-photo-none')), findsOneWidget);
      expect(
        find.text(
          "No photo to show for this ID. Nata checked the traveler's identity.",
        ),
        findsOneWidget,
      );
      expect(find.text('Passport'), findsOneWidget);
      final confirm = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('id-confirm')),
      );
      expect(confirm.onPressed, isNotNull);
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
