import 'package:carrywise_app/screens/checkout_escrow_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/stripe_sheet.dart';
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

  testWidgets('payment stays locked until the ticket is checked', (
    tester,
  ) async {
    await pump(tester, accepted());

    expect(payButton(tester).onPressed, isNull);
    expect(find.text('Validate ticket to unlock payment'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-confirm')));
    await tester.pump();
    await tester.pump();

    expect(service.ticketChecks, ['req-1']);
    expect(ticketStatus('Checked'), findsOneWidget);
    expect(find.byKey(const ValueKey('ticket-confirm')), findsNothing);
    expect(payButton(tester).onPressed, isNotNull);
    expect(find.text('Pay XOF 65,566 into Escrow'), findsOneWidget);
  });

  testWidgets('a ticket checked on an earlier visit stays checked', (
    tester,
  ) async {
    await pump(tester, accepted(checkedAt: DateTime(2030, 6, 21, 9)));

    expect(ticketStatus('Checked'), findsOneWidget);
    expect(payButton(tester).onPressed, isNotNull);
  });

  group('paying', () {
    final opened = <Uri>[];
    final sheets = <StripeSheet>[];
    var sheetResult = CardSheetResult.paid;
    var closed = 0;
    bool? popped;

    /// Checkout over a host page, with both checks done, so leaving it can
    /// be seen.
    Future<void> pumpPayable(WidgetTester tester) async {
      opened.clear();
      sheets.clear();
      sheetResult = CardSheetResult.paid;
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
                        request: accepted(checkedAt: DateTime(2030, 6, 21, 9)),
                        service: service,
                        now: () => now,
                        openPaymentPage: (link) async {
                          opened.add(link);
                          return true;
                        },
                        closePaymentPage: () async => closed++,
                        pollInterval: const Duration(seconds: 3),
                        presentCardSheet: (sheet) async {
                          sheets.add(sheet);
                          return sheetResult;
                        },
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

    // A provider answering with a payment page (none does now) still works:
    // the page opens and checkout watches it. Apple Pay is picked first.
    testWidgets('a payment page in the answer is opened', (tester) async {
      await pumpPayable(tester);

      await pay(tester);

      expect(service.paymentsStarted.single.id, 'req-1');
      expect(service.paymentsStarted.single.method, PayMethod.applePay);
      expect(opened, [service.nextPayment.link]);
      expect(
        find.byKey(const ValueKey('checkout-payment-in-progress')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('checkout-pay')), findsNothing);
    });

    testWidgets('once paid, it closes the page and goes back', (tester) async {
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

    group('cards and Apple Pay: Stripe\'s sheet', () {
      const stripePayment = PaymentLink(
        null,
        'pi_123',
        stripe: StripeSheet(
          clientSecret: 'pi_123_secret_abc',
          publishableKey: 'pk_test_abc',
        ),
      );
      setUp(() => service.nextPayment = stripePayment);

      Future<void> chooseCard(WidgetTester tester) async {
        await tester.tap(find.text('Credit or Debit Card'));
        await tester.pump();
      }

      testWidgets('opens the sheet in the app, no page', (tester) async {
        await pumpPayable(tester);
        await chooseCard(tester);
        expect(
          find.byKey(const ValueKey('checkout-stripe-note')),
          findsOneWidget,
        );
        expect(payButton(tester).onPressed, isNotNull);

        await pay(tester);

        expect(service.paymentsStarted.single.method, PayMethod.card);
        expect(sheets.single.clientSecret, 'pi_123_secret_abc');
        expect(opened, isEmpty);
      });

      testWidgets('Apple Pay goes through the same sheet', (tester) async {
        await pumpPayable(tester);
        await pay(tester); // Apple Pay is picked first

        expect(service.paymentsStarted.single.method, PayMethod.applePay);
        expect(sheets, hasLength(1));
      });

      testWidgets('paid in the sheet: confirmed, then back to Requests', (
        tester,
      ) async {
        service.paymentStatuses = [
          PaymentStatus.pending,
          PaymentStatus.successful,
        ];
        await pumpPayable(tester);
        await chooseCard(tester);
        await pay(tester);
        await tester.pump();

        // Checked straight away, while it says it is confirming.
        expect(service.paymentChecks, ['pi_123']);
        expect(find.text('Confirming your payment'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('checkout-open-payment')),
          findsNothing,
        );

        await tester.pump(const Duration(seconds: 3)); // successful
        await tester.pumpAndSettle();
        expect(popped, isTrue);
        expect(closed, 0); // no page to close
        expect(find.textContaining('Payment received'), findsOneWidget);
      });

      testWidgets('closing the sheet goes back to choosing, quietly', (
        tester,
      ) async {
        await pumpPayable(tester);
        await chooseCard(tester);
        sheetResult = CardSheetResult.cancelled;
        await pay(tester);
        await tester.pump();

        expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
        expect(find.textContaining("didn't go through"), findsNothing);
        await tester.pump(const Duration(seconds: 10));
        expect(service.paymentChecks, isEmpty);
      });

      testWidgets('a card Stripe refuses can be tried again', (tester) async {
        await pumpPayable(tester);
        await chooseCard(tester);
        sheetResult = CardSheetResult.failed;
        await pay(tester);
        await tester.pump();

        expect(find.textContaining("didn't go through"), findsOneWidget);
        expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
      });
    });

    testWidgets('mobile money: charged in the wallet country\'s currency', (
      tester,
    ) async {
      service.nextPayment = const PaymentLink(null, 'nata-req-1-tx');
      await pumpPayable(tester);
      await tester.tap(find.text('Mobile Money'));
      await tester.pump();
      await tester.pump();

      // The phone's country is suggested, with the converted amount.
      expect(find.text('Kenya · KES'), findsOneWidget);
      expect(find.textContaining('KES 14,230'), findsWidgets);

      // M-Pesa is charged directly: the number is asked for, no network.
      expect(find.byKey(const ValueKey('mobile-money-phone')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-money-network-MTN_MOMO_CMR')),
        findsNothing,
      );
      expect(payButton(tester).onPressed, isNull);
      expect(find.text('Enter your mobile money number'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('mobile-money-phone')),
        '0712 345 678',
      );
      await tester.pump();
      expect(find.text('Pay KES 14,230 into Escrow'), findsOneWidget);

      await pay(tester);
      final started = service.paymentsStarted.single;
      expect(started.method, PayMethod.mobileMoney);
      expect(started.country, 'KE');
      expect(started.phone, '+254712345678');
      // M-Pesa is Kenya's only network: chosen without asking.
      expect(started.network, 'MPESA_KEN');
    });

    group('mobile money charged directly', () {
      setUp(() {
        service.mobileOptions = const [
          MobileMoneyOption(
            countryCode: 'CM',
            countryName: 'Cameroon',
            currency: 'XAF',
            amount: 65566,
            suggested: true,
            dialCode: '+237',
            networks: [
              MobileMoneyNetwork('MTN_MOMO_CMR', 'MTN Mobile Money'),
              MobileMoneyNetwork('ORANGE_CMR', 'Orange Money'),
            ],
          ),
          MobileMoneyOption(
            countryCode: 'CG',
            countryName: 'Congo',
            currency: 'XAF',
            amount: 65566,
            dialCode: '+242',
            networks: [
              MobileMoneyNetwork('MTN_MOMO_COG', 'MTN Mobile Money'),
              MobileMoneyNetwork('AIRTEL_COG', 'Airtel Money'),
            ],
          ),
        ];
        service.nextPayment = const PaymentLink(null, 'nata-req-1-tx');
      });

      Future<void> chooseMobileMoney(WidgetTester tester) async {
        await pumpPayable(tester);
        await tester.tap(find.text('Mobile Money'));
        await tester.pump();
        await tester.pump();
      }

      Future<void> enterWallet(WidgetTester tester) async {
        await tester.tap(
          find.byKey(const ValueKey('mobile-money-network-MTN_MOMO_CMR')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('mobile-money-phone')),
          '6 77 12 34 56',
        );
        await tester.pump();
      }

      testWidgets('asks for the network and number before paying', (
        tester,
      ) async {
        await chooseMobileMoney(tester);

        expect(find.text('MTN Mobile Money'), findsOneWidget);
        expect(find.text('Orange Money'), findsOneWidget);
        expect(find.text('+237  '), findsOneWidget);
        expect(payButton(tester).onPressed, isNull);

        // A number alone isn't enough: the network too.
        await tester.enterText(
          find.byKey(const ValueKey('mobile-money-phone')),
          '6 77 12 34 56',
        );
        await tester.pump();
        expect(payButton(tester).onPressed, isNull);

        await tester.tap(
          find.byKey(const ValueKey('mobile-money-network-MTN_MOMO_CMR')),
        );
        await tester.pump();
        expect(payButton(tester).onPressed, isNotNull);
      });

      testWidgets('a number too short keeps payment locked', (tester) async {
        await chooseMobileMoney(tester);
        await tester.tap(
          find.byKey(const ValueKey('mobile-money-network-MTN_MOMO_CMR')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('mobile-money-phone')),
          '677',
        );
        await tester.pump();
        expect(payButton(tester).onPressed, isNull);
      });

      testWidgets('charges the phone and waits for approval, no page', (
        tester,
      ) async {
        service.paymentStatuses = [
          PaymentStatus.pending,
          PaymentStatus.successful,
        ];
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);

        final started = service.paymentsStarted.single;
        expect(started.country, 'CM');
        expect(started.phone, '+237677123456');
        expect(started.network, 'MTN_MOMO_CMR');
        expect(opened, isEmpty);
        expect(
          find.byKey(const ValueKey('checkout-approve-on-phone')),
          findsOneWidget,
        );
        expect(find.text('Approve the payment on your phone'), findsOneWidget);
        expect(
          find.textContaining('+237677123456 (MTN Mobile Money)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('checkout-open-payment')),
          findsNothing,
        );

        await tester.pump(const Duration(seconds: 3)); // pending
        expect(popped, isNull);
        await tester.pump(const Duration(seconds: 3)); // successful
        await tester.pumpAndSettle();

        expect(service.paymentChecks, hasLength(2));
        expect(closed, 0); // No page to close.
        expect(popped, isTrue);
      });

      testWidgets('"I\'ve approved" checks now; another way can be chosen', (
        tester,
      ) async {
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);

        await tester.tap(find.text("I've approved, check now"));
        await tester.pump();
        await tester.pump();
        expect(service.paymentChecks, hasLength(1));
        expect(
          find.textContaining("haven't received the payment yet"),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('checkout-abandon-payment')),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
      });

      testWidgets('a declined prompt can be tried again', (tester) async {
        service.paymentStatuses = [PaymentStatus.failed];
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);

        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        expect(closed, 0);
        expect(find.textContaining("didn't go through"), findsOneWidget);
        expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
      });

      testWidgets('a number the provider refuses is explained', (tester) async {
        service.failStartPayment = const RequestException(
          RequestFailure.phoneRejected,
        );
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);
        await tester.pump();

        expect(find.textContaining("can't be charged"), findsOneWidget);
        expect(find.byKey(const ValueKey('checkout-pay')), findsOneWidget);
      });

      testWidgets('a wallet that still needs a page opens it', (tester) async {
        service.nextPayment = PaymentLink(
          Uri.parse('https://orange.test/approve/1'),
          'nata-req-1-tx',
        );
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);

        expect(opened, [Uri.parse('https://orange.test/approve/1')]);
        expect(
          find.byKey(const ValueKey('checkout-payment-in-progress')),
          findsOneWidget,
        );
      });

      testWidgets('Congo: its own networks, the 0 kept in the number', (
        tester,
      ) async {
        await chooseMobileMoney(tester);
        await tester.tap(find.byKey(const ValueKey('mobile-money-country')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Congo · XAF').last);
        await tester.pumpAndSettle();

        expect(find.text('Airtel Money'), findsOneWidget);
        expect(find.text('Orange Money'), findsNothing);
        expect(find.text('+242  '), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('mobile-money-network-AIRTEL_COG')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('mobile-money-phone')),
          '05 512 3456',
        );
        await tester.pump();
        await pay(tester);

        final started = service.paymentsStarted.single;
        expect(started.country, 'CG');
        expect(started.network, 'AIRTEL_COG');
        expect(started.phone, '+242055123456');
        expect(opened, isEmpty);
      });

      testWidgets('no Bank Transfer, and no email asked', (tester) async {
        await pumpPayable(tester);
        expect(find.text('Bank Transfer'), findsNothing);
        expect(find.byKey(const ValueKey('checkout-email')), findsNothing);
      });

      testWidgets('an amount the network refuses is explained', (tester) async {
        service.failStartPayment = const RequestException(
          RequestFailure.amountOutOfBounds,
        );
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);
        await tester.pump();
        expect(find.textContaining('network allows'), findsOneWidget);
      });

      testWidgets('a network that is down is explained', (tester) async {
        service.failStartPayment = const RequestException(
          RequestFailure.networkUnavailable,
        );
        await chooseMobileMoney(tester);
        await enterWallet(tester);
        await pay(tester);
        await tester.pump();
        expect(find.textContaining("isn't answering"), findsOneWidget);
      });
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
          dialCode: '+233',
          networks: [MobileMoneyNetwork('MTN_MOMO_GHA', 'MTN Mobile Money')],
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

      // Then the wallet's number (its only network is already chosen).
      expect(find.text('Enter your mobile money number'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('mobile-money-phone')),
        '024 123 4567',
      );
      await tester.pump();

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
      expect(find.text('Kenya · KES'), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-money-error')), findsNothing);
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

  testWidgets('no ID step: a tip to check the ID at the handover', (
    tester,
  ) async {
    await pump(tester, accepted());

    expect(find.text('STEP 2 · VERIFY TRAVELER ID'), findsNothing);
    expect(find.byKey(const ValueKey('id-confirm')), findsNothing);
    expect(find.text('STEP 2 · SELECT PAYMENT METHOD'), findsOneWidget);
    expect(find.byKey(const ValueKey('id-meeting-tip')), findsOneWidget);
    expect(
      find.textContaining('Check their ID when you meet.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('ask Amara', findRichText: true),
      findsOneWidget,
    );
  });
}
