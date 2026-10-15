import 'package:carrywise_app/screens/delivery_request_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  bool? popResult;

  // The day before the flight, as in the request form tests.
  final fixedNow = DateTime.utc(2030, 6, 21, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    service = FakeRequestService();
    popResult = null;
  });

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The request form in edit mode, opened on top of a host page.
  Future<void> pumpEdit(WidgetTester tester, SentRequest request) async {
    bigScreen(tester);
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => DeliveryRequestScreen(
                      trip: request.trip,
                      editing: request,
                      service: service,
                      photoPicker: ({required bool camera}) async =>
                          sampleReceipt(name: 'new.jpg'),
                      cityService: FakeCityService(),
                      exchangeRates: FakeExchangeRateService(),
                      now: () => fixedNow,
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

  String text(WidgetTester t, String key) =>
      t.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  Future<void> save(WidgetTester t) async {
    await t.tap(find.textContaining('Save changes'));
    await t.pumpAndSettle();
  }

  group('Editing a pending request', () {
    testWidgets('the form starts from the request', (tester) async {
      await pumpEdit(tester, sampleSentRequest());

      expect(find.text('Edit Request'), findsOneWidget);
      expect(text(tester, 'request-item-0'), 'AirPods Max');
      expect(text(tester, 'request-recipient-name'), 'Jane Doe');
      expect(text(tester, 'request-recipient-phone'), '+447700900123');
      expect(text(tester, 'request-weight'), '0.9');
      expect(find.textContaining('Save changes'), findsOneWidget);
      expect(find.textContaining('Send Request'), findsNothing);
    });

    testWidgets('saving sends the changes, keeping the photos', (tester) async {
      await pumpEdit(tester, sampleSentRequest());
      await tester.enterText(
        find.byKey(const ValueKey('request-item-0')),
        'AirPods Pro',
      );
      await tester.enterText(
        find.byKey(const ValueKey('request-weight')),
        '0.5',
      );
      await tester.pump();

      await save(tester);

      final u = service.updated.single;
      expect(u.request.id, 'req-1');
      expect(u.draft.items.single.name, 'AirPods Pro');
      expect(u.draft.weightKg, 0.5);
      expect(u.draft.recipientPhone, '+447700900123');
      expect(u.photos, isNull, reason: 'unchanged photos are not re-sent');
      expect(service.sent, isEmpty, reason: 'no new request is created');
      expect(popResult, isTrue);
    });

    testWidgets('changed photos are sent with the edit', (tester) async {
      await pumpEdit(tester, sampleSentRequest());

      await tester.tap(find.byKey(const ValueKey('request-photo-remove-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('request-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('request-photo-library')));
      await tester.pumpAndSettle();
      await save(tester);

      final photos = service.updated.single.photos!;
      expect(photos.map((p) => p.name), ['new.jpg']);
    });

    testWidgets('a request the traveler already answered is refused', (
      tester,
    ) async {
      service.fail = const RequestException(RequestFailure.notEditable);
      await pumpEdit(tester, sampleSentRequest());

      await save(tester);

      expect(
        find.text(
          "The traveler already answered this request, so it can't be changed anymore.",
        ),
        findsOneWidget,
      );
      expect(popResult, isNull);
    });
  });

  group('Outgoing tab', () {
    Future<void> pumpRequests(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(
        appWrapper(RequestsScreen(requestService: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('requests-tab-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('lists the requests the user sent', (tester) async {
      service.mine = [
        sampleSentRequest(),
        sampleSentRequest(id: 'req-2', status: 'accepted'),
        sampleSentRequest(id: 'req-3', status: 'declined'),
      ];
      await pumpRequests(tester);

      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('SENT REQUESTS (3)'), findsOneWidget);
      expect(find.text('Waiting for traveler'), findsOneWidget);
      // Only the pending one can be edited.
      expect(find.text('Tap to edit'), findsOneWidget);
      expect(find.textContaining('Pay Escrow'), findsOneWidget);
      expect(find.text('Find another traveler'), findsOneWidget);
    });

    testWidgets('tapping a pending request opens it for editing', (
      tester,
    ) async {
      service.mine = [sampleSentRequest()];
      await pumpRequests(tester);

      await tester.tap(find.byKey(const ValueKey('sent-request-req-1')));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryRequestScreen), findsOneWidget);
      expect(find.text('Edit Request'), findsOneWidget);
    });

    testWidgets('an accepted request does not open the editor', (tester) async {
      service.mine = [sampleSentRequest(status: 'accepted')];
      await pumpRequests(tester);

      await tester.tap(find.byKey(const ValueKey('sent-request-req-1')));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryRequestScreen), findsNothing);
    });

    testWidgets('empty and failed states', (tester) async {
      await pumpRequests(tester);
      expect(find.byKey(const ValueKey('outgoing-empty')), findsOneWidget);

      service.failList = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpRequests(tester);
      expect(find.byKey(const ValueKey('outgoing-error')), findsOneWidget);

      service.failList = false;
      service.mine = [sampleSentRequest()];
      await tester.tap(find.byKey(const ValueKey('outgoing-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Tap to edit'), findsOneWidget);
    });
  });
}
