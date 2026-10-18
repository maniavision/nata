import 'package:carrywise_app/screens/delivery_task_screen.dart';
import 'package:carrywise_app/screens/incoming_request_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Once paid, the sender has a delivery code for the recipient, and the
/// traveler's request opens the delivery itself.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    service = FakeRequestService();
  });
  tearDown(() => PreferencesService().resetAll());

  Future<void> pump(WidgetTester tester, {int tab = 1}) async {
    PreferencesService().setCurrency(AppCurrency.usd);
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
    if (tab == 1) {
      await tester.tap(find.byKey(const ValueKey('requests-tab-1')));
      await tester.pumpAndSettle();
    }
  }

  group('the sender', () {
    setUp(() {
      service.mine = [sampleSentRequest(status: 'paid')];
      service.codes = {'req-1': const DeliveryCode('7492')};
    });

    testWidgets('sees the code to give the recipient', (tester) async {
      await pump(tester);

      expect(
        find.byKey(const ValueKey('sent-request-code-req-1')),
        findsOneWidget,
      );
      expect(find.text('7 4 9 2'), findsOneWidget);
      expect(find.textContaining('Give this code to Jane Doe'), findsOneWidget);
      expect(find.text('Text it to Jane Doe'), findsOneWidget);
    });

    testWidgets('can text it to the recipient, then resend', (tester) async {
      await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('sent-request-text-code-req-1')),
      );
      await tester.pumpAndSettle();

      expect(service.codesTexted, ['req-1']);
      expect(find.text('Code sent to Jane Doe by SMS.'), findsOneWidget);
      expect(find.text('Sent by SMS · Resend'), findsOneWidget);
    });

    testWidgets('SMS not set up: asks them to share it themselves', (
      tester,
    ) async {
      service.failTextCode = const RequestException(
        RequestFailure.smsUnavailable,
      );
      await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('sent-request-text-code-req-1')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('share the code'), findsOneWidget);
    });

    testWidgets('no code before payment or after delivery', (tester) async {
      service.mine = [
        sampleSentRequest(status: 'accepted'),
        sampleSentRequest(id: 'req-2', status: 'delivered'),
      ];
      service.codes = {
        'req-1': const DeliveryCode('1111'),
        'req-2': const DeliveryCode('2222'),
      };
      await pump(tester);

      expect(find.text('1 1 1 1'), findsNothing);
      expect(find.text('2 2 2 2'), findsNothing);
    });
  });

  group('the traveler', () {
    testWidgets('a paid request opens the delivery', (tester) async {
      service.incoming = [sampleIncoming(status: 'paid')];
      await pump(tester, tab: 0);

      await tester.tap(find.textContaining('Chioma').first);
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryTaskScreen), findsOneWidget);
      expect(find.byType(IncomingRequestScreen), findsNothing);
    });

    testWidgets('an accepted (unpaid) request opens its details', (
      tester,
    ) async {
      service.incoming = [sampleIncoming(status: 'accepted')];
      await pump(tester, tab: 0);

      await tester.tap(find.textContaining('Chioma').first);
      await tester.pumpAndSettle();

      expect(find.byType(IncomingRequestScreen), findsOneWidget);
    });
  });
}
