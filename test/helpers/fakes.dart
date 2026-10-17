import 'dart:async';
import 'package:carrywise_app/services/ticket_redaction_service.dart';
import 'package:carrywise_app/services/ticket_check_service.dart';
import 'dart:typed_data';

import 'package:carrywise_app/services/app_update_service.dart';
import 'package:carrywise_app/services/auth_service.dart';
import 'package:carrywise_app/services/biometric_service.dart';
import 'package:carrywise_app/services/city_service.dart';
import 'package:carrywise_app/services/emergency_contact_service.dart';
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
import 'package:carrywise_app/screens/delivery_task_screen.dart';
import 'package:carrywise_app/services/payment_service.dart';

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

  /// The traveler's reviews, newest first, and the total count.
  List<TravelerReview> travelerReviews = [];
  int? reviewTotal;
  bool failReviews = false;

  @override
  Future<TravelerReviews> reviews(String travelerId, {int limit = 10}) async {
    if (failReviews) throw StateError('reviews failed');
    return (
      reviews: travelerReviews.take(limit).toList(),
      total: reviewTotal ?? travelerReviews.length,
    );
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
      'country_of_residence': 'NG',
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

  /// Countries saved with [saveCountryOfResidence].
  final List<String> countriesSaved = [];

  @override
  Future<void> saveCountryOfResidence(String isoCode) async {
    countriesSaved.add(isoCode);
  }

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

  /// The blurred copy senders see; null for a trip that has none yet.
  String? sharedTicket = 'user-1/111-shared.jpg',
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
    ticketSharedPath: sharedTicket,
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
  static const sharedPath = 'user-1/999-shared.jpg';

  @override
  Future<List<Trip>> myTrips() async {
    loadCount++;
    if (failLoad) throw Exception('load failed');
    return trips;
  }

  @override
  Future<String> uploadReceipt(
    PickedReceipt receipt, {
    String suffix = '',
  }) async {
    if (failUpload) throw Exception('upload failed');
    uploaded.add(receipt);
    return suffix == '-shared' ? sharedPath : uploadedPath;
  }

  @override
  Future<void> deleteReceipt(String? path) async => deletedReceipts.add(path);

  /// Receipts downloaded to check them again.
  final List<String> downloadedReceipts = [];

  @override
  Future<Uint8List> downloadReceipt(String path) async {
    downloadedReceipts.add(path);
    return Uint8List.fromList([1, 2, 3]);
  }

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
  // Chat opens once the delivery is paid.
  String status = 'paid',
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

/// Makes the blurred ticket copy on Add Trip: answers [result] (null: the
/// booking reference could not be found) and records what it was asked.
class FakeTicketRedaction extends Fake implements TicketRedactionService {
  Uint8List? result;
  final List<({String fileName, String? reference})> calls = [];

  @override
  Future<Uint8List?> redact(
    Uint8List bytes,
    String fileName, {
    String? bookingReference,
  }) async {
    calls.add((fileName: fileName, reference: bookingReference));
    return result;
  }
}

// ── Delivery requests ─────────────────────────────────────────────────────────

/// The ticket check on Add Trip, answering [result] and recording what it
/// was asked.
class FakeTicketCheck extends Fake implements TicketCheckService {
  TicketCheckResult result = TicketCheckResult.passed;
  final List<({String fileName, DateTime departure, DateTime arrival})> calls =
      [];

  @override
  Future<TicketCheckResult> check({
    required Uint8List bytes,
    required String fileName,
    required DateTime departure,
    required DateTime arrival,
  }) async {
    calls.add((fileName: fileName, departure: departure, arrival: arrival));
    return result;
  }
}

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

  /// The user's sent requests, for the Outgoing tab.
  List<SentRequest> mine = [];
  bool failList = false;
  int listCalls = 0;

  @override
  Future<List<SentRequest>> myRequests() async {
    listCalls++;
    if (failList) throw StateError('list failed');
    return mine;
  }

  /// Saved edits: the request, the new draft and the new photos (null =
  /// unchanged).
  final List<
    ({SentRequest request, RequestDraft draft, List<PickedReceipt>? photos})
  >
  updated = [];

  @override
  Future<void> update(
    SentRequest request,
    RequestDraft draft, {
    List<PickedReceipt>? photos,
  }) async {
    attempts++;
    if (fail != null) throw fail!;
    updated.add((request: request, draft: draft, photos: photos));
  }

  /// Requests on the user's trips, for the Incoming tab.
  List<IncomingRequest> incoming = [];
  bool failIncoming = false;
  int incomingCalls = 0;

  /// Accepted / declined request ids (with the decline reason).
  final List<String> accepted = [];
  final List<({String id, String? reason})> declined = [];
  RequestException? failAnswer;

  @override
  Future<List<IncomingRequest>> incomingRequests() async {
    incomingCalls++;
    if (failIncoming) throw StateError('incoming failed');
    return incoming;
  }

  /// Answering moves the request on, as the database would.
  void _answer(String id, String status) {
    incoming = [
      for (final r in incoming)
        r.id == id ? sampleIncoming(id: r.id, status: status) : r,
    ].where((r) => r.status != 'declined').toList();
  }

  @override
  Future<void> accept(String requestId) async {
    if (failAnswer != null) throw failAnswer!;
    accepted.add(requestId);
    _answer(requestId, 'accepted');
  }

  @override
  Future<void> decline(String requestId, {String? reason}) async {
    if (failAnswer != null) throw failAnswer!;
    declined.add((id: requestId, reason: reason));
    _answer(requestId, 'declined');
  }

  @override
  Future<String> photoUrl(String path) async =>
      'https://example.test/signed/$path';

  /// Payments started (request id and method); [failStartPayment] makes
  /// starting fail. [paymentStatuses] are answered in order, the last one
  /// repeating.
  final List<({String id, PayMethod method, String? country})> paymentsStarted =
      [];
  RequestException? failStartPayment;
  PaymentLink nextPayment = PaymentLink(
    Uri.parse('https://checkout.flutterwave.test/pay/abc'),
    'nata-req-1-tx',
  );
  List<PaymentStatus> paymentStatuses = [PaymentStatus.pending];
  final List<String> paymentChecks = [];

  @override
  Future<PaymentLink> startPayment(
    String requestId,
    PayMethod method, {
    String? country,
  }) async {
    if (failStartPayment != null) throw failStartPayment!;
    paymentsStarted.add((id: requestId, method: method, country: country));
    return nextPayment;
  }

  /// Mobile money countries offered at checkout; [failMobileOptions] makes
  /// loading them fail.
  List<MobileMoneyOption> mobileOptions = const [
    MobileMoneyOption(
      countryCode: 'GH',
      countryName: 'Ghana',
      currency: 'GHS',
      amount: 1210,
    ),
    MobileMoneyOption(
      countryCode: 'KE',
      countryName: 'Kenya',
      currency: 'KES',
      amount: 14230,
      suggested: true,
    ),
  ];
  bool failMobileOptions = false;

  @override
  Future<List<MobileMoneyOption>> mobileMoneyOptions(String requestId) async {
    if (failMobileOptions) throw StateError('options failed');
    return mobileOptions;
  }

  @override
  Future<PaymentStatus> paymentStatus(String txRef) async {
    paymentChecks.add(txRef);
    final i = paymentChecks.length - 1;
    return paymentStatuses[i < paymentStatuses.length
        ? i
        : paymentStatuses.length - 1];
  }

  /// The handover: delivery codes by request, codes texted, items picked up
  /// and codes entered. [deliveryChecks] are answered in order, the last one
  /// repeating.
  Map<String, DeliveryCode> codes = {};
  final List<String> codesTexted = [];
  RequestException? failTextCode;
  final List<String> pickedUp = [];
  RequestException? failPickUp;
  List<DeliveryCheckResult> deliveryChecks = [
    (result: DeliveryCheck.delivered, attemptsLeft: 0),
  ];
  final List<({String id, String code, String? account})> deliveryAttempts = [];

  @override
  Future<DeliveryCode?> deliveryCode(String requestId) async =>
      codes[requestId];

  @override
  Future<void> sendDeliveryCode(String requestId) async {
    if (failTextCode != null) throw failTextCode!;
    codesTexted.add(requestId);
  }

  @override
  Future<void> markPickedUp(String requestId) async {
    if (failPickUp != null) throw failPickUp!;
    pickedUp.add(requestId);
  }

  @override
  Future<DeliveryCheckResult> confirmDelivery(
    String requestId,
    String code, {
    String? payoutAccountId,
  }) async {
    deliveryAttempts.add((id: requestId, code: code, account: payoutAccountId));
    final i = deliveryAttempts.length - 1;
    return deliveryChecks[i < deliveryChecks.length
        ? i
        : deliveryChecks.length - 1];
  }

  /// Receipts confirmed and reviews sent; [failReview] makes both fail.
  final List<String> receiptsConfirmed = [];
  final List<({String id, int rating, List<String> tags, String comment})>
  reviews = [];
  RequestException? failReview;

  /// When set, sending a review waits for it.
  Completer<void>? reviewGate;

  @override
  Future<void> confirmReceipt(String requestId) async {
    if (failReview != null) throw failReview!;
    receiptsConfirmed.add(requestId);
  }

  @override
  Future<void> submitReview(
    String requestId, {
    required int rating,
    List<String> tags = const [],
    String comment = '',
  }) async {
    if (reviewGate != null) await reviewGate!.future;
    if (failReview != null) throw failReview!;
    reviews.add((id: requestId, rating: rating, tags: tags, comment: comment));
  }

  /// Ticket checks confirmed (request ids); [failTicket] makes them fail.
  final List<String> ticketChecks = [];
  RequestException? failTicket;

  /// When set, loading the ticket link fails.
  bool failTicketUrl = false;

  /// ID checks confirmed (request ids); [failId] makes them fail.
  final List<String> idChecks = [];
  RequestException? failId;

  /// What travelerIdPhoto returns; [failIdPhoto] makes it throw.
  TravelerIdPhoto? idPhoto = TravelerIdPhoto(
    url: 'https://example.test/signed/id_photo.jpg',
    idDocumentType: 'passport',
    verifiedAt: DateTime.utc(2030, 5, 2, 9),
  );
  bool failIdPhoto = false;
  final List<String> idPhotoCalls = [];

  @override
  Future<DateTime> confirmIdChecked(String requestId) async {
    if (failId != null) throw failId!;
    idChecks.add(requestId);
    return DateTime(2030, 6, 21, 12);
  }

  @override
  Future<TravelerIdPhoto?> travelerIdPhoto(String requestId) async {
    idPhotoCalls.add(requestId);
    if (failIdPhoto) throw StateError('no photo');
    return idPhoto;
  }

  @override
  Future<DateTime> confirmTicketChecked(String requestId) async {
    if (failTicket != null) throw failTicket!;
    ticketChecks.add(requestId);
    return DateTime(2030, 6, 21, 12);
  }

  @override
  Future<String> ticketUrl(String path) async {
    if (failTicketUrl) throw StateError('no link');
    return 'https://example.test/signed/$path';
  }

  /// Requests cancelled, in order. On success the matching request in [mine]
  /// becomes cancelled with the fee, as the database would do.
  final List<SentRequest> cancelled = [];

  @override
  Future<double> cancel(SentRequest request) async {
    attempts++;
    if (fail != null) throw fail!;
    final fee = request.cancellationFeeNow ?? 0;
    cancelled.add(request);
    mine = [
      for (final r in mine)
        r.id == request.id
            ? sampleSentRequest(
                id: r.id,
                status: 'cancelled',
                cancellationFee: fee,
                cancelledAt: DateTime(2030, 6, 10),
              )
            : r,
    ];
    return fee;
  }

  @override
  Future<List<PickedReceipt>> downloadPhotos(List<String> paths) async => [
    for (final p in paths)
      PickedReceipt(
        bytes: Uint8List(1024),
        name: p.split('/').last,
        extension: 'jpg',
      ),
  ];
}

/// A request on one of the user's trips, by default waiting for an answer.
IncomingRequest sampleIncoming({
  String id = 'in-1',
  String status = 'pending',
  String firstName = 'Chioma',
  String lastName = 'Eze',
  double payoutUsd = 32,
  int senderDeliveries = 5,
  bool senderVerified = true,
  List<RequestItem>? items,
  List<String> photoPaths = const ['sender-1/in-1/0.jpg'],
  DateTime? expiresAt,
  String? recipientName,
  String? recipientPhone,
}) => IncomingRequest(
  id: id,
  status: status,
  createdAt: DateTime(2030, 6, 20, 9),
  expiresAt: expiresAt,
  payoutUsd: payoutUsd,
  items:
      items ??
      const [
        RequestItem(
          name: 'Apple Watch Series 9',
          category: RequestCategory.electronics,
          description: 'Sealed box',
        ),
      ],
  weightKg: 0.45,
  dimensions: '15 x 8 x 4 cm',
  sizeClass: RequestSizeClass.shoebox,
  photoPaths: photoPaths,
  senderId: 'sender-1',
  senderFirstName: firstName,
  senderLastName: lastName,
  senderVerified: senderVerified,
  senderDeliveries: senderDeliveries,
  recipientName:
      recipientName ?? (status == 'pending' ? null : 'David Adeleke'),
  recipientPhone:
      recipientPhone ?? (status == 'pending' ? null : '+447700900456'),
  tripId: 'trip-1',
  departureCity: 'Lagos',
  departureCountry: 'NG',
  arrivalCity: 'London',
  arrivalCountry: 'GB',
  departureDate: DateTime(2030, 6, 22),
  arrivalDate: DateTime(2030, 6, 22),
);

/// A request the user sent, by default pending, for [sampleTrip].
SentRequest sampleSentRequest({
  String id = 'req-1',
  String status = 'pending',
  List<RequestItem>? items,
  double? cancellationFee,
  DateTime? cancelledAt,
  String? displayCurrency,
  double? displayTotal,
  double? displayCancellationFee,
  double? displayCost,
  double? displayFee,
  DateTime? expiresAt,
  DateTime? ticketCheckedAt,
  DateTime? idCheckedAt,
  bool travelerVerified = false,
  String? ticketReceiptPath,
  bool? hasTicket,
  bool hasBookingReference = false,
  DateTime? receiptConfirmedAt,
  bool reviewed = false,
}) => SentRequest(
  id: id,
  status: status,
  createdAt: DateTime(2030, 6, 1),
  totalUsd: 110.91,
  cancellationFee: cancellationFee,
  cancelledAt: cancelledAt,
  displayCurrency: displayCurrency,
  displayTotal: displayTotal,
  displayCancellationFee: displayCancellationFee,
  displayCost: displayCost,
  displayFee: displayFee,
  expiresAt: expiresAt,
  ticketCheckedAt: ticketCheckedAt,
  idCheckedAt: idCheckedAt,
  travelerVerified: travelerVerified,
  ticketReceiptPath: ticketReceiptPath,
  hasTicket: hasTicket,
  hasBookingReference: hasBookingReference,
  receiptConfirmedAt: receiptConfirmedAt,
  reviewed: reviewed,
  items:
      items ??
      const [
        RequestItem(
          name: 'AirPods Max',
          category: RequestCategory.electronics,
          description: 'Sealed box',
        ),
      ],
  weightKg: 0.9,
  dimensions: '20 x 18 x 9',
  sizeClass: RequestSizeClass.shoebox,
  recipientName: 'Jane Doe',
  recipientPhone: '+447700900123',
  photoPaths: const ['u/req-1/0.jpg'],
  trip: sampleTrip(),
);

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

/// Remembers the contact it was asked to save; can be made to fail or wait.
class FakeEmergencyContactService extends Fake
    implements EmergencyContactService {
  final List<EmergencyContact> saved = [];
  Object? fail;
  Completer<void>? gate;
  int attempts = 0;

  @override
  Future<void> save(EmergencyContact contact) async {
    attempts++;
    if (gate != null) await gate!.future;
    if (fail != null) throw fail!;
    saved.add(contact);
  }
}

/// Reports the update you give it, and remembers "Later".
class FakeAppUpdateService extends Fake implements AppUpdateService {
  FakeAppUpdateService({this.update});

  AppUpdate? update;
  bool throwOnCheck = false;
  bool prompt = true;
  int checks = 0;
  final List<AppUpdate> postponed = [];

  @override
  Future<AppUpdate?> check() async {
    checks++;
    if (throwOnCheck) throw Exception('check failed');
    return update;
  }

  @override
  Future<bool> shouldPrompt(AppUpdate update) async => prompt;

  @override
  Future<void> postpone(AppUpdate update) async => postponed.add(update);
}

/// A delivery the traveler accepted, as on the Requests page.
AcceptedDelivery sampleDelivery() => const AcceptedDelivery(
  orderId: 'DEL-8842',
  senderName: 'Sarah Adeleke',
  senderPhotoUrl: 'https://example.com/sarah.jpg',
  senderSubtitle: 'Sender · Escrow Funded',
  senderPhone: '+234 803 555 0142',
  payout: '\$38.00',
  trip: 'Lagos (LOS) → London (LHR)',
  routeCodes: 'LOS → LHR',
  travelDate: 'Jun 22, 2025',
  destinationCity: 'London',
  itemSummary: 'iPad Mini (Sealed Box · 0.6 kg)',
  itemName: 'iPad Mini 64GB (Space Gray)',
  itemDetails: 'Factory Sealed Box · 0.60 kg · 20 × 14 × 4 cm',
  recipientName: 'David Adeleke (London)',
  recipientPhone: '+44 7700 900456',
  meetingSpot: 'LHR Terminal 4 Arrivals Lounge',
  requestId: 'req-1',
);

/// [sampleDelivery], already picked up.
AcceptedDelivery samplePickedUpDelivery() => AcceptedDelivery(
  orderId: 'DEL-8842',
  senderName: 'Sarah Adeleke',
  senderPhotoUrl: 'https://example.com/sarah.jpg',
  senderSubtitle: 'Sender · Escrow Funded',
  senderPhone: '+234 803 555 0142',
  payout: '\$38.00',
  trip: 'Lagos (LOS) → London (LHR)',
  routeCodes: 'LOS → LHR',
  travelDate: 'Jun 22, 2025',
  destinationCity: 'London',
  itemSummary: 'iPad Mini (Sealed Box · 0.6 kg)',
  itemName: 'iPad Mini 64GB (Space Gray)',
  itemDetails: 'Factory Sealed Box · 0.60 kg · 20 × 14 × 4 cm',
  recipientName: 'David Adeleke (London)',
  recipientPhone: '+44 7700 900456',
  requestId: 'req-1',
  pickedUpAt: DateTime(2030, 6, 22, 10, 14),
);

/// Capitals by country, standing in for nata.cities.is_capital.
const _capitals = {
  'NG': ('Nigeria', 'Abuja', 101),
  'GB': ('United Kingdom', 'London', 102),
  'US': ('United States', 'Washington', 103),
  'CM': ('Cameroon', 'Yaoundé', 104),
};

/// A [HomeScreen.capitalLookup] backed by [_capitals]; records the lookups.
final List<String> capitalLookups = [];
Future<LocationSelection?> fakeCapitalLookup(String countryCode) async {
  capitalLookups.add(countryCode);
  final c = _capitals[countryCode];
  if (c == null) return null;
  return LocationSelection(
    country: c.$1,
    countryCode: countryCode,
    city: c.$2,
    displayLabel: '${c.$2}, ${c.$1}',
    cityId: c.$3,
  );
}

/// Stand-in for [PaymentService], keeping one default like the database does
/// (first method added, or the last one marked default; deleting the default
/// promotes the most recent one left).
class FakePaymentService extends Fake implements PaymentService {
  FakePaymentService({
    List<PaymentMethod>? methods,
    this.accounts = const [],
    this.schedule = PayoutSchedule.automatic,
  }) : saved = [...?methods];

  final List<PaymentMethod> saved;
  List<PayoutAccount> accounts;
  PayoutSchedule schedule;

  /// Payouts: the options by country, accounts added, and payouts sent.
  Map<String, PayoutOptions> options = {
    'NG': const PayoutOptions(
      currency: 'NGN',
      banks: [
        PayoutProvider('044', 'Access Bank'),
        PayoutProvider('058', 'GTBank'),
      ],
    ),
    'KE': const PayoutOptions(
      currency: 'KES',
      banks: [PayoutProvider('01', 'KCB Bank')],
      mobileMoney: [PayoutProvider('MPS', 'M-Pesa')],
    ),
  };
  final List<
    ({
      PayoutAccountKind kind,
      String country,
      String code,
      String number,
      String holder,
    })
  >
  addedAccounts = [];
  PayoutAccountException? failAddAccount;
  int payoutsSent = 0;

  @override
  Future<PayoutOptions> payoutOptions(String country) async =>
      options[country] ?? const PayoutOptions();

  @override
  Future<PayoutAccount> addPayoutAccount({
    required PayoutAccountKind kind,
    required String country,
    required PayoutProvider provider,
    required String accountNumber,
    required String holderName,
  }) async {
    if (failAddAccount != null) throw failAddAccount!;
    addedAccounts.add((
      kind: kind,
      country: country,
      code: provider.code,
      number: accountNumber,
      holder: holderName,
    ));
    final account = PayoutAccount(
      id: 'pa${addedAccounts.length}',
      kind: kind,
      institutionName: provider.name,
      countryCode: country,
      accountLast4: accountNumber.substring(accountNumber.length - 4),
      holderName: holderName,
      isDefault: accounts.isEmpty,
    );
    accounts = [...accounts, account];
    return account;
  }

  @override
  Future<int> sendPayouts() async => ++payoutsSent;
  bool failLoad = false;
  bool failSave = false;
  int _nextId = 1;

  @override
  Future<List<PaymentMethod>> methods() async {
    if (failLoad) throw StateError('load failed');
    return List.of(saved);
  }

  @override
  Future<PaymentMethod> addMethod(PaymentMethod method) async {
    if (failSave) throw StateError('save failed');
    final makeDefault = method.isDefault || saved.isEmpty;
    if (makeDefault) {
      for (var i = 0; i < saved.length; i++) {
        saved[i] = saved[i].copyWith(isDefault: false);
      }
    }
    final stored = PaymentMethod.fromJson({
      ...method.toInsertJson('u'),
      'id': 'm${_nextId++}',
      'is_default': makeDefault,
    });
    saved.add(stored);
    return stored;
  }

  @override
  Future<void> removeMethod(String id) async {
    if (failSave) throw StateError('save failed');
    final wasDefault = saved.any((m) => m.id == id && m.isDefault);
    saved.removeWhere((m) => m.id == id);
    if (wasDefault && saved.isNotEmpty) {
      saved[saved.length - 1] = saved.last.copyWith(isDefault: true);
    }
  }

  @override
  Future<List<PayoutAccount>> payoutAccounts() async {
    if (failLoad) throw StateError('load failed');
    return accounts;
  }

  @override
  Future<PayoutSchedule> payoutSchedule() async => schedule;
}

/// The design's sample: Apple Pay (default) and a Visa card.
List<PaymentMethod> samplePaymentMethods() => const [
  PaymentMethod(
    id: 'apple-pay',
    kind: PaymentMethodKind.applePay,
    isDefault: true,
    walletDeviceLabel: "Fortune's iPhone",
  ),
  PaymentMethod(
    id: 'visa-4242',
    kind: PaymentMethodKind.card,
    cardBrand: 'Visa',
    cardLast4: '4242',
    cardExpMonth: 8,
    cardExpYear: 2027,
    cardHolderName: 'Fortune Niama',
  ),
];

PayoutAccount samplePayoutAccount() => const PayoutAccount(
  id: 'barclays',
  institutionName: 'Barclays Bank',
  countryCode: 'GB',
  accountLast4: '2093',
  holderName: 'Fortune Niama',
  isDefault: true,
);

/// A mobile money payout account, next to [samplePayoutAccount]'s bank.
PayoutAccount sampleMobilePayoutAccount() => const PayoutAccount(
  id: 'mpesa',
  kind: PayoutAccountKind.mobileMoney,
  institutionName: 'M-Pesa',
  countryCode: 'KE',
  accountLast4: '5678',
  holderName: 'Fortune Niama',
);
