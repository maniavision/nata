import 'package:carrywise_app/screens/deposit_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/stripe_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The traveler pays the refundable deposit before pickup (20240195).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  bool? popped;
  var sheets = 0;
  CardSheetResult sheetResult = CardSheetResult.paid;

  const card = RequestDeposit(
    required: true,
    amount: 450,
    currency: 'USD',
    limitUsd: 100,
  );
  const mobile = RequestDeposit(
    required: true,
    amount: 450,
    currency: 'USD',
    limitUsd: 100,
    kind: CheckoutKind.mobileMoney,
  );

  setUp(() {
    service = FakeRequestService();
    popped = null;
    sheets = 0;
    sheetResult = CardSheetResult.paid;
  });

  Future<void> pump(
    WidgetTester tester,
    RequestDeposit deposit, {
    List<PaymentMethod> saved = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
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
                    builder: (_) => DepositScreen(
                      requestId: 'req-1',
                      deposit: deposit,
                      service: service,
                      paymentService: FakePaymentService(methods: saved),
                      pollInterval: const Duration(milliseconds: 10),
                      presentCardSheet: (_) async {
                        sheets++;
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
    await tester.pumpAndSettle();
  }

  FilledButton payButton(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const ValueKey('deposit-pay')));

  testWidgets('shows the amount, the limit and how it works', (tester) async {
    await pump(tester, card);

    expect(find.text('Deposit'), findsOneWidget);
    expect(find.byKey(const ValueKey('deposit-amount')), findsOneWidget);
    expect(find.text(r'$100'), findsOneWidget);
    expect(find.text('Paid now, held by Nata'), findsOneWidget);
    expect(
      find.text('If the item is kept, the deposit goes to the sender'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('deposit-card')), findsOneWidget);
  });

  testWidgets('paying waits for the agreement', (tester) async {
    await pump(tester, card);

    expect(payButton(tester).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('deposit-agree')));
    await tester.pump();
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('by card: Stripe\'s sheet, then back once held', (tester) async {
    service.nextPayment = const PaymentLink(
      null,
      'pi_1',
      stripe: StripeSheet(clientSecret: 'cs', publishableKey: 'pk_test'),
    );
    service.paymentStatuses = [PaymentStatus.successful];
    await pump(tester, card);

    await tester.tap(find.byKey(const ValueKey('deposit-agree')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('deposit-pay')));
    await tester.pumpAndSettle();

    final started = service.paymentsStarted.single;
    expect(started.deposit, isTrue);
    expect(started.method, PayMethod.card);
    expect(sheets, 1);
    expect(popped, isTrue);
  });

  testWidgets('a closed sheet stays on the page', (tester) async {
    service.nextPayment = const PaymentLink(
      null,
      'pi_1',
      stripe: StripeSheet(clientSecret: 'cs', publishableKey: 'pk_test'),
    );
    sheetResult = CardSheetResult.cancelled;
    await pump(tester, card);

    await tester.tap(find.byKey(const ValueKey('deposit-agree')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('deposit-pay')));
    await tester.pumpAndSettle();

    expect(popped, isNull);
    expect(find.byType(DepositScreen), findsOneWidget);
  });

  testWidgets('by mobile money: the wallet, a prompt, then back once held', (
    tester,
  ) async {
    service.nextPayment = const PaymentLink(null, 'dep-1');
    service.paymentStatuses = [PaymentStatus.pending, PaymentStatus.successful];
    await pump(tester, mobile);

    await tester.tap(find.byKey(const ValueKey('deposit-country')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ghana').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('deposit-network-MTN_MOMO_GHA')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('deposit-phone')),
      '241234567',
    );
    await tester.tap(find.byKey(const ValueKey('deposit-agree')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('deposit-pay')));
    await tester.pump();

    final started = service.paymentsStarted.single;
    expect(started.deposit, isTrue);
    expect(started.method, PayMethod.mobileMoney);
    expect(started.country, 'GH');
    expect(started.network, 'MTN_MOMO_GHA');
    expect(started.phone, '+233241234567');
    expect(find.byKey(const ValueKey('deposit-approve')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });

  testWidgets('a saved wallet is used, with Change to pick another', (
    tester,
  ) async {
    await pump(
      tester,
      mobile,
      saved: const [
        PaymentMethod(
          id: 'w1',
          kind: PaymentMethodKind.mobileMoney,
          isDefault: true,
          mobileNetwork: 'MTN_MOMO_GHA',
          mobileNumber: '+233241234567',
        ),
      ],
    );

    expect(find.byKey(const ValueKey('deposit-wallet')), findsOneWidget);
    expect(find.byKey(const ValueKey('deposit-wallet-editor')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('deposit-wallet-change')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deposit-wallet-editor')), findsOneWidget);
  });
}
