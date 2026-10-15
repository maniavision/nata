import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Amounts on Requests are stored in dollars and shown in the user's
/// currency, rounded up to whole amounts like everywhere else.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    service = FakeRequestService();
  });
  tearDown(() => PreferencesService().resetAll());

  Future<void> pump(
    WidgetTester tester, {
    AppCurrency currency = AppCurrency.eur,
    FakeExchangeRateService? rates,
    int tab = 1,
  }) async {
    PreferencesService().setCurrency(currency);
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        RequestsScreen(
          requestService: service,
          exchangeRates: rates ?? FakeExchangeRateService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (tab == 1) {
      await tester.tap(find.byKey(const ValueKey('requests-tab-1')));
      await tester.pumpAndSettle();
    }
  }

  group('Outgoing', () {
    testWidgets('the request total is shown in euros', (tester) async {
      service.mine = [sampleSentRequest()]; // $110.91
      await pump(tester);

      // 98.98, rounded up; an estimate until the traveler accepts.
      expect(find.text('≈ €99'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('in CFA francs', (tester) async {
      service.mine = [sampleSentRequest()];
      await pump(tester, currency: AppCurrency.xof);

      expect(find.text('≈ XOF 64,927'), findsOneWidget);
    });

    testWidgets('Pay Escrow carries the converted total', (tester) async {
      service.mine = [sampleSentRequest(status: 'accepted')];
      await pump(tester);

      expect(find.text('Pay Escrow (≈ €99)'), findsOneWidget);
    });

    testWidgets('the cancellation fee is converted in the dialog', (
      tester,
    ) async {
      service.mine = [sampleSentRequest(status: 'accepted')]; // fee $12
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('sent-request-cancel-req-1')));
      await tester.pumpAndSettle();

      expect(find.text('Cancel and pay ≈ €11'), findsOneWidget); // 10.71
    });

    testWidgets('the fee charged on a cancelled request is converted', (
      tester,
    ) async {
      service.mine = [
        sampleSentRequest(
          status: 'cancelled',
          cancellationFee: 12,
          cancelledAt: DateTime(2030, 6, 10),
        ),
      ];
      await pump(tester, currency: AppCurrency.xof);

      expect(find.text('Cancellation fee: XOF 7,025'), findsOneWidget);
    });

    testWidgets('dollars stay dollars', (tester) async {
      service.mine = [sampleSentRequest()];
      final rates = FakeExchangeRateService();
      await pump(tester, currency: AppCurrency.usd, rates: rates);

      expect(find.text(r'$111'), findsOneWidget);
      expect(rates.calls, 0); // no rates needed
    });

    testWidgets('without exchange rates it falls back to dollars', (
      tester,
    ) async {
      service.mine = [sampleSentRequest()];
      final rates = FakeExchangeRateService()..result = null;
      await pump(tester, rates: rates);

      expect(find.text(r'$111'), findsOneWidget);
    });
  });

  testWidgets('Incoming amounts are converted too', (tester) async {
    await pump(tester, tab: 0);

    expect(find.text('€34'), findsOneWidget); // $38 payout
    expect(find.text('€29'), findsOneWidget); // $32
    expect(find.text('€24'), findsOneWidget); // $26.50
  });

  group('Once the traveler accepted, the price is fixed', () {
    // Fixed at acceptance: XOF 65,566 (the rate that day), whatever the
    // rate or the user's currency is now.
    SentRequest fixed({String status = 'accepted'}) => sampleSentRequest(
      status: status,
      displayCurrency: 'XOF',
      displayTotal: 65566,
    );

    testWidgets('the fixed amount is shown exactly, without ≈', (tester) async {
      service.mine = [fixed()];
      await pump(tester, currency: AppCurrency.xof);

      expect(find.text('XOF 65,566'), findsOneWidget);
      expect(find.text('Pay Escrow (XOF 65,566)'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
    });

    testWidgets('today\'s rate does not change it', (tester) async {
      service.mine = [fixed()];
      // Today's rate would give XOF 64,927 for $110.91.
      await pump(tester, currency: AppCurrency.xof);

      expect(find.text('XOF 64,927'), findsNothing);
      expect(find.text('XOF 65,566'), findsOneWidget);
    });

    testWidgets('it stays in the currency it was fixed in', (tester) async {
      service.mine = [fixed()];
      await pump(tester, currency: AppCurrency.eur); // user switched to euros

      expect(find.text('XOF 65,566'), findsOneWidget);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets('the cancellation fee is 10% of the fixed price', (
      tester,
    ) async {
      service.mine = [fixed()];
      await pump(tester, currency: AppCurrency.xof);

      await tester.tap(find.byKey(const ValueKey('sent-request-cancel-req-1')));
      await tester.pumpAndSettle();

      // 10% of 65,566 = 6,556.6, rounded up.
      expect(find.text('Cancel and pay XOF 6,557'), findsOneWidget);
    });

    testWidgets('a cancelled request shows the fee in that currency', (
      tester,
    ) async {
      service.mine = [
        sampleSentRequest(
          status: 'cancelled',
          cancellationFee: 12,
          cancelledAt: DateTime(2030, 6, 10),
          displayCurrency: 'XOF',
          displayTotal: 65566,
          displayCancellationFee: 6557,
        ),
      ];
      await pump(tester, currency: AppCurrency.eur);

      expect(find.text('Cancellation fee: XOF 6,557'), findsOneWidget);
    });
  });

  testWidgets('accepted card: the status pill stays next to the name', (
    tester,
  ) async {
    // As in the screenshot: a wide CFA payout on a phone-width screen.
    PreferencesService().setCurrency(AppCurrency.xof);
    tester.view.physicalSize = const Size(402, 1800);
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

    expect(find.text('XOF 22,246'), findsOneWidget); // $38 at the test rate
    final name = tester.getRect(
      find.byKey(const ValueKey('accepted-sender-name')),
    );
    final pill = tester.getRect(
      find.byKey(const ValueKey('accepted-status-pill')),
    );
    // Same line: the pill is to the right of the name, not below it.
    expect(pill.left, greaterThan(name.right));
    expect((pill.center.dy - name.center.dy).abs(), lessThan(4));
  });
}
