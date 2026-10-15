/// Unit tests for LocationSearchService models and helpers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/location_search_service.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';

void main() {
  group('CountryResult', () {
    test('fromJson parses correctly', () {
      final c = CountryResult.fromJson({
        'iso_code': 'NG',
        'name': 'Nigeria',
        'phone_code': '+234',
      });
      expect(c.isoCode, 'NG');
      expect(c.name, 'Nigeria');
      expect(c.phoneCode, '+234');
      expect(c.displayName, 'Nigeria');
    });

    test('fromJson trims whitespace', () {
      final c = CountryResult.fromJson({
        'iso_code': ' GB ',
        'name': ' United Kingdom ',
        'phone_code': ' +44 ',
      });
      expect(c.isoCode, 'GB');
      expect(c.name, 'United Kingdom');
    });

    test('fromJson handles missing fields', () {
      final c = CountryResult.fromJson({});
      expect(c.isoCode, '');
      expect(c.name, '');
    });

    test('toString returns name', () {
      const c = CountryResult(
        isoCode: 'NG',
        name: 'Nigeria',
        phoneCode: '+234',
      );
      expect(c.toString(), 'Nigeria');
    });
  });

  group('CityResult', () {
    test('fromJson parses with nested country', () {
      final c = CityResult.fromJson({
        'id': 42,
        'name': 'Lagos',
        'country_code': 'NG',
        'countries': {'name': 'Nigeria'},
      });
      expect(c.id, 42);
      expect(c.name, 'Lagos');
      expect(c.countryCode, 'NG');
      expect(c.countryName, 'Nigeria');
      expect(c.displayName, 'Lagos, Nigeria');
    });

    test('fromJson handles missing country', () {
      final c = CityResult.fromJson({
        'id': 1,
        'name': 'London',
        'country_code': 'GB',
      });
      expect(c.countryName, '');
      expect(c.displayName, 'London, ');
    });

    test('displayName format is city comma country', () {
      final c = CityResult.fromJson({
        'id': 10,
        'name': 'Paris',
        'country_code': 'FR',
        'countries': {'name': 'France'},
      });
      expect(c.displayName, 'Paris, France');
    });
  });

  group('LocationSelection', () {
    test('holds all fields', () {
      const sel = LocationSelection(
        country: 'Nigeria',
        countryCode: 'NG',
        city: 'Lagos',
        displayLabel: 'Lagos, Nigeria',
      );
      expect(sel.country, 'Nigeria');
      expect(sel.countryCode, 'NG');
      expect(sel.city, 'Lagos');
      expect(sel.displayLabel, 'Lagos, Nigeria');
    });
  });

  group('LocationSearchService.sortByName', () {
    test('countries come A to Z, whatever order the server sent', () {
      final sorted = LocationSearchService.sortByName(
        const [
          CountryResult(isoCode: 'ZW', name: 'Zimbabwe', phoneCode: '+263'),
          CountryResult(isoCode: 'ZM', name: 'Zambia', phoneCode: '+260'),
          CountryResult(isoCode: 'AF', name: 'Afghanistan', phoneCode: '+93'),
          CountryResult(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234'),
        ],
        (c) => c.name,
      );
      expect(sorted.map((c) => c.name), [
        'Afghanistan',
        'Nigeria',
        'Zambia',
        'Zimbabwe',
      ]);
    });

    test('ignores case', () {
      final sorted = LocationSearchService.sortByName(
        ['lagos', 'Abuja', 'kano', 'Ibadan'],
        (s) => s,
      );
      expect(sorted, ['Abuja', 'Ibadan', 'kano', 'lagos']);
    });
  });
}
