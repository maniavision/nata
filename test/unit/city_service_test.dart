import 'dart:async';

import 'package:carrywise_app/services/city_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockQuerySchema extends Mock implements SupabaseQuerySchema {}

class MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakeQuery extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  FakeQuery(this.row, {this.error});
  final Map<String, dynamic>? row;
  final Object? error;
  final List<String> calls = [];

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) {
    calls.add('eq:$column=$value');
    return this;
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    calls.add('maybeSingle');
    return _Single(row, error);
  }
}

class _Single extends Fake implements PostgrestTransformBuilder<PostgrestMap?> {
  _Single(this.row, this.error);
  final Map<String, dynamic>? row;
  final Object? error;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) {
    final f = error != null
        ? Future<PostgrestMap?>.error(error!)
        : Future<PostgrestMap?>.value(row);
    return f.then(onValue, onError: onError);
  }
}

void main() {
  late MockSupabaseClient client;
  late MockQuerySchema schema;
  late MockQueryBuilder cities;
  late CityService service;
  var lookups = 0;

  setUp(() {
    client = MockSupabaseClient();
    schema = MockQuerySchema();
    cities = MockQueryBuilder();
    lookups = 0;
    when(() => client.schema('nata')).thenReturn(schema);
    when(() => schema.from('cities')).thenAnswer((_) => cities);
    service = CityService(client: client);
  });

  void answer(Map<String, dynamic>? row, {Object? error}) {
    when(() => cities.select(any())).thenAnswer((_) {
      lookups++;
      return FakeQuery(row, error: error);
    });
  }

  test('finds a city by country code and name', () async {
    answer({'latitude': 6.5244, 'longitude': 3.3792});

    final c = await service.coordinates('NG', 'Lagos');

    expect(c?.latitude, 6.5244);
    expect(c?.longitude, 3.3792);
  });

  test('asks only for the coordinates, filtered by country and name', () async {
    final q = FakeQuery({'latitude': 1, 'longitude': 2});
    when(() => cities.select(any())).thenAnswer((_) => q);

    await service.coordinates('ng', '  Lagos ');

    expect(q.calls, ['eq:country_code=NG', 'eq:name=Lagos', 'maybeSingle']);
    expect(
      verify(() => cities.select(captureAny())).captured.single,
      'latitude, longitude',
    );
  });

  test('numeric columns that arrive as text still work', () async {
    answer({'latitude': '6.524400', 'longitude': '-0.127800'});

    final c = await service.coordinates('NG', 'Lagos');

    expect(c?.latitude, 6.5244);
    expect(c?.longitude, -0.1278);
  });

  test('integers work too', () async {
    answer({'latitude': 6, 'longitude': 3});

    expect((await service.coordinates('NG', 'Lagos'))?.latitude, 6.0);
  });

  test('an unknown city is null', () async {
    answer(null);

    expect(await service.coordinates('NG', 'Nowhere'), isNull);
  });

  test('unusable coordinates are null', () async {
    answer({'latitude': null, 'longitude': 3});

    expect(await service.coordinates('NG', 'Lagos'), isNull);
  });

  test(
    'a database failure is passed on, so the screen can offer a retry',
    () async {
      answer(null, error: Exception('network'));

      expect(service.coordinates('NG', 'Lagos'), throwsException);
    },
  );

  test('the same city is only looked up once', () async {
    answer({'latitude': 6.5, 'longitude': 3.4});

    await service.coordinates('NG', 'Lagos');
    await service.coordinates('NG', 'Lagos');
    await service.coordinates('ng', 'lagos ');

    expect(lookups, 1);
  });

  test('different cities are looked up separately', () async {
    answer({'latitude': 6.5, 'longitude': 3.4});

    await service.coordinates('NG', 'Lagos');
    await service.coordinates('GB', 'London');

    expect(lookups, 2);
  });

  test('a failed lookup is not remembered', () async {
    answer(null, error: Exception('network'));
    await expectLater(service.coordinates('NG', 'Lagos'), throwsException);

    answer({'latitude': 6.5, 'longitude': 3.4});

    expect((await service.coordinates('NG', 'Lagos'))?.latitude, 6.5);
  });
}
