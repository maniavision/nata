import 'package:carrywise_app/screens/parcel_market_screen.dart';
import 'package:carrywise_app/services/market_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

class FakeMarketService extends Fake implements MarketService {
  List<MarketListing> items = [];
  bool failList = false;
  MarketFailure? offerFailure;
  OfferOutcome outcome = OfferOutcome.offered;
  final sentOffers = <(String, String)>[];
  final withdrawn = <String>[];

  @override
  Future<List<MarketListing>> listings() async {
    if (failList) throw Exception('list failed');
    return [...items];
  }

  @override
  Future<OfferOutcome> offer(String groupId, String tripId) async {
    if (offerFailure != null) throw MarketException(offerFailure!);
    sentOffers.add((groupId, tripId));
    items = [
      for (final i in items)
        i.groupId == groupId && outcome == OfferOutcome.offered
            ? listing(
                id: i.groupId,
                offers: i.offers + 1,
                myOfferId: 'offer-new',
              )
            : i,
    ];
    if (outcome == OfferOutcome.accepted) {
      items = items.where((i) => i.groupId != groupId).toList();
    }
    return outcome;
  }

  @override
  Future<void> withdraw(String offerId) async {
    withdrawn.add(offerId);
    items = [
      for (final i in items)
        i.myOfferId == offerId ? listing(id: i.groupId) : i,
    ];
  }
}

MarketListing listing({
  String id = 'g1',
  String category = 'apparel',
  List<String> categories = const ['apparel'],
  int pending = 2,
  int offers = 0,
  String? myOfferId,
  String? myRequestId,
}) => MarketListing(
  groupId: id,
  tripId: 'trip-$id',
  itemName: 'Birth certificate, Degree',
  category: category,
  itemCount: 2,
  categories: categories,
  weightKg: 0.5,
  fromCity: 'Lagos',
  fromCountryCode: 'NG',
  toCity: 'Houston',
  toCountryCode: 'US',
  senderName: 'SkyBird',
  senderAvatar: 'https://example.com/avatar.jpg',
  senderVerified: true,
  senderRating: 4.8,
  pendingRequests: pending,
  offers: offers,
  myOfferId: myOfferId,
  myRequestId: myRequestId,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeMarketService service;
  setUp(() => service = FakeMarketService());

  Future<void> open(
    WidgetTester tester, {
    bool hasLiveTrip = true,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        ParcelMarketScreen(service: service, hasLiveTrip: hasLiveTrip),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a listing shows the sender privately, the item and counts', (
    tester,
  ) async {
    service.items = [listing(offers: 1)];
    await open(tester);

    expect(find.text('SkyBird'), findsOneWidget);
    expect(find.byKey(const ValueKey('market-sender-verified')), findsOne);
    expect(find.byKey(const ValueKey('traveler-photo-blurred')), findsOne);
    expect(find.text('Birth certificate, Degree'), findsOneWidget);
    expect(find.text('Lagos → Houston · 2 items · 0.5 kg'), findsOneWidget);
    expect(find.text('2 travelers asked'), findsOneWidget);
    expect(find.text('1 offered'), findsOneWidget);
  });

  testWidgets('no offers yet shows no offer count', (tester) async {
    service.items = [listing(pending: 0)];
    await open(tester);
    expect(find.text('No requests yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('market-offers-g1')), findsNothing);
  });

  testWidgets('documents and electronics are flagged', (tester) async {
    service.items = [
      listing(id: 'a', categories: const ['documents']),
      listing(id: 'b', categories: const ['apparel']),
    ];
    await open(tester);
    expect(find.byKey(const ValueKey('market-restricted-a')), findsOne);
    expect(find.byKey(const ValueKey('market-restricted-b')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('market-offer-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('market-restricted-note')), findsOne);
  });

  testWidgets('offering asks first, then sends the offer', (tester) async {
    service.items = [listing()];
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('market-offer-g1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('market-offer-sheet')), findsOne);
    expect(find.textContaining('SkyBird sees your offer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('market-offer-confirm')));
    await tester.pumpAndSettle();
    expect(service.sentOffers, [('g1', 'trip-g1')]);
    expect(find.textContaining('Offer sent. We'), findsOneWidget);
    expect(find.byKey(const ValueKey('market-offer-sent-g1')), findsOne);
  });

  testWidgets('"Not now" sends nothing', (tester) async {
    service.items = [listing()];
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('market-offer-g1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('market-offer-cancel')));
    await tester.pumpAndSettle();
    expect(service.sentOffers, isEmpty);
  });

  testWidgets('a traveler the sender already asked accepts the request', (
    tester,
  ) async {
    service.items = [listing(myRequestId: 'r1')];
    service.outcome = OfferOutcome.accepted;
    await open(tester);

    expect(find.text('Accept the request'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('market-offer-g1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('already asked you'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('market-offer-confirm')));
    await tester.pumpAndSettle();
    expect(service.sentOffers, [('g1', 'trip-g1')]);
    expect(find.textContaining('Request accepted'), findsOneWidget);
  });

  testWidgets('a sent offer can be withdrawn', (tester) async {
    service.items = [listing(myOfferId: 'o1', offers: 1)];
    await open(tester);
    expect(find.text('Offer sent'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('market-withdraw-g1')));
    await tester.pumpAndSettle();
    expect(service.withdrawn, ['o1']);
    expect(find.byKey(const ValueKey('market-offer-g1')), findsOne);
  });

  testWidgets('a full item says why', (tester) async {
    service.items = [listing()];
    service.offerFailure = MarketFailure.offerLimit;
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('market-offer-g1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('market-offer-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('This item already has 5 offers waiting.'), findsOne);
  });

  testWidgets('empty: with and without a live trip', (tester) async {
    await open(tester);
    expect(find.text('No items on your routes yet'), findsOneWidget);

    await open(tester, hasLiveTrip: false);
    expect(find.text('Post a trip first'), findsOneWidget);
  });

  testWidgets('a failed load can be retried', (tester) async {
    service.failList = true;
    await open(tester);
    expect(find.byKey(const ValueKey('market-error')), findsOne);
    service.failList = false;
    service.items = [listing()];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('market-item-g1')), findsOne);
  });

  testWidgets('in French', (tester) async {
    service.items = [listing(offers: 1)];
    await open(tester, locale: const Locale('fr'));
    expect(find.text('Marché des colis'), findsOneWidget);
    expect(find.text('2 voyageurs sollicités'), findsOneWidget);
    expect(find.text('Proposer de transporter'), findsOneWidget);
  });
}
