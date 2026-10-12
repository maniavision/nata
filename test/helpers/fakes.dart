import 'dart:async';
import 'dart:typed_data';

import 'package:carrywise_app/services/auth_service.dart';
import 'package:carrywise_app/services/biometric_service.dart';
import 'package:carrywise_app/services/city_service.dart';
import 'package:carrywise_app/services/exchange_rate_service.dart';
import 'package:carrywise_app/services/message_service.dart';
import 'package:carrywise_app/services/notification_service.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/region_service.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:carrywise_app/services/traveler_service.dart';
import 'package:carrywise_app/services/trip_service.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

/// A traveler trip for tests. Every field has a sensible default.
TravelerTrip sampleTrip({
  String tripId = 'trip-1',
  String travelerId = 'traveler-1',
  String firstName = 'Amara',
  String lastName = 'Kalu',
  double? avgRating = 4.9,
  int itemsDelivered = 28,
  String departureCity = 'Lagos',
  String departureCountry = 'NG',
  String arrivalCity = 'London',
  String arrivalCountry = 'GB',
  DateTime? departureDate,
  DateTime? arrivalDate,
  double price = 35,
  String currency = 'USD',
  double? maxWeightKg = 3,
  String? maxSize = 'Shoebox (30×20×15 cm)',
}) {
  final dep = departureDate ?? DateTime(2030, 6, 22);
  return TravelerTrip(
    tripId: tripId,
    travelerId: travelerId,
    firstName: firstName,
    lastName: lastName,
    avatarPath: null, // null avoids any network/cache access in tests
    avgRating: avgRating,
    itemsDelivered: itemsDelivered,
    departureCity: departureCity,
    departureCountry: departureCountry,
    arrivalCity: arrivalCity,
    arrivalCountry: arrivalCountry,
    departureDate: dep,
    arrivalDate: arrivalDate ?? dep,
    price: price,
    currency: currency,
    maxWeightKg: maxWeightKg,
    maxSize: maxSize,
  );
}

/// Three travelers matching the sample data the Home screen used to hard-code.
List<TravelerTrip> sampleTravelers() => [
  sampleTrip(),
  sampleTrip(
    tripId: 'trip-2',
    travelerId: 'traveler-2',
    firstName: 'Daniel',
    lastName: 'Okafor',
    avgRating: 5.0,
    itemsDelivered: 41,
    departureCity: 'Accra',
    departureCountry: 'GH',
    arrivalCity: 'Paris',
    arrivalCountry: 'FR',
    departureDate: DateTime(2030, 6, 24),
    maxWeightKg: 5,
  ),
  sampleTrip(
    tripId: 'trip-3',
    travelerId: 'traveler-3',
    firstName: 'Maya',
    lastName: 'Tariq',
    avgRating: 4.8,
    itemsDelivered: 19,
    departureCity: 'Nairobi',
    departureCountry: 'KE',
    arrivalCity: 'Dubai',
    arrivalCountry: 'AE',
    departureDate: DateTime(2030, 6, 26),
    maxWeightKg: 2,
  ),
];

TravelerProfile sampleProfile(
  List<TravelerTrip> trips, {
  String firstName = 'Amara',
  String lastName = 'Kalu',
}) {
  return TravelerProfile(
    id: trips.first.travelerId,
    firstName: firstName,
    lastName: lastName,
    avatarPath: null,
    verificationStatus: 'verified',
    avgRating: trips.first.avgRating,
    itemsDelivered: trips.first.itemsDelivered,
    memberSince: DateTime(2025, 3, 1),
    trips: trips,
  );
}

/// In-memory stand-in for [TravelerService]. Records every search it receives.
class FakeTravelerService extends Fake implements TravelerService {
  FakeTravelerService({
    List<TravelerTrip>? trips,
    this.profile,
    this.failSearch = false,
  }) : trips = trips ?? sampleTravelers();

  List<TravelerTrip> trips;
  TravelerProfile? profile;
  bool failSearch;

  final List<Map<String, dynamic>> searchCalls = [];
  final List<String> profileCalls = [];

  /// When set, searches wait for it (to test a request that is "in flight").
  Completer<void>? searchGate;

  @override
  Future<List<TravelerTrip>> search({
    String? departureCountry,
    String? departureCity,
    String? arrivalCountry,
    String? arrivalCity,
    DateTime? date,
    int limit = 50,
  }) async {
    searchCalls.add({
      'departureCountry': departureCountry,
      'departureCity': departureCity,
      'arrivalCountry': arrivalCountry,
      'arrivalCity': arrivalCity,
      'date': date,
      'limit': limit,
    });
    if (searchGate != null) await searchGate!.future;
    if (failSearch) throw Exception('search failed');
    return trips;
  }

  @override
  Future<TravelerProfile?> getProfile(String travelerId) async {
    profileCalls.add(travelerId);
    return profile;
  }
}

/// Stand-in for [AuthService]: knows the signed-in user's profile, wallet and
/// stats, and records the calls that change something.
class FakeAuthService extends Fake implements AuthService {
  FakeAuthService({
    this.profile = const {
      'first_name': 'Fortune',
      'last_name': 'Niama',
      'avatar_path': null,
      'verification_status': 'verified',
      'created_at': '2025-03-01T10:00:00+00:00',
    },
    this.balances = const {'available': 320.0, 'escrow': 150.0},
    this.stats = const {'trips': 4, 'parcels': 7},
  });

  Map<String, dynamic>? profile;
  Map<String, double> balances;
  Map<String, int> stats;
  bool failProfile = false;

  int signOutCalls = 0;
  final List<String?> avatarsUploaded = [];

  /// Whether a signed-in session is kept on the device (for Face ID).
  bool hasSession = false;

  @override
  bool get hasActiveSession => hasSession;

  /// Phone numbers an SMS code was requested for.
  final List<String> otpRequests = [];

  /// For each request, whether the number was allowed to create an account.
  final List<bool> otpCreateUser = [];
  Object? otpError;

  @override
  Future<void> sendOtp(String phone, {bool createUser = true}) async {
    otpRequests.add(phone);
    otpCreateUser.add(createUser);
    if (otpError != null) throw otpError!;
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    if (failProfile) throw Exception('profile failed');
    return profile;
  }

  @override
  Future<Map<String, double>> getWalletBalances() async => balances;

  @override
  Future<Map<String, int>> getStats() async => stats;

  // The screens also listen to live streams; none of the tests need updates.
  @override
  Stream<Map<String, dynamic>?> profileStream() => const Stream.empty();

  @override
  Stream<Map<String, double>> walletBalancesStream() => const Stream.empty();

  @override
  Stream<Map<String, int>> statsStream() => const Stream.empty();

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<void> deleteAvatar(String? path) async => avatarsUploaded.add(path);
}

// ── Trips ─────────────────────────────────────────────────────────────────────

/// One of the signed-in traveler's own trips ("My Trips").
Trip sampleMyTrip({
  String id = 'my-trip-1',
  String status = TripStatus.live,
  int departureCityId = 1,
  String departureCity = 'Lagos',
  String departureCountryCode = 'NG',
  String departureCountry = 'Nigeria',
  int arrivalCityId = 2,
  String arrivalCity = 'London',
  String arrivalCountryCode = 'GB',
  String arrivalCountry = 'United Kingdom',
  DateTime? departureDate,
  DateTime? arrivalDate,
  double price = 30,
  String currency = 'USD',
  double? maxWeightKg = 3,
  String? maxSize = 'Shoebox (30×20×15 cm)',
  String receipt = 'user-1/111.pdf',
  String? bookingReference,
  int requests = 0,
  int delivered = 0,
}) {
  final today = DateTime.now();
  final dep =
      departureDate ?? DateTime(today.year, today.month, today.day + 10);
  return Trip(
    id: id,
    departureCityId: departureCityId,
    departureCity: departureCity,
    departureCountryCode: departureCountryCode,
    departureCountry: departureCountry,
    arrivalCityId: arrivalCityId,
    arrivalCity: arrivalCity,
    arrivalCountryCode: arrivalCountryCode,
    arrivalCountry: arrivalCountry,
    departureDate: dep,
    arrivalDate: arrivalDate ?? dep,
    price: price,
    currency: currency,
    maxWeightKg: maxWeightKg,
    maxSize: maxSize,
    ticketReceiptPath: receipt,
    status: status,
    bookingReference: bookingReference,
    requestsCount: requests,
    deliveredCount: delivered,
  );
}

/// In-memory stand-in for [TripService]. Records everything that is written.
class FakeTripService extends Fake implements TripService {
  FakeTripService({List<Trip>? trips}) : trips = trips ?? [];

  List<Trip> trips;
  bool failLoad = false;
  bool failUpload = false;
  bool failSave = false;

  /// When set, create/update wait for it (to test the "saving" state).
  Completer<void>? saveGate;

  int loadCount = 0;
  final List<PickedReceipt> uploaded = [];
  final List<TripDraft> created = [];
  final List<({String id, TripDraft draft})> updated = [];
  final List<String?> deletedReceipts = [];

  static const uploadedPath = 'user-1/999.pdf';

  @override
  Future<List<Trip>> myTrips() async {
    loadCount++;
    if (failLoad) throw Exception('load failed');
    return trips;
  }

  @override
  Future<String> uploadReceipt(PickedReceipt receipt) async {
    if (failUpload) throw Exception('upload failed');
    uploaded.add(receipt);
    return uploadedPath;
  }

  @override
  Future<void> deleteReceipt(String? path) async => deletedReceipts.add(path);

  @override
  Future<void> createTrip(TripDraft draft) async {
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw Exception('save failed');
    created.add(draft);
  }

  @override
  Future<void> updateTrip(String tripId, TripDraft draft) async {
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw Exception('save failed');
    updated.add((id: tripId, draft: draft));
  }
}

/// A city the fake location picker can return.
LocationSelection city(String name, String code, String country, int id) =>
    LocationSelection(
      country: country,
      countryCode: code,
      city: name,
      displayLabel: '$name, $country',
      cityId: id,
    );

PickedReceipt sampleReceipt({String name = 'ticket.pdf', int bytes = 2048}) =>
    PickedReceipt(
      bytes: Uint8List(bytes),
      name: name,
      extension: name.split('.').last,
    );

// ── Notifications ─────────────────────────────────────────────────────────────

AppNotification sampleNotification({
  String id = 'n1',
  String type = 'system',
  String title = 'Title',
  String body = 'Body text',
  String? imageUrl,
  bool isRead = false,
  DateTime? createdAt,
}) => AppNotification(
  id: id,
  type: type,
  title: title,
  body: body,
  imageUrl: imageUrl,
  isRead: isRead,
  createdAt: createdAt ?? DateTime(2030, 6, 15, 11, 58),
);

/// In-memory stand-in for [NotificationService].
class FakeNotificationService extends Fake implements NotificationService {
  FakeNotificationService({List<AppNotification>? items}) : items = items ?? [];

  List<AppNotification> items;
  bool failList = false;
  bool failMarkRead = false;
  bool failMarkAll = false;

  int listCalls = 0;
  final List<String> markedRead = [];
  int markAllCalls = 0;

  @override
  Future<List<AppNotification>> list({int limit = 100}) async {
    listCalls++;
    if (failList) throw Exception('list failed');
    return items;
  }

  @override
  Future<void> markRead(String id) async {
    if (failMarkRead) throw Exception('mark failed');
    markedRead.add(id);
  }

  @override
  Future<void> markAllRead() async {
    if (failMarkAll) throw Exception('mark all failed');
    markAllCalls++;
  }
}

// ── Face ID ───────────────────────────────────────────────────────────────────

/// Stand-in for [BiometricService]: you choose what the "device" answers.
class FakeBiometricService extends Fake implements BiometricService {
  BiometricAvailability availabilityResult = BiometricAvailability.available;
  BiometricResult result = BiometricResult.success;

  /// When set, authentication waits for it (to test the "busy" state).
  Completer<void>? gate;

  int authenticateCalls = 0;
  String? lastReason;

  @override
  Future<BiometricAvailability> availability() async => availabilityResult;

  @override
  Future<bool> isAvailable() async =>
      availabilityResult == BiometricAvailability.available;

  @override
  Future<BiometricResult> authenticate(String reason) async {
    authenticateCalls++;
    lastReason = reason;
    if (gate != null) await gate!.future;
    return result;
  }
}

// ── Region detection ──────────────────────────────────────────────────────────

/// A phone whose location you control. Records what the app asked it to do.
class FakeDeviceLocation implements DeviceLocation {
  bool serviceEnabled = true;
  LocationAccess currentAccess = LocationAccess.granted;

  /// What the permission becomes if the app asks the user.
  LocationAccess accessAfterPrompt = LocationAccess.granted;

  ({String isoCode, String? name})? found = (
    isoCode: 'US',
    name: 'United States',
  );
  Object? error;

  int promptCount = 0;
  int countryLookups = 0;

  @override
  Future<bool> isServiceEnabled() async {
    if (error != null) throw error!;
    return serviceEnabled;
  }

  @override
  Future<LocationAccess> access() async => currentAccess;

  @override
  Future<LocationAccess> requestAccess() async {
    promptCount++;
    currentAccess = accessAfterPrompt;
    return currentAccess;
  }

  @override
  Future<({String isoCode, String? name})?> country() async {
    countryLookups++;
    return found;
  }
}

/// Stand-in for [RegionService] with a fixed answer.
class FakeRegionService extends Fake implements RegionService {
  FakeRegionService({this.region});

  DetectedRegion? region;
  Completer<void>? gate;
  int detectCalls = 0;

  @override
  Future<DetectedRegion?> detect() async {
    detectCalls++;
    if (gate != null) await gate!.future;
    return region;
  }
}

DetectedRegion region({
  String iso = 'US',
  String name = 'United States',
  AppLanguage language = AppLanguage.english,
  AppCurrency currency = AppCurrency.usd,
}) => DetectedRegion(
  isoCode: iso,
  countryName: name,
  language: language,
  currency: currency,
);

// ── Messages ──────────────────────────────────────────────────────────────────

const meId = 'me-1';

ConversationSummary sampleConversation({
  String id = 'conv-1',
  String firstName = 'Amara',
  String lastName = 'Kalu',
  String? avatar,
  bool verified = true,
  bool iAmTraveler = false,
  String from = 'Lagos',
  String to = 'London',
  String item = 'iPhone 15 Pro (sealed)',
  String status = 'accepted',
  String? lastBody = 'Meeting you at the gate tomorrow.',
  String? lastAttachment,
  DateTime? lastAt,
  String? lastAuthor = 'other-1',
  int unread = 0,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2030, 6, 10, 9);
  final hasLast = lastBody != null || lastAttachment != null;
  return ConversationSummary(
    id: id,
    requestId: 'req-$id',
    otherUserId: 'other-1',
    otherFirstName: firstName,
    otherLastName: lastName,
    otherAvatarPath: avatar,
    otherVerified: verified,
    iAmTraveler: iAmTraveler,
    departureCity: from,
    arrivalCity: to,
    itemDescription: item,
    requestStatus: status,
    lastBody: lastBody,
    lastAttachmentPath: lastAttachment,
    lastMessageAt: hasLast ? (lastAt ?? DateTime(2030, 6, 15, 11, 58)) : null,
    lastAuthorId: hasLast ? lastAuthor : null,
    unreadCount: unread,
    createdAt: created,
  );
}

ChatMessage sampleMessage({
  String id = 'm1',
  String conversationId = 'conv-1',
  String author = 'other-1',
  String? body = 'Hello',
  String? attachment,
  DateTime? readAt,
  DateTime? createdAt,
}) => ChatMessage(
  id: id,
  conversationId: conversationId,
  authorId: author,
  body: body,
  attachmentPath: attachment,
  readAt: readAt,
  createdAt: createdAt ?? DateTime(2030, 6, 15, 10, 0),
);

/// In-memory stand-in for [MessageService].
class FakeMessageService extends Fake implements MessageService {
  FakeMessageService({
    List<ConversationSummary>? conversations,
    Map<String, List<ChatMessage>>? messages,
  }) : convs = conversations ?? [],
       thread = messages ?? {};

  List<ConversationSummary> convs;
  Map<String, List<ChatMessage>> thread;

  bool failConversations = false;
  bool failMessages = false;
  bool failSend = false;
  bool failUpload = false;
  bool failAttachmentUrl = false;

  /// When set, sending waits for it (to test the "sending" state).
  Completer<void>? sendGate;

  int conversationCalls = 0;
  int messageCalls = 0;
  final List<String> markedRead = [];
  final List<({String conversationId, String? body, String? attachment})> sent =
      [];
  final List<PickedReceipt> uploads = [];
  int _id = 0;

  @override
  String? get currentUserId => meId;

  @override
  Future<List<ConversationSummary>> conversations() async {
    conversationCalls++;
    if (failConversations) throw Exception('conversations failed');
    return convs;
  }

  @override
  Future<List<ChatMessage>> messages(
    String conversationId, {
    int limit = 300,
  }) async {
    messageCalls++;
    if (failMessages) throw Exception('messages failed');
    return [...(thread[conversationId] ?? const [])];
  }

  @override
  Future<ChatMessage> send(
    String conversationId, {
    String? body,
    String? attachmentPath,
  }) async {
    if (sendGate != null) await sendGate!.future;
    if (failSend) throw Exception('send failed');
    sent.add((
      conversationId: conversationId,
      body: body,
      attachment: attachmentPath,
    ));
    final m = ChatMessage(
      id: 'sent-${_id++}',
      conversationId: conversationId,
      authorId: meId,
      body: body,
      attachmentPath: attachmentPath,
      readAt: null,
      createdAt: DateTime(2030, 6, 15, 12, 0).add(Duration(minutes: _id)),
    );
    thread[conversationId] = [...(thread[conversationId] ?? const []), m];
    return m;
  }

  @override
  Future<void> markRead(String conversationId) async =>
      markedRead.add(conversationId);

  @override
  Future<String> uploadAttachment(
    String conversationId,
    PickedReceipt photo,
  ) async {
    if (failUpload) throw Exception('upload failed');
    uploads.add(photo);
    return '$conversationId/${uploads.length}.jpg';
  }

  @override
  Future<String> attachmentUrl(String path) async {
    if (failAttachmentUrl) throw Exception('no url');
    return 'https://example.com/signed/$path';
  }
}

// ── Delivery requests ─────────────────────────────────────────────────────────

/// In-memory stand-in for [RequestService].
class FakeRequestService extends Fake implements RequestService {
  /// When set, the next send fails with this.
  RequestException? fail;

  /// When set, sending waits for it (to test the "sending" state).
  Completer<void>? gate;

  final List<({String id, RequestDraft draft, List<PickedReceipt> photos})>
  sent = [];
  int attempts = 0;

  /// The request id of every attempt, failed or not.
  final List<String> attemptIds = [];

  @override
  Future<String> send(
    String requestId,
    RequestDraft draft,
    List<PickedReceipt> photos,
  ) async {
    attempts++;
    attemptIds.add(requestId);
    if (gate != null) await gate!.future;
    if (fail != null) throw fail!;
    sent.add((id: requestId, draft: draft, photos: photos));
    return requestId;
  }
}

// ── Delivery pricing inputs ───────────────────────────────────────────────────

/// City coordinates by "CC|Name". Defaults to Lagos and London.
class FakeCityService extends Fake implements CityService {
  FakeCityService({Map<String, CityCoordinates>? cities})
    : cities =
          cities ??
          {
            'NG|Lagos': const CityCoordinates(6.5244, 3.3792),
            'GB|London': const CityCoordinates(51.5074, -0.1278),
            'GH|Accra': const CityCoordinates(5.6037, -0.187),
            'FR|Paris': const CityCoordinates(48.8566, 2.3522),
          };

  Map<String, CityCoordinates> cities;
  bool fail = false;
  Completer<void>? gate;
  int lookups = 0;

  @override
  Future<CityCoordinates?> coordinates(String countryCode, String city) async {
    lookups++;
    if (gate != null) await gate!.future;
    if (fail) throw Exception('cities failed');
    return cities['${countryCode.toUpperCase()}|$city'];
  }
}

/// Exchange rates you control. Defaults to the real answer's rates.
class FakeExchangeRateService extends Fake implements ExchangeRateService {
  FakeExchangeRateService({this.result}) {
    result ??= sampleRates();
  }

  ExchangeRates? result;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<ExchangeRates?> rates() async {
    calls++;
    if (gate != null) await gate!.future;
    return result;
  }
}

ExchangeRates sampleRates({DateTime? updatedAt}) => ExchangeRates(
  perUsd: const {
    'USD': 1,
    'EUR': 0.892438,
    'GBP': 0.755923,
    'XOF': 585.399478,
    'XAF': 585.399478,
  },
  updatedAt: updatedAt ?? DateTime.utc(2030, 6, 21, 12, 2),
);
