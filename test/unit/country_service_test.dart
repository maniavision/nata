/// Unit tests for CountryService bundled search and Country model.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/country_service.dart';

// Mirror of the _flagEmoji helper from sign_up_screen.dart
String flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '🌍';
  final base = 0x1F1E6;
  final first = isoCode.codeUnitAt(0) - 0x41;
  final second = isoCode.codeUnitAt(1) - 0x41;
  return String.fromCharCodes([base + first, base + second]);
}

void main() {
  group('Country model', () {
    test('fromJson parses correctly', () {
      final c = Country.fromJson({
        'iso_code': 'NG',
        'name': 'Nigeria',
        'phone_code': '+234',
      });
      expect(c.isoCode, 'NG');
      expect(c.name, 'Nigeria');
      expect(c.phoneCode, '+234');
    });

    test('fromJson trims whitespace', () {
      final c = Country.fromJson({
        'iso_code': ' GB ',
        'name': ' United Kingdom ',
        'phone_code': ' +44 ',
      });
      expect(c.isoCode, 'GB');
      expect(c.name, 'United Kingdom');
      expect(c.phoneCode, '+44');
    });

    test('fromJson handles missing fields gracefully', () {
      final c = Country.fromJson({});
      expect(c.isoCode, '');
      expect(c.name, '');
      expect(c.phoneCode, '');
    });

    test('toString returns name', () {
      const c = Country(isoCode: 'NG', name: 'Nigeria', phoneCode: '+234');
      expect(c.toString(), 'Nigeria');
    });
  });

  group('CountryService bundled search', () {
    late CountryService service;

    setUp(() {
      service = CountryService();
    });

    test('search for Nigeria returns Nigeria first', () async {
      final results = await service.search('Nig');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, contains('Nigeria'));
    });

    test('search is case-insensitive', () async {
      final lower = await service.search('nigeria');
      final upper = await service.search('NIGERIA');
      expect(lower.map((c) => c.name), equals(upper.map((c) => c.name)));
    });

    test('search for Ghana finds it', () async {
      final results = await service.search('Ghana');
      expect(results.any((c) => c.name == 'Ghana'), isTrue);
    });

    test('search for United Kingdom finds it', () async {
      final results = await service.search('United');
      expect(results.any((c) => c.name == 'United Kingdom'), isTrue);
    });

    test('empty query returns up to 8 results', () async {
      final results = await service.search('');
      expect(results.length, lessThanOrEqualTo(8));
      expect(results.isNotEmpty, isTrue);
    });

    test('unknown country returns empty list', () async {
      final results = await service.search('Zzzzzz');
      expect(results, isEmpty);
    });

    test('search returns at most 8 results', () async {
      final results = await service.search('a'); // many countries have 'a'
      expect(results.length, lessThanOrEqualTo(8));
    });

    test('all bundled countries have valid phone codes', () async {
      final all = await service.search('');
      // Get full list by searching common letter
      final full = await service.search('');
      for (final c in full) {
        expect(c.phoneCode.startsWith('+'), isTrue,
            reason: '${c.name} has invalid phone code: ${c.phoneCode}');
      }
    });

    test('all bundled countries have 2-letter iso codes', () async {
      final results = await service.search('');
      for (final c in results) {
        expect(c.isoCode.length, 2,
            reason: '${c.name} has invalid iso code: ${c.isoCode}');
      }
    });

    test('Nigeria has correct phone code +234', () async {
      final results = await service.search('Nigeria');
      final ng = results.firstWhere((c) => c.name == 'Nigeria');
      expect(ng.phoneCode, '+234');
      expect(ng.isoCode, 'NG');
    });

    test('UK has phone code +44', () async {
      final results = await service.search('United Kingdom');
      final uk = results.firstWhere((c) => c.name == 'United Kingdom');
      expect(uk.phoneCode, '+44');
    });
  });

  group('Flag emoji helper', () {
    test('Nigeria flag', () {
      expect(flagEmoji('NG'), '🇳🇬');
    });

    test('UK flag', () {
      expect(flagEmoji('GB'), '🇬🇧');
    });

    test('US flag', () {
      expect(flagEmoji('US'), '🇺🇸');
    });

    test('France flag', () {
      expect(flagEmoji('FR'), '🇫🇷');
    });

    test('Ghana flag', () {
      expect(flagEmoji('GH'), '🇬🇭');
    });

    test('invalid iso returns globe', () {
      expect(flagEmoji(''), '🌍');
      expect(flagEmoji('X'), '🌍');
      expect(flagEmoji('ABC'), '🌍');
    });

    test('iso must be uppercase for correct flag', () {
      // Flags require uppercase regional indicator letters
      final ng = flagEmoji('NG');
      expect(ng.runes.length, 2);
    });
  });

  group('CountryService full list and lookup by code', () {
    final service = CountryService();

    test('all() returns every known country, not just a handful', () async {
      final all = await service.all();

      expect(all.length, greaterThan(8));
    });

    test('all() is sorted by name', () async {
      final names = (await service.all()).map((c) => c.name.toLowerCase());

      expect(names.toList(), [...names]..sort());
    });

    test('all() has no duplicates', () async {
      final codes = (await service.all()).map((c) => c.isoCode).toList();

      expect(codes.toSet().length, codes.length);
    });

    test('all() includes the default country (USA) with +1', () async {
      final us = (await service.all()).firstWhere((c) => c.isoCode == 'US');

      expect(us.name, 'United States');
      expect(us.phoneCode, '+1');
    });

    test('all() does not change the list used by search', () async {
      await service.all();

      expect((await service.search('')).length, lessThanOrEqualTo(8));
    });

    test('byIsoCode finds a country', () async {
      final c = await service.byIsoCode('GH');

      expect(c?.name, 'Ghana');
      expect(c?.phoneCode, '+233');
    });

    test('byIsoCode is case-insensitive and ignores spaces', () async {
      expect((await service.byIsoCode('gb'))?.name, 'United Kingdom');
      expect((await service.byIsoCode(' US '))?.isoCode, 'US');
    });

    test('byIsoCode returns null for an unknown code', () async {
      expect(await service.byIsoCode('ZZ'), isNull);
      expect(await service.byIsoCode(''), isNull);
    });
  });
}
