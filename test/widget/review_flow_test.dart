import 'package:carrywise_app/screens/report_problem_screen.dart';
import 'package:carrywise_app/screens/confirm_receipt_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/screens/review_screen.dart';
import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// After the traveler marks a request delivered, the sender confirms receipt
/// and rates the traveler; the rating shows on the traveler's profile.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
    service = FakeRequestService();
  });
  tearDown(() => PreferencesService().resetAll());

  SentRequest delivered({bool confirmed = true, bool reviewed = false}) =>
      sampleSentRequest(
        status: 'delivered',
        travelerVerified: true,
        receiptConfirmedAt: confirmed ? DateTime(2030, 6, 23) : null,
        reviewed: reviewed,
      );

  group('Rate Your Traveler', () {
    bool? popped;

    Future<void> pump(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      popped = null;
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
                      builder: (_) =>
                          ReviewScreen(request: delivered(), service: service),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    ElevatedButton submit(WidgetTester tester) =>
        tester.widget(find.byKey(const ValueKey('review-submit')));

    testWidgets('shows the delivery and the traveler', (tester) async {
      await pump(tester);

      expect(find.text('Rate Your Traveler'), findsOneWidget);
      expect(find.text('Amara K.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('review-traveler-verified')),
        findsOneWidget,
      );
      expect(find.textContaining('Lagos → London'), findsOneWidget);
      expect(find.textContaining('AirPods Max'), findsOneWidget);
      expect(find.textContaining('shared with Amara'), findsOneWidget);
    });

    testWidgets('Submit waits for a rating; stars label it', (tester) async {
      await pump(tester);

      expect(find.text('Tap a star to rate'), findsOneWidget);
      expect(submit(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await tester.pump();
      expect(find.text('Great — exceeded expectations'), findsOneWidget);
      expect(submit(tester).onPressed, isNotNull);
    });

    testWidgets('sends the rating, tags and comment, then closes', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('review-star-5')));
      // Selected in reverse order: they are sent in display order.
      await tester.tap(find.byKey(const ValueKey('review-tag-careful')));
      await tester.tap(find.byKey(const ValueKey('review-tag-on_time')));
      await tester.tap(find.byKey(const ValueKey('review-tag-use_again')));
      await tester.tap(find.byKey(const ValueKey('review-tag-use_again')));
      await tester.enterText(
        find.byKey(const ValueKey('review-comment')),
        'Kept me updated the whole way.',
      );
      await tester.tap(find.byKey(const ValueKey('review-submit')));
      await tester.pumpAndSettle();

      expect(service.reviews, hasLength(1));
      final r = service.reviews.single;
      expect(r.id, 'req-1');
      expect(r.rating, 5);
      expect(r.tags, ['on_time', 'careful']);
      expect(r.comment, 'Kept me updated the whole way.');
      expect(popped, isTrue);
      expect(
        find.textContaining('Thanks for reviewing Amara K.'),
        findsOneWidget,
      );
    });

    testWidgets('a failure stays on the page to retry', (tester) async {
      service.failReview = const RequestException(RequestFailure.other);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('review-star-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not send your review. Please try again.'),
        findsOneWidget,
      );
      expect(popped, isNull);
      expect(submit(tester).onPressed, isNotNull);
    });

    testWidgets('already reviewed closes the page', (tester) async {
      service.failReview = const RequestException(
        RequestFailure.alreadyReviewed,
      );
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('review-star-3')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('review-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text("You've already reviewed this delivery."),
        findsOneWidget,
      );
      expect(popped, isTrue);
    });

    testWidgets('Skip for now closes without a review', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('review-skip')));
      await tester.pumpAndSettle();

      expect(popped, isFalse);
      expect(service.reviews, isEmpty);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Évaluez votre voyageur'), findsOneWidget);
      expect(find.text('Touchez une étoile pour noter'), findsOneWidget);
      expect(find.text("Soigneux avec l'article"), findsOneWidget);
      expect(find.text('Rate Your Traveler'), findsNothing);
    });
  });

  group('Rate Your Sender', () {
    bool? popped;

    Future<void> pump(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      popped = null;
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
                      builder: (_) => ReviewScreen.sender(
                        request: sampleIncoming(status: 'delivered'),
                        service: service,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the sender, the delivery and sender tags', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Rate Your Sender'), findsOneWidget);
      expect(find.text('You delivered the item'), findsOneWidget);
      expect(find.text('Chioma E.'), findsOneWidget);
      expect(find.textContaining('Lagos → London'), findsOneWidget);
      expect(find.textContaining('Apple Watch Series 9'), findsOneWidget);
      for (final tag in [
        'Clear instructions',
        'Well packed',
        'On time for pickup',
        'Friendly',
        'Would carry again',
      ]) {
        expect(find.text(tag), findsOneWidget, reason: tag);
      }
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('sends the sender review, then closes', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await tester.tap(find.byKey(const ValueKey('review-tag-friendly')));
      await tester.tap(find.byKey(const ValueKey('review-tag-well_packed')));
      await tester.enterText(
        find.byKey(const ValueKey('review-comment')),
        'Ready on time.',
      );
      await tester.tap(find.byKey(const ValueKey('review-submit')));
      await tester.pumpAndSettle();

      expect(service.reviews, isEmpty);
      final r = service.senderReviews.single;
      expect(r.id, 'in-1');
      expect(r.rating, 4);
      expect(r.tags, ['well_packed', 'friendly']);
      expect(r.comment, 'Ready on time.');
      expect(popped, isTrue);
    });

    testWidgets('Later closes without a review', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('review-skip')));
      await tester.pumpAndSettle();

      expect(service.senderReviews, isEmpty);
      expect(popped, isFalse);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Notez votre expéditeur'), findsOneWidget);
      expect(find.text('Bien emballé'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
    });
  });

  group('Incoming delivered card', () {
    Future<void> pump(WidgetTester tester) async {
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
    }

    testWidgets('asks to rate the sender, and opens the review', (
      tester,
    ) async {
      service.incoming = [sampleIncoming(status: 'delivered')];
      await pump(tester);

      expect(find.text('Rate the sender'), findsOneWidget);
      expect(find.text('Rate Chioma'), findsOneWidget);

      await tester.tap(find.text('Rate Chioma'));
      await tester.pumpAndSettle();
      expect(find.text('Rate Your Sender'), findsOneWidget);
    });

    testWidgets('once reviewed, it says so', (tester) async {
      service.incoming = [
        sampleIncoming(status: 'delivered', senderReviewed: true),
      ];
      await pump(tester);

      expect(find.text('Review submitted'), findsOneWidget);
      expect(find.text('Rate Chioma'), findsNothing);
      expect(find.text('View Request'), findsOneWidget);
    });

    testWidgets('a pending request shows the sender\'s rating', (tester) async {
      service.incoming = [sampleIncoming(senderRating: 4.6)];
      await pump(tester);

      expect(find.textContaining('★ 4.6'), findsOneWidget);
    });
  });

  group('Outgoing delivered card', () {
    Future<void> pump(WidgetTester tester) async {
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
    }

    testWidgets('Confirm Receipt confirms, then opens the review', (
      tester,
    ) async {
      service.mine = [delivered(confirmed: false)];
      await pump(tester);

      expect(
        find.byKey(const ValueKey('sent-request-review-req-1')),
        findsNothing,
      );
      final before = service.listCalls;
      await tester.tap(
        find.byKey(const ValueKey('sent-request-confirm-receipt-req-1')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmReceiptScreen), findsOneWidget);
      expect(service.receiptsConfirmed, isEmpty);

      await tester.tap(find.byKey(const ValueKey('receipt-yes')));
      await tester.pumpAndSettle();

      expect(service.receiptsConfirmed, ['req-1']);
      expect(find.byType(ReviewScreen), findsOneWidget);

      service.mine = [delivered()];
      await tester.tap(find.byKey(const ValueKey('review-skip')));
      await tester.pumpAndSettle();

      // Reloaded: now waiting for the review.
      expect(service.listCalls, greaterThan(before));
      expect(
        find.byKey(const ValueKey('sent-request-review-req-1')),
        findsOneWidget,
      );
    });

    testWidgets('a failed confirmation is explained', (tester) async {
      service.mine = [delivered(confirmed: false)];
      service.failReview = const RequestException(RequestFailure.other);
      await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('sent-request-confirm-receipt-req-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('receipt-yes')));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not confirm receipt. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(ReviewScreen), findsNothing);
      expect(find.byType(ConfirmReceiptScreen), findsOneWidget);
    });

    testWidgets('Report a problem instead of confirming', (tester) async {
      service.mine = [delivered(confirmed: false)];
      await pump(tester);

      await tester.tap(
        find.byKey(const ValueKey('sent-request-confirm-receipt-req-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('You can report a problem for 3 days'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('receipt-report')));
      await tester.pumpAndSettle();
      expect(find.byType(ReportProblemScreen), findsOneWidget);

      // Nothing to send until a reason is picked.
      final send = find.byKey(const ValueKey('report-send'));
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('report-reason-damaged')));
      await tester.enterText(
        find.byKey(const ValueKey('report-details')),
        'The screen is cracked.',
      );
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(service.reports.single.id, 'req-1');
      expect(service.reports.single.reason, ProblemReason.damaged);
      expect(service.reports.single.details, 'The screen is cracked.');
      expect(service.receiptsConfirmed, isEmpty);
      expect(find.byType(ConfirmReceiptScreen), findsNothing);
      expect(find.byType(ReviewScreen), findsNothing);
      expect(
        find.text("Thanks. We've received your report and will contact you."),
        findsOneWidget,
      );
    });

    testWidgets('a second report is explained', (tester) async {
      service.mine = [delivered(confirmed: false)];
      service.failReport = const RequestException(
        RequestFailure.alreadyReported,
      );
      await pump(tester);
      await tester.tap(
        find.byKey(const ValueKey('sent-request-confirm-receipt-req-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('receipt-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-reason-other')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();

      expect(
        find.text("You've already reported a problem on this delivery."),
        findsOneWidget,
      );
    });

    testWidgets('Leave a Review opens the review', (tester) async {
      service.mine = [delivered()];
      await pump(tester);

      expect(
        find.byKey(const ValueKey('sent-request-confirm-receipt-req-1')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('sent-request-review-req-1')));
      await tester.pumpAndSettle();

      expect(find.byType(ReviewScreen), findsOneWidget);
    });

    testWidgets('once reviewed, it says so', (tester) async {
      service.mine = [delivered(reviewed: true)];
      await pump(tester);

      expect(
        find.byKey(const ValueKey('sent-request-reviewed-req-1')),
        findsOneWidget,
      );
      expect(find.text('You reviewed this delivery'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sent-request-review-req-1')),
        findsNothing,
      );
    });
  });

  group('Traveler profile reviews', () {
    late FakeTravelerService travelers;

    setUp(() => travelers = FakeTravelerService());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(
          TravelerProfileScreen(trip: sampleTrip(), service: travelers),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists what senders said', (tester) async {
      travelers.travelerReviews = [
        TravelerReview(
          id: 'rev-1',
          rating: 5,
          comment: 'Fast and careful.',
          createdAt: DateTime(2030, 5, 2),
          reviewerName: 'Kofi M.',
        ),
        TravelerReview(
          id: 'rev-2',
          rating: 4,
          createdAt: DateTime(2030, 4, 1),
          reviewerName: 'Ada O.',
        ),
      ];
      travelers.reviewTotal = 12;
      await pump(tester);

      expect(find.text('No reviews yet'), findsNothing);
      expect(find.text('Kofi M.'), findsOneWidget);
      expect(find.text('KM'), findsOneWidget);
      expect(find.text('Fast and careful.'), findsOneWidget);
      expect(find.text('Ada O.'), findsOneWidget);
      expect(find.text('12 reviews'), findsOneWidget);
    });

    testWidgets('none yet, or failing to load, says so', (tester) async {
      await pump(tester);
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-reviews-count')), findsNothing);

      travelers.failReviews = true;
      await pump(tester);
      expect(find.text('No reviews yet'), findsOneWidget);
    });
  });
}
