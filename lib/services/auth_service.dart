import 'push_service.dart';
import 'home_search_memory.dart';
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
  Future<void> sendOtp(String phone, {bool createUser = true}) async {
    try {
      await _client.auth.signInWithOtp(
        phone: phone,
        shouldCreateUser: createUser,
      );
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

  /// Fetches wallet balances based on the specified logic:
  /// - Available: Sum of amount in nata.payouts where traveler_id = current_user and status != 'paid'
  /// - Escrow: Sum of amount in nata.payments where sender_id = current_user and status = 'held'
  Future<Map<String, double>> getWalletBalances() async {
    final userId = currentUser?.id;
    if (userId == null) return {'available': 0.0, 'escrow': 0.0};

    try {
      // Fetch Available for Payout
      final payoutsResponse = await _client
          .schema('nata')
          .from('payouts')
          .select('amount')
          .eq('traveler_id', userId)
          .neq('status', 'paid');

      double available = 0.0;
      final payouts = payoutsResponse as List?;
      if (payouts != null) {
        for (final row in payouts) {
          final amount = row['amount'];
          if (amount != null) {
            available += (amount as num).toDouble();
          }
        }
      }

      // Fetch Held in Escrow
      final paymentsResponse = await _client
          .schema('nata')
          .from('payments')
          .select('amount')
          .eq('sender_id', userId)
          .eq('status', 'held');

      double escrow = 0.0;
      final payments = paymentsResponse as List?;
      if (payments != null) {
        for (final row in payments) {
          final amount = row['amount'];
          if (amount != null) {
            escrow += (amount as num).toDouble();
          }
        }
      }

      return {'available': available, 'escrow': escrow};
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

  /// Fetches the user's trip and delivery statistics.
  /// - Trips Carried: Count of nata.trips where traveler_id = current_user
  /// - Parcels Sent: Count of nata.delivery_requests where sender_id = current_user
  Future<Map<String, int>> getStats() async {
    final userId = currentUser?.id;
    if (userId == null) return {'trips': 0, 'parcels': 0};

    try {
      final tripsResponse = await _client
          .schema('nata')
          .from('trips')
          .select('id')
          .eq('traveler_id', userId);

      final parcelsResponse = await _client
          .schema('nata')
          .from('delivery_requests')
          .select('id')
          .eq('sender_id', userId);

      final tripsCount = (tripsResponse as List?)?.length ?? 0;
      final parcelsCount = (parcelsResponse as List?)?.length ?? 0;

      return {'trips': tripsCount, 'parcels': parcelsCount};
    } catch (e) {
      debugPrint('[AuthService] getStats error: $e');
      return {'trips': 0, 'parcels': 0};
    }
  }

  /// Returns a stream of stats updates.
  Stream<Map<String, int>> statsStream() {
    final userId = currentUser?.id;
    if (userId == null) return Stream.value({'trips': 0, 'parcels': 0});

    // Listen to changes in trips table
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
    // The next person to sign in on this device starts with an empty search.
    HomeSearchMemory.clear();
  }
}
