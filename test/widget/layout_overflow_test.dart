// Regression tests for "A RenderFlex overflowed" errors.
//
// Each screen is rendered at phone widths (the card content is only ~328px
// wide on a 400px phone), with enlarged text, in every supported language
// (translations are often longer than English). Any layout overflow makes the
// framework report an exception, which fails the test.
import 'package:carrywise_app/screens/add_trip_screen.dart';
import 'package:carrywise_app/screens/checkout_escrow_screen.dart';
import 'package:carrywise_app/screens/delivery_confirm_screen.dart';
import 'package:carrywise_app/screens/delivery_request_screen.dart';
import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/identity_verification_screen.dart';
import 'package:carrywise_app/screens/chat_thread_screen.dart';
import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/messages_screen.dart';
import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/screens/profile_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:carrywise_app/screens/review_screen.dart';
import 'package:carrywise_app/screens/sign_up_screen.dart';
import 'package:carrywise_app/screens/splash_screen.dart';
import 'package:carrywise_app/screens/traveler_profile_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:carrywise_app/screens/trips_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/trip_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';
import '../helpers/test_fonts.dart';

const _locales = [Locale('en'), Locale('es'), Locale('fr')];

// Narrow widths; tall so lazily-built lists lay out every item.
// 402px is an iPhone 17 Pro; 360px is a small Android phone.
const _sizes = {
  'narrow 360px': Size(360, 3200),
  'phone 402px': Size(402, 3200),
};

// The stand-in font (Roboto) is about 11% narrower than the app's real font
// (DM Sans); this was measured against a real overflow on a device. So 1.12 is
// "normal" text, and 1.3 is the user's text size set one notch larger.
const _textScales = [1.12, 1.3];

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  var realFonts = false;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Without real text metrics (see test_fonts.dart) these checks would be
    // meaningless, so they are skipped rather than reporting false failures.
    realFonts = await loadRealisticTestFonts();
  });

  /// Long names stress the layouts.
  final longTrip = sampleMyTrip(
    id: 'long',
    departureCity: 'Johannesburg',
    departureCountry: 'Democratic Republic of the Congo',
    arrivalCity: 'Ho Chi Minh City',
    arrivalCountry: 'United Arab Emirates',
    bookingReference: 'ABCDEFG8',
    maxSize: 'Shoebox (30×20×15 cm)',
    requests: 12,
  );

  final screens = <String, Widget Function()>{
    'Add Trip': () => AddTripScreen(service: FakeTripService()),
    'Add Trip (editing)': () =>
        AddTripScreen(trip: longTrip, service: FakeTripService()),
    'My Trips': () => TripsScreen(
      service: FakeTripService(
        trips: [
          longTrip,
          sampleMyTrip(
            id: 'review',
            status: TripStatus.pendingReview,
            bookingReference: 'X7KQ9R',
          ),
          sampleMyTrip(
            id: 'done',
            status: TripStatus.completed,
            departureDate: DateTime.now().subtract(const Duration(days: 30)),
            delivered: 12,
          ),
        ],
      ),
    ),
    'Traveler profile': () => TravelerProfileScreen(
      trip: sampleTrip(
        firstName: 'Oluwaseun-Chukwuemeka',
        lastName: 'Adewale-Okonkwo',
        departureCity: 'Johannesburg',
        arrivalCity: 'Ho Chi Minh City',
        maxSize: 'Envelope / Document',
      ),
      service: FakeTravelerService(),
    ),
    'Traveler results': () => TravelerResultsScreen(
      service: FakeTravelerService(
        trips: [
          sampleTrip(
            firstName: 'Oluwaseun-Chukwuemeka',
            lastName: 'Adewale-Okonkwo',
            departureCity: 'Johannesburg',
            arrivalCity: 'Ho Chi Minh City',
          ),
          ...sampleTravelers(),
        ],
      ),
    ),
    'Home': () => HomeScreen(
      authService: FakeAuthService(),
      travelerService: FakeTravelerService(),
    ),
    'Notifications': () => NotificationsScreen(
      now: () => DateTime(2030, 6, 15, 12),
      service: FakeNotificationService(
        items: [
          sampleNotification(
            id: 'a',
            type: 'request',
            title: 'Request accepted by Oluwaseun-Chukwuemeka Adewale-Okonkwo',
            body:
                'Your delivery request for Johannesburg → Ho Chi Minh City '
                'was accepted. Please arrange the hand-off with the traveler '
                'before the departure date shown on your trip.',
            createdAt: DateTime(2030, 6, 15, 11, 58),
          ),
          sampleNotification(
            id: 'b',
            type: 'message',
            title: 'New message',
            body:
                'Daniel O.: Happy to carry the package to Paris on Jun 24 '
                'and meet you at the airport terminal afterwards.',
            createdAt: DateTime(2030, 6, 15, 11, 40),
          ),
          sampleNotification(
            id: 'c',
            type: 'payment',
            title: 'Payment held in escrow',
            isRead: true,
            createdAt: DateTime(2030, 6, 14, 9),
          ),
        ],
      ),
    ),
    'Home (five travelers)': () => HomeScreen(
      authService: FakeAuthService(),
      travelerService: FakeTravelerService(
        trips: [
          for (var i = 1; i <= 8; i++)
            sampleTrip(
              tripId: 't$i',
              travelerId: 'traveler-$i',
              firstName: 'Oluwaseun-Chukwuemeka',
              lastName: 'Adewale-Okonkwo',
              itemsDelivered: 100 + i,
              departureCity: 'Johannesburg',
              arrivalCity: 'Ho Chi Minh City',
            ),
        ],
      ),
    ),
    'Messages': () => MessagesScreen(
      now: () => DateTime(2030, 6, 15, 12),
      service: FakeMessageService(
        conversations: [
          sampleConversation(
            id: 'a',
            firstName: 'Oluwaseun-Chukwuemeka',
            lastName: 'Adewale-Okonkwo',
            from: 'Johannesburg',
            to: 'Ho Chi Minh City',
            item: 'A very long item description for a sealed parcel',
            lastBody:
                'This is a long message that should be cut off '
                'neatly instead of overflowing the conversation tile.',
            unread: 128,
          ),
          sampleConversation(id: 'b', status: 'delivered', verified: false),
          sampleConversation(id: 'c', lastBody: null),
          sampleConversation(
            id: 'd',
            lastBody: null,
            lastAttachment: 'x/1.jpg',
            lastAuthor: meId,
          ),
        ],
      ),
    ),
    'Chat': () => ChatThreadScreen(
      now: () => DateTime(2030, 6, 15, 12),
      conversation: sampleConversation(
        firstName: 'Oluwaseun-Chukwuemeka',
        lastName: 'Adewale-Okonkwo',
        from: 'Johannesburg',
        to: 'Ho Chi Minh City',
        item: 'A very long item description for a sealed parcel',
      ),
      service: FakeMessageService(
        messages: {
          'conv-1': [
            sampleMessage(
              id: '1',
              body:
                  'A very long message from the other person that has to '
                  'wrap over several lines inside its bubble without '
                  'overflowing, even on a small phone.',
              createdAt: DateTime(2030, 6, 14, 9),
            ),
            sampleMessage(
              id: '2',
              author: meId,
              body:
                  'AnUnbrokenVeryLongWordWithoutAnySpacesToTestWrapping'
                  'AnUnbrokenVeryLongWordWithoutAnySpacesToTestWrapping',
              readAt: DateTime(2030, 6, 14, 9, 5),
              createdAt: DateTime(2030, 6, 14, 9, 1),
            ),
            sampleMessage(
              id: '3',
              body: 'With a photo',
              attachment: 'conv-1/1.jpg',
              createdAt: DateTime(2030, 6, 15, 8),
            ),
          ],
        },
      ),
    ),
    'Requests': () => const RequestsScreen(),
    'Profile (verified)': () => ProfileScreen(authService: FakeAuthService()),
    'Profile (pending)': () => ProfileScreen(
      authService: FakeAuthService()
        ..profile = {
          'first_name': 'Fortune',
          'last_name': 'Niama',
          'verification_status': 'pending',
          'created_at': '2025-03-01T10:00:00+00:00',
        },
    ),
    'Profile (unverified)': () => ProfileScreen(
      authService: FakeAuthService()
        ..profile = {
          'first_name': 'Fortune',
          'last_name': 'Niama',
          'verification_status': 'unverified',
          'created_at': '2025-03-01T10:00:00+00:00',
        },
    ),
    'Delivery request': () => const DeliveryRequestScreen(),
    'Checkout (escrow)': () => const CheckoutEscrowScreen(),
    'Delivery confirmation': () => const DeliveryConfirmScreen(),
    'Review': () => const ReviewScreen(),
    'Identity verification': () => const IdentityVerificationScreen(),
    'Sign in': () => const LoginScreen(),
    'Sign up': () => const SignUpScreen(),
    'Splash': () => SplashScreen(regionService: FakeRegionService()),
    'Splash (region detected)': () => SplashScreen(
      regionService: FakeRegionService(
        region: region(
          iso: 'CD',
          name: 'Democratic Republic of the Congo',
          language: AppLanguage.french,
          currency: AppCurrency.xof,
        ),
      ),
    ),
    // Messages and the chat thread are intentionally not listed yet: they are
    // being rebuilt on real data and get their own layout checks then.
  };

  /// A screen state reached by acting on a screen (tapping a tab, opening a
  /// sheet, moving to a later step). Layout bugs hide in these: they are not
  /// visible until someone opens them.
  final states =
      <
        String,
        ({Widget Function() build, Future<void> Function(WidgetTester) act})
      >{
        'Requests (outgoing tab)': (
          build: () => const RequestsScreen(),
          act: (t) => _tap(t, const ValueKey('requests-tab-1')),
        ),
        'My Trips (past tab)': (
          build: () => TripsScreen(
            service: FakeTripService(
              trips: [
                longTrip,
                sampleMyTrip(
                  id: 'done',
                  status: TripStatus.completed,
                  departureDate: DateTime.now().subtract(
                    const Duration(days: 30),
                  ),
                  delivered: 12,
                  bookingReference: 'ABCDEFG8',
                  departureCity: 'Johannesburg',
                  departureCountry: 'Democratic Republic of the Congo',
                  arrivalCity: 'Ho Chi Minh City',
                  arrivalCountry: 'United Arab Emirates',
                ),
              ],
            ),
          ),
          act: (t) => _tap(t, const ValueKey('trips-tab-1')),
        ),
        'My Trips (empty)': (
          build: () => TripsScreen(service: FakeTripService()),
          act: (t) async {},
        ),
        'Notifications (Requests filter)': (
          build: () => NotificationsScreen(
            now: () => DateTime(2030, 6, 15, 12),
            service: FakeNotificationService(
              items: [
                sampleNotification(
                  id: 'a',
                  type: 'request',
                  title: 'Request accepted by Oluwaseun-Chukwuemeka',
                  body: 'Your delivery request was accepted.',
                  createdAt: DateTime(2030, 6, 15, 11, 58),
                ),
              ],
            ),
          ),
          act: (t) => _tap(t, const ValueKey('notif-filter-1')),
        ),
        'Notifications (empty)': (
          build: () => NotificationsScreen(
            now: () => DateTime(2030, 6, 15, 12),
            service: FakeNotificationService(),
          ),
          act: (t) async {},
        ),
        'Home (date picker open)': (
          build: () => HomeScreen(
            authService: FakeAuthService(),
            travelerService: FakeTravelerService(),
          ),
          act: (t) async {
            await t.tap(find.text('Anytime this month'));
            await t.pump(const Duration(milliseconds: 500));
          },
        ),
        'Add Trip (date picker open)': (
          build: () => AddTripScreen(service: FakeTripService()),
          act: (t) => _tap(t, const ValueKey('add-trip-departure-date')),
        ),
        'Identity verification (face scan step)': (
          build: () => const IdentityVerificationScreen(initialStep: 1),
          act: (t) async {},
        ),
        'Identity verification (success step)': (
          build: () => const IdentityVerificationScreen(initialStep: 2),
          act: (t) async {},
        ),
        'Delivery confirmation (photo added)': (
          build: () => const DeliveryConfirmScreen(),
          act: (t) => _tap(t, const ValueKey('handoff-photo')),
        ),
        'Delivery confirmation (confirming)': (
          build: () => const DeliveryConfirmScreen(),
          act: (t) async {
            await _tap(t, const ValueKey('handoff-photo'));
            await t.tap(find.byKey(const ValueKey('delivery-confirm')));
            await t.pump(const Duration(milliseconds: 200)); // "Confirming..."
            // Tapping Confirm schedules a 1.2s navigation to the review
            // screen; let it run so no timer is left pending at the end.
            await t.pump(const Duration(milliseconds: 1500));
          },
        ),
        'Sign in (error shown)': (
          build: () => const LoginScreen(),
          act: (t) async {
            await t.tap(find.byType(ElevatedButton).first);
            await t.pump(const Duration(milliseconds: 200));
          },
        ),
        'Sign up (error shown)': (
          build: () => const SignUpScreen(),
          act: (t) async {
            await t.tap(find.byType(ElevatedButton).first);
            await t.pump(const Duration(milliseconds: 200));
          },
        ),
        'Traveler profile (several trips)': (
          build: () {
            final a = sampleTrip(
              tripId: 'a',
              departureCity: 'Johannesburg',
              arrivalCity: 'Ho Chi Minh City',
            );
            final b = sampleTrip(
              tripId: 'b',
              departureCity: 'Abuja',
              arrivalCity: 'Dubai',
            );
            return TravelerProfileScreen(
              trip: a,
              service: FakeTravelerService(profile: sampleProfile([a, b])),
            );
          },
          act: (t) async {},
        ),
      };

  void defineLayoutChecks(
    String name,
    Widget Function() build, {
    Future<void> Function(WidgetTester)? act,
  }) {
    group('no overflow: $name', () {
      for (final locale in _locales) {
        for (final size in _sizes.entries) {
          for (final scale in _textScales) {
            testWidgets('${locale.languageCode}, ${size.key}, text x$scale', (
              tester,
            ) async {
              if (!realFonts) {
                markTestSkipped('SDK fonts not found');
                return;
              }
              tester.view.physicalSize = size.value;
              tester.view.devicePixelRatio = 1.0;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.view.reset);
              addTearDown(tester.platformDispatcher.clearAllTestValues);

              await tester.pumpWidget(appWrapper(build(), locale: locale));
              // A few fixed pumps rather than pumpAndSettle: some screens
              // have endless animations (pulsing indicators) that never
              // "settle". Data from the fake services arrives immediately.
              for (var i = 0; i < 4; i++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              if (act != null) {
                await act(tester);
                for (var i = 0; i < 3; i++) {
                  await tester.pump(const Duration(milliseconds: 100));
                }
              }

              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    });
  }

  for (final screen in screens.entries) {
    defineLayoutChecks(screen.key, screen.value);
  }
  for (final state in states.entries) {
    defineLayoutChecks(state.key, state.value.build, act: state.value.act);
  }

  group('no overflow with the error banner showing', () {
    for (final locale in _locales) {
      testWidgets('Add Trip validation error in ${locale.languageCode}', (
        tester,
      ) async {
        if (!realFonts) {
          markTestSkipped('SDK fonts not found');
          return;
        }
        tester.view.physicalSize = const Size(360, 3200);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);

        await tester.pumpWidget(
          appWrapper(AddTripScreen(service: FakeTripService()), locale: locale),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('add-trip-save')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('add-trip-error')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
