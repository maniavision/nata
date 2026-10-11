import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/region_service.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/fakes.dart';

void main() {
  group('language for a country', () {
    AppLanguage of(String iso) => RegionService.languageForCountry(iso);

    test('English by default', () {
      for (final iso in ['US', 'GB', 'NG', 'GH', 'KE', 'ZA', 'CA', 'AU', 'IN', 'DE', 'JP']) {
        expect(of(iso), AppLanguage.english, reason: iso);
      }
    });

    test('Spanish where Spanish is the usual language', () {
      for (final iso in ['ES', 'MX', 'AR', 'CO', 'CL', 'PE', 'VE', 'CU', 'PR']) {
        expect(of(iso), AppLanguage.spanish, reason: iso);
      }
    });

    test('French where French is the usual language', () {
      for (final iso in ['FR', 'SN', 'CI', 'CM', 'CD', 'BF', 'ML', 'BJ', 'TG', 'HT']) {
        expect(of(iso), AppLanguage.french, reason: iso);
      }
    });

    test('is not case sensitive and ignores spaces', () {
      expect(of('fr'), AppLanguage.french);
      expect(of(' mx '), AppLanguage.spanish);
    });

    test('an unknown code falls back to English', () {
      expect(of('ZZ'), AppLanguage.english);
      expect(of(''), AppLanguage.english);
    });
  });

  group('currency for a country', () {
    AppCurrency of(String iso) => RegionService.currencyForCountry(iso);

    test('USD for the USA', () => expect(of('US'), AppCurrency.usd));

    test('GBP for the United Kingdom', () => expect(of('GB'), AppCurrency.gbp));

    test('EUR across the eurozone', () {
      for (final iso in ['FR', 'DE', 'ES', 'IT', 'NL', 'BE', 'PT', 'IE', 'AT', 'GR', 'FI']) {
        expect(of(iso), AppCurrency.eur, reason: iso);
      }
    });

    test('CFA franc (XOF) in West Africa', () {
      for (final iso in ['SN', 'CI', 'BF', 'ML', 'NE', 'TG', 'BJ', 'GW']) {
        expect(of(iso), AppCurrency.xof, reason: iso);
      }
    });

    test('USD for everywhere the app has no local currency', () {
      for (final iso in ['NG', 'GH', 'KE', 'ZA', 'CA', 'MX', 'AU', 'JP', 'ZZ']) {
        expect(of(iso), AppCurrency.usd, reason: iso);
      }
    });

    test('Senegal is French AND uses the CFA franc', () {
      expect(RegionService.languageForCountry('SN'), AppLanguage.french);
      expect(of('SN'), AppCurrency.xof);
    });

    test('is not case sensitive', () {
      expect(of('gb'), AppCurrency.gbp);
      expect(of(' fr '), AppCurrency.eur);
    });
  });

  group('RegionService.detect', () {
    late FakeDeviceLocation device;
    late RegionService service;

    setUp(() {
      device = FakeDeviceLocation();
      service = RegionService(device: device);
    });

    test('finds the country when location is on and allowed', () async {
      final r = await service.detect();

      expect(r, isNotNull);
      expect(r!.isoCode, 'US');
      expect(r.countryName, 'United States');
      expect(r.language, AppLanguage.english);
      expect(r.currency, AppCurrency.usd);
    });

    test('suggests the language and currency of the detected country',
        () async {
      device.found = (isoCode: 'FR', name: 'France');

      final r = await service.detect();

      expect(r!.countryName, 'France');
      expect(r.language, AppLanguage.french);
      expect(r.currency, AppCurrency.eur);
    });

    test('Senegal: French and CFA franc', () async {
      device.found = (isoCode: 'SN', name: 'Senegal');

      final r = await service.detect();

      expect(r!.language, AppLanguage.french);
      expect(r.currency, AppCurrency.xof);
    });

    test('Mexico: Spanish, dollars', () async {
      device.found = (isoCode: 'MX', name: 'Mexico');

      final r = await service.detect();

      expect(r!.language, AppLanguage.spanish);
      expect(r.currency, AppCurrency.usd);
    });

    test('a lower-case code from the phone still works', () async {
      device.found = (isoCode: 'gb', name: 'United Kingdom');

      final r = await service.detect();

      expect(r!.isoCode, 'GB');
      expect(r.currency, AppCurrency.gbp);
    });

    test('uses the name the phone reports for a country the app does not list',
        () async {
      device.found = (isoCode: 'IS', name: 'Iceland');

      final r = await service.detect();

      // Whatever the app's own list says, the user sees a real name.
      expect(r!.countryName, isNotEmpty);
      expect(r.countryName, anyOf('Iceland'));
    });

    test('falls back to the code when no name is known at all', () async {
      device.found = (isoCode: 'ZZ', name: null);

      final r = await service.detect();

      expect(r!.countryName, 'ZZ');
    });

    group('when it cannot detect anything', () {
      test('location switched off: nothing, and the user is not asked',
          () async {
        device.serviceEnabled = false;

        expect(await service.detect(), isNull);
        expect(device.promptCount, 0);
        expect(device.countryLookups, 0);
      });

      test('permission refused when asked: nothing', () async {
        device.currentAccess = LocationAccess.denied;
        device.accessAfterPrompt = LocationAccess.denied;

        expect(await service.detect(), isNull);
        expect(device.promptCount, 1);
        expect(device.countryLookups, 0);
      });

      test('permission refused for good: nothing, and not asked again',
          () async {
        device.currentAccess = LocationAccess.deniedForever;

        expect(await service.detect(), isNull);
        expect(device.promptCount, 0);
        expect(device.countryLookups, 0);
      });

      test('the country cannot be worked out: nothing', () async {
        device.found = null;

        expect(await service.detect(), isNull);
      });

      test('any device error: nothing, and no exception', () async {
        device.error = Exception('location unavailable');

        expect(await service.detect(), isNull);
      });
    });

    group('permission', () {
      test('already allowed: the user is not asked again', () async {
        device.currentAccess = LocationAccess.granted;

        await service.detect();

        expect(device.promptCount, 0);
      });

      test('not decided yet: the user is asked once, then it is detected',
          () async {
        device.currentAccess = LocationAccess.denied;
        device.accessAfterPrompt = LocationAccess.granted;

        final r = await service.detect();

        expect(device.promptCount, 1);
        expect(r?.isoCode, 'US');
      });
    });
  });
}
