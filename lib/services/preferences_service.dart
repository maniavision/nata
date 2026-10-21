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

/// The user's language and currency, and what this device remembers.
///
/// A first-time visitor picks language and currency on the splash screen;
/// signing up saves them to the account (nata.user_settings). Signing in
/// applies the account's saved choice instead (see [loadFromProfile]). The
/// device remembers the last language and currency, and that an account has
/// been used here, so a returning member starts on Sign In, in their own
/// language, without the splash.
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
  static const _languagePrefsKey = 'language';
  static const _currencyPrefsKey = 'currency';
  static const _hasAccountPrefsKey = 'has_account';

  /// An account has signed in on this device (until it is deleted).
  bool _hasAccountOnDevice = false;

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
  bool get hasAccountOnDevice => _hasAccountOnDevice;
  Locale get locale => _language.locale;

  // ── Setters (call from splash screen) ─────────────────────────────────────

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    _lastWrite = _persist();
  }

  void setCurrency(AppCurrency cur) {
    if (_currency == cur) return;
    _currency = cur;
    notifyListeners();
    _lastWrite = _persist();
  }

  /// Someone signed in or signed up here: next time the app opens on Sign
  /// In instead of the splash.
  void rememberAccount() {
    if (_hasAccountOnDevice) return;
    _hasAccountOnDevice = true;
    _lastWrite = _persist();
  }

  /// The account was deleted: next time the app starts like a new install.
  void forgetAccount() {
    if (!_hasAccountOnDevice) return;
    _hasAccountOnDevice = false;
    _lastWrite = _persist();
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
      await prefs.setString(_languagePrefsKey, _language.code);
      await prefs.setString(_currencyPrefsKey, _currency.code);
      await prefs.setBool(_hasAccountPrefsKey, _hasAccountOnDevice);
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
      final lang = prefs.getString(_languagePrefsKey);
      if (lang != null && AppLanguage.fromCode(lang) != _language) {
        _language = AppLanguage.fromCode(lang);
        changed = true;
      }
      final cur = prefs.getString(_currencyPrefsKey);
      if (cur != null && AppCurrency.fromCode(cur) != _currency) {
        _currency = AppCurrency.fromCode(cur);
        changed = true;
      }
      final hasAccount = prefs.getBool(_hasAccountPrefsKey) ?? false;
      if (hasAccount != _hasAccountOnDevice) {
        _hasAccountOnDevice = hasAccount;
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
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

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

  /// Applies the language and currency saved on the signed-in account (a
  /// returning member). An account without saved settings gets the current
  /// ones saved instead.
  Future<void> loadFromProfile() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await client
          .schema('nata')
          .from('user_settings')
          .select('language, currency_code')
          .eq('user_id', userId)
          .maybeSingle();
      final lang = row?['language'] as String?;
      final cur = row?['currency_code'] as String?;
      if (lang == null && cur == null) {
        await saveToProfile();
        return;
      }
      if (lang != null) setLanguageCode(lang);
      if (cur != null) setCurrencyCode(cur);
    } catch (e) {
      debugPrint('PreferencesService.loadFromProfile: $e');
    }
  }

  /// Logging out. Language, currency and the country of residence stay, so
  /// the sign-in screen that follows (and the next launch) are in the
  /// member's own language. Face ID is switched off: it signs in to the
  /// account that has just logged out.
  void reset() {
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
    _hasAccountOnDevice = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_countryPrefsKey);
      await prefs.remove(_faceIdPrefsKey);
      await prefs.remove(_languagePrefsKey);
      await prefs.remove(_currencyPrefsKey);
      await prefs.remove(_hasAccountPrefsKey);
    } catch (_) {}
    notifyListeners();
  }
}
