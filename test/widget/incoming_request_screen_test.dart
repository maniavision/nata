import 'package:carrywise_app/screens/incoming_request_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The traveler's view of one request: review it, then accept or decline.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  final now = DateTime(2030, 6, 20, 12);
  bool? popped;

  setUp(() {
    service = FakeRequestService();
    popped = null;
  });

  Future<void> pump(WidgetTester tester, IncomingRequest request) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    service.incoming = [request];
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => IncomingRequestScreen(
                      request: request,
                      service: service,
                      now: () => now,
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

  testWidgets('shows the sender, payout, trip, items and photos', (
    tester,
  ) async {
    await pump(
      tester,
      sampleIncoming(
        items: const [
          RequestItem(
            name: 'Apple Watch Series 9',
            category: RequestCategory.electronics,
            description: 'Sealed box',
          ),
          RequestItem(
            name: 'Scarf',
            category: RequestCategory.apparel,
            description: '',
          ),
        ],
        expiresAt: now.add(const Duration(hours: 23, minutes: 10)),
      ),
    );

    expect(find.text('Request Details'), findsOneWidget);
    expect(find.text('Chioma Eze'), findsOneWidget);
    expect(find.byKey(const ValueKey('sender-verified')), findsOneWidget);
    expect(find.text('Sender · 5 deliveries'), findsOneWidget);
    expect(find.text(r'$32'), findsOneWidget);
    expect(find.text('Lagos → London'), findsOneWidget);
    expect(find.text('Jun 22, 2030'), findsOneWidget);
    expect(find.text('0.45 kg · Shoebox · 15 x 8 x 4 cm'), findsOneWidget);
    expect(find.text('Apple Watch Series 9'), findsOneWidget);
    expect(find.text('Electronics'), findsOneWidget);
    expect(find.text('Sealed box'), findsOneWidget);
    expect(find.text('Scarf'), findsOneWidget);
    expect(find.byKey(const ValueKey('incoming-photo-0')), findsOneWidget);
    expect(find.text('Answer within 23h 10m'), findsOneWidget);
  });

  testWidgets('the recipient stays hidden until accepted', (tester) async {
    await pump(tester, sampleIncoming());

    expect(find.byKey(const ValueKey('recipient-hidden')), findsOneWidget);
    expect(find.text('David Adeleke'), findsNothing);
  });

  testWidgets('once accepted: the recipient\'s name, no answer buttons', (
    tester,
  ) async {
    await pump(tester, sampleIncoming(status: 'paid'));

    expect(find.text('David Adeleke'), findsOneWidget);
    // Never the recipient's phone number.
    expect(find.text('Recipient Phone:'), findsNothing);
    expect(find.textContaining('900456'), findsNothing);
    expect(find.byKey(const ValueKey('incoming-accept')), findsNothing);
    expect(find.byKey(const ValueKey('incoming-decline')), findsNothing);
  });

  testWidgets('Accept answers it and goes back with a change', (tester) async {
    await pump(tester, sampleIncoming());

    await tester.tap(find.byKey(const ValueKey('incoming-accept')));
    await tester.pumpAndSettle();

    expect(service.accepted, ['in-1']);
    expect(popped, isTrue);
  });

  testWidgets('Decline asks, then answers it', (tester) async {
    await pump(tester, sampleIncoming());

    await tester.tap(find.byKey(const ValueKey('incoming-decline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('decline-confirm')));
    await tester.pumpAndSettle();

    expect(service.declined.single, (id: 'in-1', reason: null));
    expect(popped, isTrue);
  });

  testWidgets('a refused accept stays on the screen and says why', (
    tester,
  ) async {
    service.failAnswer = const RequestException(RequestFailure.rateUnavailable);
    await pump(tester, sampleIncoming());

    await tester.tap(find.byKey(const ValueKey('incoming-accept')));
    await tester.pumpAndSettle();

    expect(find.byType(IncomingRequestScreen), findsOneWidget);
    expect(
      find.textContaining("exchange rate isn't available"),
      findsOneWidget,
    );
  });

  group('reviews from travelers', () {
    testWidgets('shows the sender\'s rating and latest reviews', (
      tester,
    ) async {
      service.senderReviewsBySender['sender-1'] = (
        reviews: [
          TravelerReview(
            id: 'r1',
            rating: 5,
            comment: 'Clear pickup instructions.',
            createdAt: DateTime(2030, 6, 14),
            reviewerName: 'Kofi M.',
          ),
          TravelerReview(
            id: 'r2',
            rating: 4,
            createdAt: DateTime(2030, 5, 30),
            reviewerName: 'Adaeze O.',
          ),
        ],
        total: 12,
      );
      await pump(tester, sampleIncoming(senderRating: 4.8));

      expect(service.senderReviewLoads, ['sender-1']);
      expect(find.text('REVIEWS FROM TRAVELERS'), findsOneWidget);
      expect(find.text('RATING AS A SENDER'), findsOneWidget);
      expect(find.textContaining('4.8'), findsOneWidget);
      expect(find.text('12 reviews'), findsOneWidget);
      expect(find.text('Kofi M.'), findsOneWidget);
      expect(find.text('Clear pickup instructions.'), findsOneWidget);
      expect(find.text('Adaeze O.'), findsOneWidget);
      expect(find.byKey(const ValueKey('sender-reviews-none')), findsNothing);
    });

    testWidgets('none yet says so', (tester) async {
      await pump(tester, sampleIncoming());

      expect(find.text('No reviews from travelers yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('sender-rating')), findsNothing);
    });

    testWidgets('failing to load shows none, not an error', (tester) async {
      service.failSenderReviews = true;
      await pump(tester, sampleIncoming());

      expect(find.byKey(const ValueKey('sender-reviews-none')), findsOneWidget);
      expect(find.text('Accept Request'), findsWidgets);
    });
  });

  group('declared value', () {
    IncomingRequest valued(double value, {bool receipt = false}) =>
        sampleIncoming(
          items: [
            RequestItem(
              name: 'Camera',
              category: RequestCategory.electronics,
              description: '',
              value: value,
              valueCurrency: 'USD',
              hasReceipt: receipt,
            ),
          ],
        );

    testWidgets('shows each value and the total', (tester) async {
      await pump(tester, valued(80));

      expect(find.text(r'Value $80'), findsOneWidget);
      expect(find.text(r'Declared value $80'), findsOneWidget);
      expect(find.byKey(const ValueKey('incoming-receipt')), findsNothing);
    });

    testWidgets('says when a receipt is attached', (tester) async {
      await pump(tester, valued(80, receipt: true));

      expect(find.byKey(const ValueKey('incoming-receipt')), findsOneWidget);
    });

    testWidgets('within the traveler\'s limit: no note', (tester) async {
      await pump(tester, valued(100));

      expect(find.byKey(const ValueKey('incoming-over-limit')), findsNothing);
    });

    testWidgets('above the traveler\'s limit: a note', (tester) async {
      await pump(tester, valued(450));

      expect(find.byKey(const ValueKey('incoming-over-limit')), findsOneWidget);
      expect(find.text(r'Above your $100 carrying limit.'), findsOneWidget);
    });

    testWidgets('a higher level lifts the limit', (tester) async {
      service.carryLimit = const CarryLimit(level: 2, limitUsd: 300);
      await pump(tester, valued(250));

      expect(find.byKey(const ValueKey('incoming-over-limit')), findsNothing);
    });

    testWidgets('if the limit can\'t be loaded, no note', (tester) async {
      service.failCarryLimit = true;
      await pump(tester, valued(450));

      expect(find.byKey(const ValueKey('incoming-over-limit')), findsNothing);
      expect(find.text(r'Declared value $450'), findsOneWidget);
    });

    testWidgets('older requests without values show none', (tester) async {
      await pump(tester, sampleIncoming());

      expect(
        find.byKey(const ValueKey('incoming-declared-value')),
        findsNothing,
      );
    });
  });

  testWidgets('is translated', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        IncomingRequestScreen(
          request: sampleIncoming(),
          service: service,
          now: () => now,
        ),
        locale: const Locale('es'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detalles de la solicitud'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });
}
