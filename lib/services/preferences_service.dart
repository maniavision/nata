import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supported languages.
enum AppLanguage {
  english('en', 'English'),
  spanish('es', 'Español'),
  french('fr', 'Français');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String code) =>
      values.firstWhere((l) => l.code == code, orElse: () => english);
}

/// Supported currencies.
enum AppCurrency {
  usd('USD', 'US Dollar', '\$'),
  eur('EUR', 'Euro', '€'),
  gbp('GBP', 'British Pound', '£'),
  xof('XOF', 'Franc CFA', 'CFA');

  const AppCurrency(this.code, this.label, this.symbol);
  final String code;
  final String label;
  final String symbol;

  static AppCurrency fromCode(String code) =>
      values.firstWhere((c) => c.code == code, orElse: () => usd);
}

/// Holds the user's language + currency selections in memory.
///
/// These are set on the splash screen and persisted to nata.profiles
/// when the user completes sign-up. On subsequent launches the values
/// are reloaded from the database.
class PreferencesService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final PreferencesService _instance = PreferencesService._();
  factory PreferencesService() => _instance;
  PreferencesService._();

  // ── In-memory state ────────────────────────────────────────────────────────
  AppLanguage _language = AppLanguage.english;
  AppCurrency _currency = AppCurrency.usd;

  /// The country the phone-number fields start with when nobody has
  /// registered on this device yet.
  static const defaultCountryIso = 'US';

  static const _countryPrefsKey = 'registered_country_iso';
  static const _faceIdPrefsKey = 'face_id_enabled';

  /// The country of residence chosen at sign-up. It is remembered on this
  /// device (see [restore]) and survives logout, so the sign-in screen starts
  /// with the country the user registered with.
  String _countryIsoCode = defaultCountryIso;

  /// Face ID is switched on by signing in with "Remember me" ticked, and off
  /// again when the user logs out. Kept on the device.
  bool _faceIdEnabled = false;
  Future<void> _lastWrite = Future<void>.value();

  AppLanguage get language => _language;
  AppCurrency get currency => _currency;
  String get countryIsoCode => _countryIsoCode;
  bool get faceIdEnabled => _faceIdEnabled;
  Locale get locale => _language.locale;

  // ── Setters (call from splash screen) ─────────────────────────────────────

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
  }

  void setCurrency(AppCurrency cur) {
    if (_currency == cur) return;
    _currency = cur;
    notifyListeners();
  }

  /// Sets the country of residence and remembers it on this device.
  void setCountry(String isoCode) {
    final iso = isoCode.trim().toUpperCase();
    if (iso.length != 2 || _countryIsoCode == iso) return;
    _countryIsoCode = iso;
    notifyListeners();
    _lastWrite = _persist();
  }

  /// Turns Face ID sign-in on or off and remembers the choice on the device.
  void setFaceIdEnabled(bool enabled) {
    if (_faceIdEnabled == enabled) return;
    _faceIdEnabled = enabled;
    notifyListeners();
    _lastWrite = _persist();
  }

  /// Writes the current country and Face ID setting to the device.
  ///
  /// It always writes the *latest* values (read after the device storage is
  /// ready), so several quick changes can be in flight at once and the last one
  /// still wins, whatever order they finish in. Nothing waits on an earlier
  /// write.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_countryPrefsKey, _countryIsoCode);
      await prefs.setBool(_faceIdPrefsKey, _faceIdEnabled);
    } catch (e) {
      debugPrint('PreferencesService: could not save settings: $e');
    }
  }

  /// Loads the country remembered on this device. Call once at app start.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var changed = false;
      final saved = prefs.getString(_countryPrefsKey)?.trim().toUpperCase();
      if (saved != null && saved.length == 2 && saved != _countryIsoCode) {
        _countryIsoCode = saved;
        changed = true;
      }
      final faceId = prefs.getBool(_faceIdPrefsKey) ?? false;
      if (faceId != _faceIdEnabled) {
        _faceIdEnabled = faceId;
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('PreferencesService: could not restore country: $e');
    }
  }

  /// Completes when the last [setCountry] has been written to the device.
  @visibleForTesting
  Future<void> get pendingWrites => _lastWrite;

  /// Sets language by locale code (e.g. 'en', 'es', 'fr').
  void setLanguageCode(String code) => setLanguage(AppLanguage.fromCode(code));

  /// Sets currency by code (e.g. 'USD', 'EUR').
  void setCurrencyCode(String code) => setCurrency(AppCurrency.fromCode(code));

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Saves current preferences to nata.user_settings.
  /// Uses upsert so it works for both new sign-ups and returning users.
  /// Ensures the parent nata.profiles row exists first (FK requirement).
  Future<void> saveToProfile() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Ensure nata.profiles row exists (trigger may not have fired yet)
      await client.schema('nata').from('profiles').upsert({
        'id': userId,
      }, onConflict: 'id');

      // Now upsert the user settings
      await client.schema('nata').from('user_settings').upsert({
        'user_id': userId,
        'language': _language.code,
        'currency_code': _currency.code,
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('PreferencesService.saveToProfile: $e');
    }
  }

  /// Loads preferences from nata.user_settings and applies them in-memory.
  /// Call this after sign-in to restore saved preferences.
  Future<void> loadFromProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final row = await Supabase.instance.client
          .schema('nata')
          .from('user_settings')
          .select('language, currency_code')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return;
      if (row['language'] != null) {
        _language = AppLanguage.fromCode(row['language'] as String);
      }
      if (row['currency_code'] != null) {
        _currency = AppCurrency.fromCode(
          (row['currency_code'] as String).trim(),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('PreferencesService.loadFromProfile: $e');
    }
  }

  /// Resets the account-specific choices (call on sign-out).
  ///
  /// Language and currency go back to their defaults, but the country of
  /// residence is kept: after logging out, the sign-in screen should start with
  /// the country the user registered with, not a generic default.
  void reset() {
    _language = AppLanguage.english;
    _currency = AppCurrency.usd;
    // Face ID signs in to the account that has just logged out: off again.
    if (_faceIdEnabled) {
      _faceIdEnabled = false;
      _lastWrite = _persist();
    }
    notifyListeners();
  }

  /// Back to factory defaults, including the remembered country. Tests only.
  @visibleForTesting
  Future<void> resetAll() async {
    _language = AppLanguage.english;
    _currency = AppCurrency.usd;
    _countryIsoCode = defaultCountryIso;
    _faceIdEnabled = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_countryPrefsKey);
      await prefs.remove(_faceIdPrefsKey);
    } catch (_) {}
    notifyListeners();
  }
}
