import 'package:carrywise_app/services/market_service.dart';
import 'package:carrywise_app/widgets/market_offers_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

class FakeOffersService extends Fake implements MarketService {
  MarketListingState? state = const MarketListingState(listed: false);
  List<MarketOffer> list = [];
  final listedCalls = <bool>[];
  final accepted = <String>[];
  final declined = <String>[];
  MarketFailure? acceptFailure;

  @override
  Future<MarketListingState?> listing(String groupId) async => state;

  @override
  Future<List<MarketOffer>> offers(String groupId) async => [...list];

  @override
  Future<void> setListed(String groupId, bool listed) async {
    listedCalls.add(listed);
    state = MarketListingState(listed: listed, offers: list.length);
  }

  @override
  Future<String> acceptOffer(String offerId) async {
    if (acceptFailure != null) throw MarketException(acceptFailure!);
    accepted.add(offerId);
    list = list.where((o) => o.id != offerId).toList();
    return 'new-request';
  }

  @override
  Future<void> declineOffer(String offerId) async {
    declined.add(offerId);
    list = list.where((o) => o.id != offerId).toList();
  }
}

MarketOffer offer(String id, {String name = 'Emeka', String last = 'Okafor'}) =>
    MarketOffer(
      id: id,
      tripId: 'trip-$id',
      travelerId: 'trav-$id',
      firstName: name,
      lastName: last,
      avatarPath: 'https://example.com/$id.jpg',
      verified: true,
      rating: 4.9,
      itemsDelivered: 3,
      departureDate: DateTime(2030, 6, 20),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeOffersService service;
  late List<String> paid;
  setUp(() {
    service = FakeOffersService();
    paid = [];
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: MarketOffersPanel(
            groupId: 'g1',
            service: service,
            onAccepted: paid.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing shows when the request isn\'t the sender\'s', (
    tester,
  ) async {
    service.state = null;
    await open(tester);
    expect(find.byKey(const ValueKey('market-panel-g1')), findsNothing);
  });

  testWidgets('the switch puts the request on the market', (tester) async {
    await open(tester);
    expect(find.text('Show on the Parcel Market'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('market-switch-g1')));
    await tester.pumpAndSettle();
    expect(service.listedCalls, [true]);
    final sw = tester.widget<Switch>(
      find.byKey(const ValueKey('market-switch-g1')),
    );
    expect(sw.value, isTrue);
  });

  testWidgets('offers show, with the traveler private until paid', (
    tester,
  ) async {
    service.state = const MarketListingState(listed: true, offers: 2);
    service.list = [offer('o1'), offer('o2', name: 'SkyBird', last: '')];
    await open(tester);
    expect(find.text('OFFERS TO CARRY'), findsOneWidget);
    expect(find.text('Emeka O.'), findsOneWidget);
    expect(find.text('SkyBird'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('traveler-photo-blurred')),
      findsNWidgets(2),
    );
    expect(find.textContaining('3 deliveries'), findsNWidgets(2));
  });

  testWidgets('accepting goes on to pay the new request', (tester) async {
    service.state = const MarketListingState(listed: true, offers: 1);
    service.list = [offer('o1')];
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('market-accept-o1')));
    await tester.pumpAndSettle();
    expect(service.accepted, ['o1']);
    expect(paid, ['new-request']);
    expect(find.textContaining('Offer accepted'), findsOneWidget);
  });

  testWidgets('an offer that is gone says so', (tester) async {
    service.state = const MarketListingState(listed: true, offers: 1);
    service.list = [offer('o1')];
    service.acceptFailure = MarketFailure.offerGone;
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('market-accept-o1')));
    await tester.pumpAndSettle();
    expect(paid, isEmpty);
    expect(find.text('This offer is no longer available.'), findsOneWidget);
  });

  testWidgets('declining removes the offer', (tester) async {
    service.state = const MarketListingState(listed: true, offers: 1);
    service.list = [offer('o1')];
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('market-decline-o1')));
    await tester.pumpAndSettle();
    expect(service.declined, ['o1']);
    expect(find.byKey(const ValueKey('market-offer-row-o1')), findsNothing);
  });
}
