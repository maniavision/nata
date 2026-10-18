import 'package:carrywise_app/services/auth_service.dart';
import 'package:carrywise_app/services/home_search_memory.dart';
import 'package:carrywise_app/widgets/location_search_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

const london = LocationSelection(
  country: 'United Kingdom',
  countryCode: 'GB',
  city: 'London',
  displayLabel: 'London, United Kingdom',
);

void main() {
  group('HomeSearchMemory.dateFrom', () {
    final now = DateTime(2030, 6, 22, 15, 30);

    test('nothing remembered', () {
      expect(HomeSearchMemory.dateFrom(now), isNull);
    });

    test('today and later dates are kept', () {
      HomeSearchMemory.date = DateTime(2030, 6, 22);
      expect(HomeSearchMemory.dateFrom(now), DateTime(2030, 6, 22));

      HomeSearchMemory.date = DateTime(2030, 7, 1);
      expect(HomeSearchMemory.dateFrom(now), DateTime(2030, 7, 1));
    });

    test('a date that has passed is dropped', () {
      HomeSearchMemory.date = DateTime(2030, 6, 21);
      expect(HomeSearchMemory.dateFrom(now), isNull);
    });
  });

  test('clear forgets everything', () {
    HomeSearchMemory.departure = london;
    HomeSearchMemory.destination = london;
    HomeSearchMemory.date = DateTime(2030, 6, 22);
    HomeSearchMemory.flexible = true;

    HomeSearchMemory.clear();

    expect(HomeSearchMemory.departure, isNull);
    expect(HomeSearchMemory.destination, isNull);
    expect(HomeSearchMemory.date, isNull);
    expect(HomeSearchMemory.flexible, isFalse);
  });

  test('signing out forgets the search', () async {
    final client = _Client();
    final auth = _Auth();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.signOut()).thenAnswer((_) async {});
    HomeSearchMemory.destination = london;

    await AuthService(client: client).signOut();

    expect(HomeSearchMemory.destination, isNull);
  });
}
