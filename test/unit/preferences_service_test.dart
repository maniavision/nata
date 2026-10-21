/// Unit tests for PreferencesService — in-memory language/currency state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Reset singleton state before each test so tests don't bleed into each other.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });

  group('AppLanguage enum', () {
    test('all values have valid locale codes', () {
      for (final lang in AppLanguage.values) {
        expect(lang.code, isNotEmpty);
        expect(lang.locale, isA<Locale>());
        expect(lang.locale.languageCode, lang.code);
      }
    });

    test('fromCode returns correct language', () {
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('es'), AppLanguage.spanish);
      expect(AppLanguage.fromCode('fr'), AppLanguage.french);
    });

    test('fromCode defaults to english for unknown code', () {
      expect(AppLanguage.fromCode('xx'), AppLanguage.english);
      expect(AppLanguage.fromCode(''), AppLanguage.english);
    });

    test('labels are non-empty', () {
      for (final lang in AppLanguage.values) {
        expect(lang.label, isNotEmpty);
      }
    });
  });

  group('AppCurrency enum', () {
    test('all values have valid codes and symbols', () {
      for (final cur in AppCurrency.values) {
        expect(cur.code.length, 3);
        expect(cur.symbol, isNotEmpty);
        expect(cur.label, isNotEmpty);
      }
    });

    test('fromCode returns correct currency', () {
      expect(AppCurrency.fromCode('USD'), AppCurrency.usd);
      expect(AppCurrency.fromCode('EUR'), AppCurrency.eur);
      expect(AppCurrency.fromCode('GBP'), AppCurrency.gbp);
      expect(AppCurrency.fromCode('XOF'), AppCurrency.xof);
    });

    test('fromCode defaults to USD for unknown code', () {
      expect(AppCurrency.fromCode('ZZZ'), AppCurrency.usd);
      expect(AppCurrency.fromCode(''), AppCurrency.usd);
    });
  });

  group('PreferencesService defaults', () {
    test('default language is English', () {
      expect(PreferencesService().language, AppLanguage.english);
    });

    test('default currency is USD', () {
      expect(PreferencesService().currency, AppCurrency.usd);
    });

    test('default country is the USA', () {
      expect(PreferencesService().countryIsoCode, 'US');
      expect(PreferencesService.defaultCountryIso, 'US');
    });

    test('default locale is en', () {
      expect(PreferencesService().locale, const Locale('en'));
    });
  });

  group('PreferencesService setters', () {
    test('setLanguage updates language and locale', () {
      final prefs = PreferencesService();
      prefs.setLanguage(AppLanguage.french);
      expect(prefs.language, AppLanguage.french);
      expect(prefs.locale, const Locale('fr'));
    });

    test('setCurrency updates currency', () {
      final prefs = PreferencesService();
      prefs.setCurrency(AppCurrency.eur);
      expect(prefs.currency, AppCurrency.eur);
    });

    test('setCountry updates country', () {
      final prefs = PreferencesService();
      prefs.setCountry('GB');
      expect(prefs.countryIsoCode, 'GB');
    });

    test('setLanguageCode updates by code string', () {
      final prefs = PreferencesService();
      prefs.setLanguageCode('es');
      expect(prefs.language, AppLanguage.spanish);
    });

    test('setCurrencyCode updates by code string', () {
      final prefs = PreferencesService();
      prefs.setCurrencyCode('GBP');
      expect(prefs.currency, AppCurrency.gbp);
    });
  });

  group('PreferencesService notifications', () {
    test('notifies listeners on language change', () {
      final prefs = PreferencesService();
      int callCount = 0;
      prefs.addListener(() => callCount++);
      prefs.setLanguage(AppLanguage.spanish);
      expect(callCount, 1);
      prefs.removeListener(() {});
    });

    test('does not notify if language unchanged', () {
      final prefs = PreferencesService();
      int callCount = 0;
      void listener() => callCount++;
      prefs.addListener(listener);
      prefs.setLanguage(AppLanguage.english); // already english
      expect(callCount, 0);
      prefs.removeListener(listener);
    });

    test('notifies listeners on currency change', () {
      final prefs = PreferencesService();
      int callCount = 0;
      void listener() => callCount++;
      prefs.addListener(listener);
      prefs.setCurrency(AppCurrency.gbp);
      expect(callCount, 1);
      prefs.removeListener(listener);
    });

    test('notifies listeners on country change', () {
      final prefs = PreferencesService();
      int callCount = 0;
      void listener() => callCount++;
      prefs.addListener(listener);
      prefs.setCountry('FR');
      expect(callCount, 1);
      prefs.removeListener(listener);
    });
  });

  group('PreferencesService reset', () {
    test('logging out keeps language and currency', () {
      final prefs = PreferencesService();
      prefs.setLanguage(AppLanguage.french);
      prefs.setCurrency(AppCurrency.xof);
      prefs.reset();
      expect(prefs.language, AppLanguage.french);
      expect(prefs.currency, AppCurrency.xof);
    });

    test('the device remembers language, currency and the account', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService();
      await prefs.resetAll();
      prefs.setLanguage(AppLanguage.spanish);
      prefs.setCurrency(AppCurrency.eur);
      prefs.rememberAccount();
      await prefs.pendingWrites;

      // A fresh start reads it back.
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString('language'), 'es');
      expect(stored.getString('currency'), 'EUR');
      expect(stored.getBool('has_account'), isTrue);

      await prefs.resetAll();
      SharedPreferences.setMockInitialValues({
        'language': 'fr',
        'currency': 'XOF',
        'has_account': true,
      });
      await prefs.restore();
      expect(prefs.language, AppLanguage.french);
      expect(prefs.currency, AppCurrency.xof);
      expect(prefs.hasAccountOnDevice, isTrue);
      await prefs.resetAll();
    });

    test('deleting the account forgets it on the device', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PreferencesService();
      await prefs.resetAll();
      prefs.rememberAccount();
      prefs.forgetAccount();
      await prefs.pendingWrites;
      expect(prefs.hasAccountOnDevice, isFalse);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getBool('has_account'), isFalse);
    });

    test('reset keeps the country the user registered with', () {
      final prefs = PreferencesService();
      prefs.setCountry('FR');
      prefs.reset(); // logging out

      expect(prefs.countryIsoCode, 'FR');
    });

    test('resetAll goes back to the factory default country', () async {
      final prefs = PreferencesService();
      prefs.setCountry('FR');
      await prefs.pendingWrites;

      await prefs.resetAll();

      expect(prefs.countryIsoCode, 'US');
    });

    test('reset notifies listeners', () {
      final prefs = PreferencesService();
      prefs.setLanguage(AppLanguage.spanish); // change from default
      int callCount = 0;
      void listener() => callCount++;
      prefs.addListener(listener);
      prefs.reset();
      expect(callCount, 1);
      prefs.removeListener(listener);
    });
  });

  group('country of residence is remembered on the device', () {
    const key = 'registered_country_iso';

    Future<String?> stored() async =>
        (await SharedPreferences.getInstance()).getString(key);

    test('setCountry writes it to the device', () async {
      PreferencesService().setCountry('GH');
      await PreferencesService().pendingWrites;

      expect(await stored(), 'GH');
    });

    test('it is stored in upper case', () async {
      PreferencesService().setCountry('gh');
      await PreferencesService().pendingWrites;

      expect(PreferencesService().countryIsoCode, 'GH');
      expect(await stored(), 'GH');
    });

    test('a changed country replaces the stored one', () async {
      PreferencesService().setCountry('GH');
      await PreferencesService().pendingWrites;
      PreferencesService().setCountry('GB');
      await PreferencesService().pendingWrites;

      expect(await stored(), 'GB');
    });

    test('anything that is not a 2-letter code is ignored', () async {
      PreferencesService().setCountry('GH');
      await PreferencesService().pendingWrites;

      PreferencesService().setCountry('');
      PreferencesService().setCountry('G');
      PreferencesService().setCountry('GHA');
      PreferencesService().setCountry('  ');

      expect(PreferencesService().countryIsoCode, 'GH');
      expect(await stored(), 'GH');
    });

    test('setCountry notifies listeners', () {
      var calls = 0;
      void listener() => calls++;
      PreferencesService().addListener(listener);

      PreferencesService().setCountry('GH');

      expect(calls, 1);
      PreferencesService().removeListener(listener);
    });

    test('setting the same country again does nothing', () {
      PreferencesService().setCountry('GH');
      var calls = 0;
      void listener() => calls++;
      PreferencesService().addListener(listener);

      PreferencesService().setCountry('gh');

      expect(calls, 0);
      PreferencesService().removeListener(listener);
    });

    test('restore brings it back after the app restarts', () async {
      // A previous run stored GB; the app starts fresh on the default.
      SharedPreferences.setMockInitialValues({key: 'GB'});
      expect(PreferencesService().countryIsoCode, 'US');

      await PreferencesService().restore();

      expect(PreferencesService().countryIsoCode, 'GB');
    });

    test('restore notifies listeners when it changes something', () async {
      SharedPreferences.setMockInitialValues({key: 'GB'});
      var calls = 0;
      void listener() => calls++;
      PreferencesService().addListener(listener);

      await PreferencesService().restore();

      expect(calls, 1);
      PreferencesService().removeListener(listener);
    });

    test('restore with nothing stored keeps the default', () async {
      SharedPreferences.setMockInitialValues({});

      await PreferencesService().restore();

      expect(PreferencesService().countryIsoCode, 'US');
    });

    test('restore ignores a corrupt stored value', () async {
      SharedPreferences.setMockInitialValues({key: 'NOT-A-CODE'});

      await PreferencesService().restore();

      expect(PreferencesService().countryIsoCode, 'US');
    });

    test('restore reads a lower-case stored value', () async {
      SharedPreferences.setMockInitialValues({key: 'gb'});

      await PreferencesService().restore();

      expect(PreferencesService().countryIsoCode, 'GB');
    });

    test('register, log out, restart: the country is still there', () async {
      final prefs = PreferencesService();
      prefs.setCountry('GH'); // registers in Ghana
      await prefs.pendingWrites;
      prefs.reset(); // logs out
      expect(prefs.countryIsoCode, 'GH');

      // The app is closed and opened again: memory is empty, the device is not.
      final storedValue = await stored();
      SharedPreferences.setMockInitialValues({key: storedValue!});
      await prefs.resetAll();
      SharedPreferences.setMockInitialValues({key: storedValue});
      await prefs.restore();

      expect(prefs.countryIsoCode, 'GH');
    });
  });

  group('Face ID setting', () {
    const key = 'face_id_enabled';

    Future<bool?> stored() async =>
        (await SharedPreferences.getInstance()).getBool(key);

    test('is off by default', () {
      expect(PreferencesService().faceIdEnabled, isFalse);
    });

    test('can be switched on and is written to the device', () async {
      PreferencesService().setFaceIdEnabled(true);
      await PreferencesService().pendingWrites;

      expect(PreferencesService().faceIdEnabled, isTrue);
      expect(await stored(), isTrue);
    });

    test('can be switched off again', () async {
      PreferencesService().setFaceIdEnabled(true);
      PreferencesService().setFaceIdEnabled(false);
      await PreferencesService().pendingWrites;

      expect(PreferencesService().faceIdEnabled, isFalse);
      expect(await stored(), isFalse);
    });

    test('notifies listeners only when it changes', () {
      var calls = 0;
      void listener() => calls++;
      PreferencesService().addListener(listener);

      PreferencesService().setFaceIdEnabled(true);
      PreferencesService().setFaceIdEnabled(true);

      expect(calls, 1);
      PreferencesService().removeListener(listener);
    });

    test('is restored after the app restarts', () async {
      SharedPreferences.setMockInitialValues({key: true});
      expect(PreferencesService().faceIdEnabled, isFalse);

      await PreferencesService().restore();

      expect(PreferencesService().faceIdEnabled, isTrue);
    });

    test('logging out switches it off, also on the device', () async {
      PreferencesService().setFaceIdEnabled(true);
      await PreferencesService().pendingWrites;

      PreferencesService().reset(); // log out
      await PreferencesService().pendingWrites;

      expect(PreferencesService().faceIdEnabled, isFalse);
      expect(await stored(), isFalse);
    });

    test('logging out does not forget the registered country', () async {
      PreferencesService().setCountry('GH');
      PreferencesService().setFaceIdEnabled(true);

      PreferencesService().reset();

      expect(PreferencesService().countryIsoCode, 'GH');
    });

    test('quick successive changes are all written, in order', () async {
      PreferencesService().setCountry('GB');
      PreferencesService().setFaceIdEnabled(true);
      PreferencesService().setCountry('FR');
      await PreferencesService().pendingWrites;

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('registered_country_iso'), 'FR');
      expect(prefs.getBool(key), isTrue);
    });

    test('the last change wins even when saves overlap', () async {
      final prefs = PreferencesService();
      // Not awaited in between: all of these saves are in flight together.
      prefs.setCountry('GB');
      prefs.setFaceIdEnabled(true);
      prefs.setCountry('FR');
      prefs.setFaceIdEnabled(false);
      prefs.setCountry('DE');
      await prefs.pendingWrites;
      // Let every save finish, whichever order they complete in.
      await Future<void>.delayed(Duration.zero);

      final stored = await SharedPreferences.getInstance();
      expect(stored.getString('registered_country_iso'), 'DE');
      expect(stored.getBool(key), isFalse);
    });

    test('a save never waits on an earlier one that did not finish', () async {
      final prefs = PreferencesService();
      prefs.setCountry('GB'); // left running

      prefs.setFaceIdEnabled(true);
      await prefs.pendingWrites.timeout(const Duration(seconds: 5));

      expect((await SharedPreferences.getInstance()).getBool(key), isTrue);
    });

    test('resetAll clears it', () async {
      PreferencesService().setFaceIdEnabled(true);
      await PreferencesService().pendingWrites;

      await PreferencesService().resetAll();

      expect(PreferencesService().faceIdEnabled, isFalse);
      expect(await stored(), isNull);
    });
  });

  group('PreferencesService is a singleton', () {
    test('two instances are the same object', () {
      final a = PreferencesService();
      final b = PreferencesService();
      expect(identical(a, b), isTrue);
    });

    test('state is shared across instances', () {
      PreferencesService().setLanguage(AppLanguage.french);
      expect(PreferencesService().language, AppLanguage.french);
    });
  });
}
