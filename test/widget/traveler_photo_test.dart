import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:carrywise_app/widgets/traveler_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Traveler photos are blurred where people browse until the traveler
/// accepts one of the viewer's requests.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const photo = 'https://example.invalid/avatars/amara.jpg';
  final blurred = find.byKey(const ValueKey('traveler-photo-blurred'));

  TravelerTrip trip({bool revealed = false, String? path = photo}) {
    final t = sampleTrip();
    return TravelerTrip(
      tripId: t.tripId,
      travelerId: t.travelerId,
      firstName: t.firstName,
      lastName: t.lastName,
      avatarPath: path,
      avgRating: t.avgRating,
      itemsDelivered: t.itemsDelivered,
      departureCity: t.departureCity,
      departureCountry: t.departureCountry,
      arrivalCity: t.arrivalCity,
      arrivalCountry: t.arrivalCountry,
      departureDate: t.departureDate,
      arrivalDate: t.arrivalDate,
      price: t.price,
      currency: t.currency,
      maxWeightKg: t.maxWeightKg,
      maxSize: t.maxSize,
      photoRevealed: revealed,
    );
  }

  Future<void> pumpPhoto(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(appWrapper(Scaffold(body: Center(child: w))));
    await tester.pump();
  }

  testWidgets('blurred, with no lock, until revealed', (tester) async {
    await pumpPhoto(
      tester,
      const TravelerPhoto(path: photo, revealed: false, size: 52),
    );
    expect(blurred, findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('clear once revealed', (tester) async {
    await pumpPhoto(
      tester,
      const TravelerPhoto(path: photo, revealed: true, size: 52),
    );
    expect(blurred, findsNothing);
  });

  testWidgets('no photo: nothing to hide', (tester) async {
    await pumpPhoto(
      tester,
      const TravelerPhoto(path: null, revealed: false, size: 52),
    );
    expect(blurred, findsNothing);
  });

  test('search results and profiles say whether it is revealed', () {
    final row = TravelerTrip.fromJson({
      'trip_id': 't1',
      'traveler_id': 'u1',
      'departure_date': '2030-06-22',
      'arrival_date': '2030-06-22',
      'photo_revealed': true,
    });
    expect(row.photoRevealed, isTrue);
    final hidden = TravelerTrip.fromJson({
      'trip_id': 't1',
      'traveler_id': 'u1',
      'departure_date': '2030-06-22',
      'arrival_date': '2030-06-22',
    });
    expect(hidden.photoRevealed, isFalse);

    final profile = TravelerProfile.fromJson({
      'id': 'u1',
      'photo_revealed': true,
      'trips': [
        {
          'trip_id': 't1',
          'traveler_id': 'u1',
          'departure_date': '2030-06-22',
          'arrival_date': '2030-06-22',
        },
      ],
    });
    expect(profile.photoRevealed, isTrue);
    expect(profile.trips.single.photoRevealed, isTrue);
  });

  testWidgets('the traveler\'s profile says when the photo shows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        TravelerProfileScreen(trip: trip(), service: FakeTravelerService()),
      ),
    );
    await tester.pump();

    expect(blurred, findsOneWidget);
    expect(
      find.text('Photo shown once they accept your request'),
      findsOneWidget,
    );
  });

  testWidgets('a search result is blurred until revealed', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final travelers = FakeTravelerService(trips: [trip()]);
    await tester.pumpWidget(
      appWrapper(TravelerResultsScreen(service: travelers)),
    );
    await tester.pumpAndSettle();

    expect(blurred, findsWidgets);
  });

  test('on the sender\'s requests, clear once the traveler accepted', () {
    expect(sampleSentRequest(status: 'pending').photoRevealed, isFalse);
    expect(sampleSentRequest(status: 'declined').photoRevealed, isFalse);
    expect(sampleSentRequest(status: 'accepted').photoRevealed, isTrue);
    expect(sampleSentRequest(status: 'paid').photoRevealed, isTrue);
    expect(sampleSentRequest(status: 'delivered').photoRevealed, isTrue);
  });
}
