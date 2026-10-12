import 'dart:convert';

import 'package:carrywise_app/services/exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The shape of the real answer from https://open.er-api.com/v6/latest/USD
Map<String, dynamic> apiBody({
  String result = 'success',
  Map<String, Object?>? rates,
  Object? last = 1791676951,
  Object? next = 1791764701,
}) => {
  'result': result,
  'provider': 'https://www.exchangerate-api.com',
  'time_last_update_unix': last,
  'time_next_update_unix': next,
  'base_code': 'USD',
  'rates':
      rates ??
      {
        'USD': 1,
        'EUR': 0.892438,
        'GBP': 0.755923,
        'XOF': 585.399478,
        'XAF': 585.399478,
      },
};

http.Response ok(Map<String, dynamic> b) => http.Response(jsonEncode(b), 200);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ExchangeRates.fromApi', () {
    test('reads the rates and the update times', () {
      final r = ExchangeRates.fromApi(apiBody())!;

      expect(r.perUsd['EUR'], 0.892438);
      expect(r.perUsd['GBP'], 0.755923);
      expect(
        r.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1791676951000, isUtc: true),
      );
      expect(
        r.nextUpdateAt,
        DateTime.fromMillisecondsSinceEpoch(1791764701000, isUtc: true),
      );
    });

    test('integers and decimals both work', () {
      final r = ExchangeRates.fromApi(apiBody(rates: {'USD': 1, 'EUR': 0.9}))!;

      expect(r.perUsd['USD'], 1.0);
      expect(r.perUsd['EUR'], 0.9);
    });

    test('is refused unless the answer says success', () {
      expect(ExchangeRates.fromApi(apiBody(result: 'error')), isNull);
    });

    test('is refused without rates', () {
      expect(ExchangeRates.fromApi({'result': 'success'}), isNull);
      expect(ExchangeRates.fromApi(apiBody(rates: {})), isNull);
    });

    test('bad entries are skipped, good ones kept', () {
      final r = ExchangeRates.fromApi(
        apiBody(
          rates: {'EUR': 0.9, 'XYZ': 'n/a', 'ABC': null, 'NEG': -1, 'ZERO': 0},
        ),
      )!;

      expect(r.perUsd.keys, ['EUR']);
    });

    test('currency codes are upper-cased', () {
      final r = ExchangeRates.fromApi(apiBody(rates: {'eur': 0.9}))!;

      expect(r.perUsd['EUR'], 0.9);
    });

    test('a missing update time is tolerated', () {
      final r = ExchangeRates.fromApi(apiBody(last: null, next: null))!;

      expect(r.nextUpdateAt, isNull);
      expect(r.updatedAt, isNotNull);
    });
  });

  group('ExchangeRates.rateFor', () {
    final r = ExchangeRates.fromApi(apiBody())!;

    test('USD is always 1', () {
      expect(r.rateFor('USD'), 1);
      expect(
        ExchangeRates(
          perUsd: const {},
          updatedAt: DateTime.now(),
        ).rateFor('USD'),
        1,
      );
    });

    test('EUR and GBP are read by their code', () {
      expect(r.rateFor('EUR'), 0.892438);
      expect(r.rateFor('GBP'), 0.755923);
    });

    test('the code is not case sensitive', () {
      expect(r.rateFor('eur'), 0.892438);
      expect(r.rateFor(' gbp '), 0.755923);
    });

    test('the CFA franc (XOF)', () => expect(r.rateFor('XOF'), 585.399478));

    test('the CFA franc under its other code (XAF)', () {
      expect(r.rateFor('XAF'), 585.399478);
    });

    test('XOF falls back to XAF when only XAF is listed, and back again', () {
      final onlyXaf = ExchangeRates(
        perUsd: const {'XAF': 600},
        updatedAt: DateTime.now(),
      );
      final onlyXof = ExchangeRates(
        perUsd: const {'XOF': 610},
        updatedAt: DateTime.now(),
      );

      expect(onlyXaf.rateFor('XOF'), 600);
      expect(onlyXof.rateFor('XAF'), 610);
    });

    test('an unknown currency has no rate', () {
      expect(r.rateFor('ZZZ'), isNull);
      expect(r.rateFor(''), isNull);
    });
  });

  group('ExchangeRates saved on the device', () {
    test('survive a round trip', () {
      final r = ExchangeRates.fromApi(apiBody())!;

      final back = ExchangeRates.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      )!;

      expect(back.perUsd, r.perUsd);
      expect(back.updatedAt, r.updatedAt);
      expect(back.nextUpdateAt, r.nextUpdateAt);
    });

    test('damaged data is refused', () {
      expect(ExchangeRates.fromJson({}), isNull);
      expect(ExchangeRates.fromJson({'rates': {}, 'updated': 1}), isNull);
      expect(
        ExchangeRates.fromJson({
          'rates': {'EUR': 1},
          'updated': 'x',
        }),
        isNull,
      );
    });
  });

  group('ExchangeRateService', () {
    // 2026-10-11 12:00 UTC; the sample answer says the next update is later
    // that day (1791764701 = 2026-10-11 23:25 UTC).
    var clock = DateTime.utc(2026, 10, 11, 12);
    DateTime now() => clock;

    setUp(() => clock = DateTime.utc(2026, 10, 11, 12));

    test('asks the right address', () async {
      Uri? asked;
      final service = ExchangeRateService(
        client: MockClient((req) async {
          asked = req.url;
          return ok(apiBody());
        }),
        now: now,
      );

      await service.rates();

      expect(asked.toString(), 'https://open.er-api.com/v6/latest/USD');
    });

    test('returns the rates it was given', () async {
      final service = ExchangeRateService(
        client: MockClient((_) async => ok(apiBody())),
        now: now,
      );

      final r = await service.rates();

      expect(r?.rateFor('EUR'), 0.892438);
      expect(r?.rateFor('XOF'), 585.399478);
    });

    test('reuses the answer until the provider says it will update', () async {
      var calls = 0;
      final service = ExchangeRateService(
        client: MockClient((_) async {
          calls++;
          return ok(apiBody());
        }),
        now: now,
      );

      await service.rates();
      await service.rates();
      clock = DateTime.utc(2026, 10, 11, 20);
      await service.rates();

      expect(calls, 1);
    });

    test('asks again once the update time has passed', () async {
      var calls = 0;
      final service = ExchangeRateService(
        client: MockClient((_) async {
          calls++;
          return ok(apiBody());
        }),
        now: now,
      );
      await service.rates();

      clock = DateTime.utc(2026, 10, 12, 0, 30); // after 23:25 the day before
      await service.rates();

      expect(calls, 2);
    });

    test('without an update time, reuses it for six hours', () async {
      var calls = 0;
      final service = ExchangeRateService(
        client: MockClient((_) async {
          calls++;
          return ok(apiBody(next: null));
        }),
        now: now,
      );
      await service.rates();

      clock = clock.add(const Duration(hours: 5, minutes: 59));
      await service.rates();
      expect(calls, 1);

      clock = clock.add(const Duration(minutes: 2));
      await service.rates();
      expect(calls, 2);
    });

    test('callers at the same moment share one request', () async {
      var calls = 0;
      final service = ExchangeRateService(
        client: MockClient((_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return ok(apiBody());
        }),
        now: now,
      );

      final results = await Future.wait([
        service.rates(),
        service.rates(),
        service.rates(),
      ]);

      expect(calls, 1);
      expect(results.every((r) => r != null), isTrue);
    });

    test('keeps the rates on the device', () async {
      final service = ExchangeRateService(
        client: MockClient((_) async => ok(apiBody())),
        now: now,
      );

      await service.rates();

      final stored = (await SharedPreferences.getInstance()).getString(
        'exchange_rates_usd',
      );
      expect(stored, isNotNull);
      expect(jsonDecode(stored!)['rates']['GBP'], 0.755923);
    });

    group('when the network fails', () {
      test('offline and never fetched: null, no crash', () async {
        final service = ExchangeRateService(
          client: MockClient(
            (_) async => throw http.ClientException('offline'),
          ),
          now: now,
        );

        expect(await service.rates(), isNull);
      });

      test('offline: the last saved rates are used', () async {
        // An earlier run saved rates.
        final saved = ExchangeRates.fromApi(apiBody())!;
        SharedPreferences.setMockInitialValues({
          'exchange_rates_usd': jsonEncode(saved.toJson()),
        });
        final service = ExchangeRateService(
          client: MockClient(
            (_) async => throw http.ClientException('offline'),
          ),
          now: now,
        );

        final r = await service.rates();

        expect(r?.rateFor('EUR'), 0.892438);
      });

      test(
        'expired saved rates: the next call tries the network again',
        () async {
          clock = DateTime.utc(2026, 10, 13); // past the saved "next update"
          final saved = ExchangeRates.fromApi(apiBody())!;
          SharedPreferences.setMockInitialValues({
            'exchange_rates_usd': jsonEncode(saved.toJson()),
          });
          var online = false;
          var calls = 0;
          final service = ExchangeRateService(
            client: MockClient((_) async {
              calls++;
              if (!online) throw http.ClientException('offline');
              return ok(apiBody(rates: {'USD': 1, 'EUR': 0.5}));
            }),
            now: now,
          );

          expect(
            (await service.rates())?.rateFor('EUR'),
            0.892438,
          ); // saved, old
          online = true;
          expect((await service.rates())?.rateFor('EUR'), 0.5); // fresh
          expect(calls, 2);
        },
      );

      test('saved rates that are still current are not replaced', () async {
        final saved = ExchangeRates.fromApi(apiBody())!;
        SharedPreferences.setMockInitialValues({
          'exchange_rates_usd': jsonEncode(saved.toJson()),
        });
        var calls = 0;
        final service = ExchangeRateService(
          client: MockClient((_) async {
            calls++;
            if (calls == 1) throw http.ClientException('offline');
            return ok(apiBody(rates: {'USD': 1, 'EUR': 0.5}));
          }),
          now: now,
        );

        await service.rates(); // offline -> saved rates
        final again = await service.rates(); // still current -> no new request

        expect(again?.rateFor('EUR'), 0.892438);
        expect(calls, 1);
      });

      test('a server error uses the saved rates', () async {
        final saved = ExchangeRates.fromApi(apiBody())!;
        SharedPreferences.setMockInitialValues({
          'exchange_rates_usd': jsonEncode(saved.toJson()),
        });
        final service = ExchangeRateService(
          client: MockClient((_) async => http.Response('oops', 500)),
          now: now,
        );

        expect((await service.rates())?.rateFor('GBP'), 0.755923);
      });

      test('an answer that says "error" is not trusted', () async {
        final service = ExchangeRateService(
          client: MockClient((_) async => ok(apiBody(result: 'error'))),
          now: now,
        );

        expect(await service.rates(), isNull);
      });

      test('an answer that is not JSON is not trusted', () async {
        final service = ExchangeRateService(
          client: MockClient((_) async => http.Response('<html>', 200)),
          now: now,
        );

        expect(await service.rates(), isNull);
      });

      test('a slow server is given up on', () async {
        final service = ExchangeRateService(
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(seconds: 2));
            return ok(apiBody());
          }),
          now: now,
          timeout: const Duration(milliseconds: 50),
        );

        expect(await service.rates(), isNull);
      });

      test('a failure does not block a later success', () async {
        var online = false;
        final service = ExchangeRateService(
          client: MockClient((_) async {
            if (!online) throw http.ClientException('offline');
            return ok(apiBody());
          }),
          now: now,
        );
        expect(await service.rates(), isNull);

        online = true;

        expect((await service.rates())?.rateFor('EUR'), 0.892438);
      });
    });
  });
}
