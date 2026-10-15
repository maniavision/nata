import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;

  setUp(() => service = FakeRequestService());

  Future<void> pumpRequests(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(RequestsScreen(requestService: service), locale: locale),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('requests-tab-1')));
    await tester.pumpAndSettle();
  }

  Finder cancelButton([String id = 'req-1']) =>
      find.byKey(ValueKey('sent-request-cancel-$id'));

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(cancelButton());
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('cancel-request-confirm')));
    await tester.pumpAndSettle();
  }

  group('Card layout', () {
    testWidgets('shows traveler, status, price, route, date and item', (
      tester,
    ) async {
      service.mine = [sampleSentRequest()];
      await pumpRequests(tester);

      expect(find.text('SENT REQUESTS (1)'), findsOneWidget);
      expect(find.text('Waiting for traveler'), findsOneWidget);
      expect(find.text('Amara Kalu'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Traveler · 28 deliveries'), findsOneWidget);
      // $110.91 (saved before whole prices) is shown rounded up.
      expect(find.text(r'$111'), findsOneWidget);
      expect(find.text('Route:'), findsOneWidget);
      expect(find.text('Lagos → London'), findsOneWidget);
      expect(find.text('Travel Date:'), findsOneWidget);
      expect(find.text('Jun 22, 2030'), findsOneWidget);
      expect(find.text('Item:'), findsOneWidget);
      expect(find.text('AirPods Max (0.9 kg)'), findsOneWidget);
      expect(find.text('Cancel Request'), findsOneWidget);
    });

    testWidgets('the cancel button spans the card', (tester) async {
      service.mine = [sampleSentRequest()];
      await pumpRequests(tester);

      final card = tester.getSize(
        find.byKey(const ValueKey('sent-request-req-1')),
      );
      final button = tester.getSize(cancelButton());
      // Inside the card's 1px border and 16px padding on each side.
      expect(button.width, card.width - 2 * (1 + 16));
    });

    testWidgets('no "Waiting for traveler" when nothing is pending', (
      tester,
    ) async {
      service.mine = [sampleSentRequest(status: 'accepted')];
      await pumpRequests(tester);

      expect(find.text('Waiting for traveler'), findsNothing);
    });

    testWidgets('a new traveler is labelled as new', (tester) async {
      service.mine = [
        SentRequest(
          id: 'req-new',
          status: 'pending',
          createdAt: DateTime(2030, 6, 1),
          totalUsd: 20,
          items: sampleSentRequest().items,
          weightKg: 1,
          dimensions: null,
          sizeClass: null,
          recipientName: 'Jane',
          recipientPhone: '+447700900123',
          photoPaths: const [],
          trip: sampleTrip(itemsDelivered: 0),
        ),
      ];
      await pumpRequests(tester);

      expect(find.text('Traveler · New'), findsOneWidget);
    });
  });

  group('Which requests can be cancelled', () {
    testWidgets('pending, accepted and paid show Cancel request', (
      tester,
    ) async {
      service.mine = [
        sampleSentRequest(id: 'a'),
        sampleSentRequest(id: 'b', status: 'accepted'),
        sampleSentRequest(id: 'c', status: 'paid'),
      ];
      await pumpRequests(tester);

      expect(cancelButton('a'), findsOneWidget);
      expect(cancelButton('b'), findsOneWidget);
      expect(cancelButton('c'), findsOneWidget);
    });

    testWidgets('handed off or finished requests cannot be cancelled', (
      tester,
    ) async {
      service.mine = [
        for (final s in [
          'handed_off',
          'delivered',
          'declined',
          'expired',
          'cancelled',
        ])
          sampleSentRequest(id: s, status: s),
      ];
      await pumpRequests(tester);

      expect(find.text('Cancel Request'), findsNothing);
    });

    testWidgets('tapping Cancel does not open the editor', (tester) async {
      service.mine = [sampleSentRequest()];
      await pumpRequests(tester);

      await openDialog(tester);

      expect(find.text('Edit Request'), findsNothing);
      expect(
        find.byKey(const ValueKey('cancel-request-dialog')),
        findsOneWidget,
      );
    });
  });

  group('Before the traveler accepts', () {
    testWidgets('the dialog says it is free', (tester) async {
      service.mine = [sampleSentRequest()];
      await pumpRequests(tester);
      await openDialog(tester);

      expect(find.text('Cancel this request?'), findsOneWidget);
      expect(
        find.text("The traveler hasn't accepted yet, so cancelling is free."),
        findsOneWidget,
      );
      expect(find.textContaining(r'$12'), findsNothing);
    });

    testWidgets('confirming cancels at no cost and refreshes the list', (
      tester,
    ) async {
      service.mine = [sampleSentRequest()];
      await pumpRequests(tester);
      final listsBefore = service.listCalls;
      await openDialog(tester);
      await confirm(tester);

      expect(service.cancelled.single.id, 'req-1');
      expect(service.listCalls, listsBefore + 1);
      expect(find.text('Request cancelled'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Cancelled free of charge'), findsOneWidget);
      expect(cancelButton(), findsNothing);
    });
  });

  group('After the traveler accepts', () {
    testWidgets('the dialog shows the 10% fee', (tester) async {
      service.mine = [sampleSentRequest(status: 'accepted')];
      await pumpRequests(tester);
      await openDialog(tester);

      expect(
        find.text(
          r'The traveler already accepted this request. Cancelling now costs a 10% cancellation fee of $12.',
        ),
        findsOneWidget,
      );
      expect(find.text(r'Cancel and pay $12'), findsOneWidget);
    });

    testWidgets('confirming cancels and the card shows the fee', (
      tester,
    ) async {
      service.mine = [sampleSentRequest(status: 'paid')];
      await pumpRequests(tester);
      await openDialog(tester);
      await confirm(tester);

      expect(service.cancelled.single.status, 'paid');
      expect(find.text(r'Cancellation fee: $12'), findsOneWidget);
    });
  });

  testWidgets('Keep request closes the dialog without cancelling', (
    tester,
  ) async {
    service.mine = [sampleSentRequest(status: 'accepted')];
    await pumpRequests(tester);
    await openDialog(tester);

    await tester.tap(find.byKey(const ValueKey('cancel-request-keep')));
    await tester.pumpAndSettle();

    expect(service.cancelled, isEmpty);
    expect(find.text('Accepted'), findsOneWidget);
    expect(cancelButton(), findsOneWidget);
  });

  group('Refusals', () {
    for (final c in {
      RequestFailure.feeChanged:
          'The traveler just answered this request, so the cancellation fee has changed. Please check and try again.',
      RequestFailure.notCancellable: 'This request can no longer be cancelled.',
      RequestFailure.other: 'Could not cancel your request. Please try again.',
    }.entries) {
      testWidgets('${c.key.name}: explained, and the list is reloaded', (
        tester,
      ) async {
        service.mine = [sampleSentRequest()];
        service.fail = RequestException(c.key);
        await pumpRequests(tester);
        final listsBefore = service.listCalls;
        await openDialog(tester);
        await confirm(tester);

        expect(find.text(c.value), findsOneWidget);
        expect(service.listCalls, listsBefore + 1);
      });
    }
  });

  testWidgets('is translated', (tester) async {
    service.mine = [sampleSentRequest(status: 'accepted')];
    await pumpRequests(tester, locale: const Locale('fr'));

    expect(find.text('Annuler la demande'), findsOneWidget);
    await openDialog(tester);
    expect(find.text('Annuler cette demande ?'), findsOneWidget);
    expect(find.text('Garder la demande'), findsOneWidget);
  });
}
