import 'push_service.dart';
import 'home_search_memory.dart';
import 'screen_cache.dart';
import 'exchange_rate_service.dart';
import 'wallet_money.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Signing in with a phone number that has no account.
class AccountNotFoundException implements Exception {
  const AccountNotFoundException();

  @override
  String toString() => 'AccountNotFoundException';
}

/// Wraps all Supabase authentication calls for the Nata app.
class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ── Current session / user ─────────────────────────────────────────────────

  /// True while a signed-in session is kept on this device (Supabase stores it
  /// until the user logs out), e.g. after the app was closed and reopened.
  bool get hasActiveSession => _client.auth.currentSession != null;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentSession != null;

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  /// Sends an SMS OTP to [phone] (E.164 format, e.g. "+2348034567890").
  ///
  /// NOTE: Requires a Twilio / MessageBird SMS provider configured in
  /// your Supabase dashboard → Authentication → Providers → Phone.
  /// During development you can enable "Enable phone confirmations" and
  /// add a test number in the dashboard to receive the code without a
  /// real SMS provider (Supabase will log the code in the project logs).
  ///
  /// [createUser] decides whether an unknown number gets a new account:
  ///  * true (sign up): the number is added to auth.users and a code is sent.
  ///  * false (log in): the number must already be in auth.users. Nothing is
  ///    created and no SMS is sent otherwise; [AccountNotFoundException] is
  ///    thrown instead. Supabase enforces this, not just the app.
  ///
  /// [profile] (first and last name, on sign-up) travels with the request,
  /// so the profile created when the code is confirmed already has the name
  /// (see migration 20240161).
  Future<void> sendOtp(
    String phone, {
    bool createUser = true,
    Map<String, dynamic>? profile,
  }) async {
    try {
      if (profile == null) {
        await _client.auth.signInWithOtp(
          phone: phone,
          shouldCreateUser: createUser,
        );
      } else {
        await _client.auth.signInWithOtp(
          phone: phone,
          shouldCreateUser: createUser,
          data: profile,
        );
      }
    } on AuthException catch (e) {
      if (!createUser && isAccountNotFound(e)) {
        throw const AccountNotFoundException();
      }
      rethrow;
    }
  }

  /// True when Supabase refused a code because the number has no account
  /// ("Signups not allowed for otp", sent when shouldCreateUser is false).
  @visibleForTesting
  static bool isAccountNotFound(AuthException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('signups not allowed') ||
        e.code == 'otp_disabled' ||
        e.code == 'user_not_found';
  }

  /// Verifies the 6-digit OTP received via SMS.
  /// Returns the [AuthResponse] which contains the session.
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    return await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  /// After a new sign-up, saves [firstName] and [lastName] to
  /// nata.profiles (the row is auto-created by the DB trigger).
  /// Changes the member's name. Refused once their identity check has
  /// started (migration 20240160): throws [NameLockedException].
  Future<void> updateName(String firstName, String lastName) async {
    final userId = currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .schema('nata')
          .from('profiles')
          .update({'first_name': firstName, 'last_name': lastName})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.message.contains('name_locked')) throw const NameLockedException();
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? avatarPath,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    final updates = {
      'id': userId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (avatarPath != null) 'avatar_path': avatarPath,
    };

    try {
      // Upsert ensures the row exists even if the trigger hasn't fired
      await _client
          .schema('nata')
          .from('profiles')
          .upsert(updates, onConflict: 'id');
    } catch (e) {
      // Non-fatal — profile name can be updated later in settings
      debugPrint('[AuthService] updateProfile error: $e');
      rethrow;
    }
  }

  /// Saves the user's country of residence (ISO code, e.g. "NG") to
  /// nata.profiles.country_of_residence. Never throws: the account works
  /// without it, the home screen then falls back to the device's country.
  Future<void> saveCountryOfResidence(String isoCode) async {
    final userId = currentUser?.id;
    final iso = isoCode.trim().toUpperCase();
    if (userId == null || iso.length != 2) return;
    try {
      await _client
          .schema('nata')
          .from('profiles')
          .update({'country_of_residence': iso})
          .eq('id', userId);
    } catch (e) {
      debugPrint('[AuthService] saveCountryOfResidence error: $e');
    }
  }

  /// Fetches the user's profile from nata.profiles.
  Future<Map<String, dynamic>?> getProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      return await _client
          .schema('nata')
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('[AuthService] getProfile error: $e');
      return null;
    }
  }

  /// Wraps a Supabase Realtime stream so a failed subscription never turns into
  /// an unhandled exception. If Realtime is unavailable (e.g. not enabled for
  /// the table, or a transient channel error) the stream quietly falls back to
  /// refreshing with [fetch] every [pollEvery]. An initial value is always
  /// emitted via [fetch].
  Stream<T> _resilientStream<T>({
    required Stream<T> Function() live,
    required Future<T> Function() fetch,
    Duration pollEvery = const Duration(seconds: 30),
  }) {
    late final StreamController<T> controller;
    StreamSubscription<T>? sub;
    Timer? timer;

    Future<void> poll() async {
      try {
        final value = await fetch();
        if (!controller.isClosed) controller.add(value);
      } catch (e) {
        debugPrint('[AuthService] poll error: $e');
      }
    }

    void fallBackToPolling(Object error) {
      debugPrint('[AuthService] Realtime unavailable, polling instead: $error');
      sub?.cancel();
      sub = null;
      timer ??= Timer.periodic(pollEvery, (_) => poll());
    }

    controller = StreamController<T>(
      onListen: () {
        poll();
        try {
          sub = live().listen(
            (value) {
              if (!controller.isClosed) controller.add(value);
            },
            onError: fallBackToPolling,
            cancelOnError: true,
          );
        } catch (e) {
          fallBackToPolling(e);
        }
      },
      onCancel: () {
        sub?.cancel();
        timer?.cancel();
        sub = null;
        timer = null;
      },
    );
    return controller.stream;
  }

  /// Returns a stream of the user's profile updates.
  Stream<Map<String, dynamic>?> profileStream() {
    final userId = currentUser?.id;
    if (userId == null) return Stream.value(null);

    return _resilientStream<Map<String, dynamic>?>(
      live: () => _client
          .schema('nata')
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .map((data) => data.isNotEmpty ? data.first : null),
      fetch: getProfile,
    );
  }

  /// Fetches wallet balances, in US dollars ([WalletMoney] shows them in the
  /// member's currency):
  /// - Available: nata.payouts where traveler_id = current_user and status != 'paid'
  /// - Escrow: nata.payments where sender_id = current_user and status = 'held'
  /// Each is in its own currency (NGN, XOF...), so it is turned into dollars
  /// before they are added up.
  Future<Map<String, double>> getWalletBalances() async {
    final userId = currentUser?.id;
    if (userId == null) return {'available': 0.0, 'escrow': 0.0};

    try {
      // Fetch Available for Payout
      final payoutsResponse = await _client
          .schema('nata')
          .from('payouts')
          .select('amount, currency')
          .eq('traveler_id', userId)
          .neq('status', 'paid');

      // Fetch Held in Escrow
      final paymentsResponse = await _client
          .schema('nata')
          .from('payments')
          .select('amount, currency')
          .eq('sender_id', userId)
          .eq('status', 'held');

      final rates = await ExchangeRateService.shared.rates();
      return {
        'available': WalletMoney.sumInUsd(payoutsResponse as List, rates),
        'escrow': WalletMoney.sumInUsd(paymentsResponse as List, rates),
      };
    } catch (e) {
      debugPrint('[AuthService] getWalletBalances error: $e');
      return {'available': 0.0, 'escrow': 0.0};
    }
  }

  /// Returns a stream of wallet balance updates.
  Stream<Map<String, double>> walletBalancesStream() {
    final userId = currentUser?.id;
    if (userId == null) return Stream.value({'available': 0.0, 'escrow': 0.0});

    // Listen to changes in payouts and payments tables
    return _resilientStream<Map<String, double>>(
      live: () => _client
          .schema('nata')
          .from('payouts')
          .stream(primaryKey: ['id'])
          .eq('traveler_id', userId)
          .asyncMap((_) => getWalletBalances()),
      fetch: getWalletBalances,
    );
  }

  /// The user's delivery statistics, counting only what was delivered:
  /// - Trips Carried: the user's trips with at least one delivered request.
  /// - Parcels Sent: the user's requests (as sender) that were delivered.
  Future<Map<String, int>> getStats() async {
    final userId = currentUser?.id;
    if (userId == null) return {'trips': 0, 'parcels': 0};

    try {
      final trips = await _client
          .schema('nata')
          .from('trips')
          .select('id')
          .eq('traveler_id', userId);

      // Delivered requests the user can see: theirs as sender, and those on
      // their trips as traveler.
      final delivered = await _client
          .schema('nata')
          .from('delivery_requests')
          .select('sender_id, trip_id')
          .eq('status', 'delivered');

      return deliveredStats(
        userId: userId,
        myTripIds: [for (final t in trips as List) '${(t as Map)['id']}'],
        deliveredRequests: [
          for (final r in delivered as List)
            Map<String, dynamic>.from(r as Map),
        ],
      );
    } catch (e) {
      debugPrint('[AuthService] getStats error: $e');
      return {'trips': 0, 'parcels': 0};
    }
  }

  /// Trips carried and parcels sent by [userId], from the delivered requests
  /// (each with sender_id and trip_id) and the ids of the user's own trips.
  /// A trip counts once, however many of its requests were delivered.
  @visibleForTesting
  static Map<String, int> deliveredStats({
    required String userId,
    required List<String> myTripIds,
    required List<Map<String, dynamic>> deliveredRequests,
  }) {
    final mine = myTripIds.toSet();
    final carried = <String>{};
    var parcels = 0;
    for (final r in deliveredRequests) {
      if (r['sender_id'] == userId) parcels++;
      final trip = '${r['trip_id']}';
      if (mine.contains(trip)) carried.add(trip);
    }
    return {'trips': carried.length, 'parcels': parcels};
  }

  /// Returns a stream of stats updates.
  Stream<Map<String, int>> statsStream() {
    final userId = currentUser?.id;
    if (userId == null) return Stream.value({'trips': 0, 'parcels': 0});

    // Refreshes when the user's trips change; delivered counts are also read
    // each time the profile opens.
    return _resilientStream<Map<String, int>>(
      live: () => _client
          .schema('nata')
          .from('trips')
          .stream(primaryKey: ['id'])
          .eq('traveler_id', userId)
          .asyncMap((_) => getStats()),
      fetch: getStats,
    );
  }

  /// Uploads a profile picture to the 'user-assets' bucket and returns the STORAGE PATH.
  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // A unique file name per upload gives every picture its own URL, so no
    // device, CDN or image cache can keep serving a previous picture.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'avatar_${userId}_$stamp.$extension';
    final path = 'avatars/$userId/$fileName';

    // Normalize extension for contentType
    String mimeType = 'image/jpeg';
    if (extension.toLowerCase() == 'png') mimeType = 'image/png';
    if (extension.toLowerCase() == 'gif') mimeType = 'image/gif';
    if (extension.toLowerCase() == 'webp') mimeType = 'image/webp';

    await _client.storage
        .from('user-assets')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
        );

    return path;
  }

  /// Deletes a previously uploaded avatar from storage. Best effort: failures
  /// are logged and ignored. Only files inside the current user's own avatar
  /// folder can be deleted.
  Future<void> deleteAvatar(String? path) async {
    final userId = currentUser?.id;
    if (userId == null || path == null) return;
    final clean = path.trim();
    if (!clean.startsWith('avatars/$userId/')) return;
    try {
      await _client.storage.from('user-assets').remove([clean]);
    } catch (e) {
      debugPrint('[AuthService] deleteAvatar error: $e');
    }
  }

  /// Returns the public URL for a given avatar path.
  /// The URL is stable across calls so it can be cached. After a new upload,
  /// the cache is refreshed via `AvatarImage.replace` rather than by changing
  /// the URL. [timestamp] can still be passed to force a cache-busting URL.
  String getAvatarUrl(String? path, {String? timestamp}) {
    if (path == null || path.trim().isEmpty) return '';

    String finalPath = path.trim();

    // 1. Handle full URLs (backwards compatibility)
    if (finalPath.startsWith('http')) {
      // Fix singular/plural if it's a Supabase URL
      if (finalPath.contains('/public/user-assets/avatar/')) {
        finalPath = finalPath.replaceFirst(
          '/public/user-assets/avatar/',
          '/public/user-assets/avatars/',
        );
      }

      // Remove existing timestamp if any to avoid stacking them
      if (finalPath.contains('?t=')) {
        finalPath = finalPath.split('?t=').first;
      } else if (finalPath.contains('&t=')) {
        finalPath = finalPath.split('&t=').first;
      }

      // Keep the URL stable so image caches can reuse it.
      if (timestamp == null) return finalPath;
      final separator = finalPath.contains('?') ? '&' : '?';
      return '$finalPath${separator}t=$timestamp';
    }

    // 2. Handle relative storage paths
    if (finalPath.startsWith('/')) {
      finalPath = finalPath.substring(1);
    }

    // Auto-correct old 'avatar/' prefix to 'avatars/'
    if (finalPath.startsWith('avatar/') && !finalPath.startsWith('avatars/')) {
      finalPath = finalPath.replaceFirst('avatar/', 'avatars/');
    }

    // Ensure we are hitting the correct bucket
    final url = _client.storage.from('user-assets').getPublicUrl(finalPath);
    // Stable URL (no per-call timestamp) so image caches can reuse it.
    // Pass [timestamp] only if you explicitly need to bypass caches.
    return timestamp == null ? url : '$url?t=$timestamp';
  }

  /// Signs the current user out and clears the session.
  Future<void> signOut() async {
    await PushService.instance.signingOut();
    await _client.auth.signOut();
    // The next person to sign in on this device starts with an empty search,
    // and none of the pages this one saw.
    HomeSearchMemory.clear();
    ScreenCache.clear();
  }
}

/// The name can't be changed once the identity check has started.
class NameLockedException implements Exception {
  const NameLockedException();
}
