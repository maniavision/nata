import 'dart:async';

import 'package:carrywise_app/services/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockClient extends Mock implements SupabaseClient {}

class FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeRpc(this.value, {this.error});
  final Object? value;
  final Object? error;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(dynamic value) onValue, {
    Function? onError,
  }) {
    final f = error != null
        ? Future<dynamic>.error(error!)
        : Future<dynamic>.value(value);
    return f.then(onValue, onError: onError);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppVersion', () {
    AppVersion v(String s) => AppVersion.tryParse(s)!;

    test('reads major.minor.patch', () {
      expect(v('1.2.3').parts, [1, 2, 3]);
    });

    test('missing parts are zero', () {
      expect(v('1.2'), v('1.2.0'));
      expect(v('2'), v('2.0.0'));
    });

    test('the build number and a suffix are ignored', () {
      expect(v('1.2.3+45'), v('1.2.3'));
      expect(v('1.2.3-beta.1'), v('1.2.3'));
    });

    test('compares numbers, not text', () {
      expect(v('1.10.0') > v('1.9.0'), isTrue);
      expect(v('1.0.10') > v('1.0.9'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('1.0.0') < v('1.0.1'), isTrue);
    });

    test('equal versions are neither bigger nor smaller', () {
      expect(v('1.2.3') > v('1.2.3'), isFalse);
      expect(v('1.2.3') < v('1.2.3'), isFalse);
      expect(v('1.2.3').hashCode, v('1.2.3+9').hashCode);
    });

    test('is printed without the build number', () {
      expect(v('1.2+7').toString(), '1.2.0');
    });

    test('rubbish is not a version', () {
      for (final bad in ['', 'abc', '1.2.3.4', '1..2', 'v1.0.0', '-1.0']) {
        expect(AppVersion.tryParse(bad), isNull, reason: bad);
      }
      expect(AppVersion.tryParse(null), isNull);
    });
  });

  group('AppUpdateService.check', () {
    late MockClient client;
    var now = DateTime(2030, 6, 1, 12);

    AppUpdateService service({
      String version = '1.0.0',
      String package = 'com.carrywise.carrywise_app',
      TargetPlatform platform = TargetPlatform.android,
    }) => AppUpdateService(
      client: client,
      appInfo: () async => (version: version, packageName: package),
      platform: platform,
      now: () => now,
    );

    void answer(Object? value, {Object? error, String platform = 'android'}) {
      when(
        () => client.rpc<dynamic>(
          'get_app_version',
          params: {'p_platform': platform},
        ),
      ).thenAnswer((_) => FakeRpc(value, error: error));
    }

    Map<String, dynamic> row({
      String latest = '1.1.0',
      String min = '1.0.0',
      String? url,
      String? notes,
    }) => {
      'latest_version': latest,
      'min_supported_version': min,
      'store_url': url,
      'release_notes': notes,
    };

    setUp(() {
      client = MockClient();
      now = DateTime(2030, 6, 1, 12);
    });

    test('a newer version is offered', () async {
      answer([row(latest: '1.1.0')]);

      final u = await service().check();

      expect(u, isNotNull);
      expect(u!.latest, '1.1.0');
      expect(u.current, '1.0.0');
      expect(u.mandatory, isFalse);
    });

    test('the same version is up to date', () async {
      answer([row(latest: '1.0.0')]);

      expect(await service().check(), isNull);
    });

    test('running a newer one than published (a test build) is fine', () async {
      answer([row(latest: '1.0.0')]);

      expect(await service(version: '1.2.0').check(), isNull);
    });

    test('the build number does not matter', () async {
      answer([row(latest: '1.0.0')]);

      expect(await service(version: '1.0.0+57').check(), isNull);
    });

    test('1.10.0 is newer than 1.9.0', () async {
      answer([row(latest: '1.10.0')]);

      expect(await service(version: '1.9.0').check(), isNotNull);
    });

    test('asks for its own platform', () async {
      answer([row(latest: '2.0.0')], platform: 'ios');

      final u = await service(platform: TargetPlatform.iOS).check();

      expect(u?.latest, '2.0.0');
    });

    test('a platform without a store is not checked', () async {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(await service(platform: p).check(), isNull);
      }
      verifyNever(
        () => client.rpc<dynamic>(any(), params: any(named: 'params')),
      );
    });

    group('compulsory', () {
      test('below the minimum version', () async {
        answer([row(latest: '1.3.0', min: '1.2.0')]);

        final u = await service(version: '1.1.0').check();

        expect(u!.mandatory, isTrue);
        expect(u.latest, '1.3.0');
      });

      test('exactly the minimum is allowed', () async {
        answer([row(latest: '1.3.0', min: '1.2.0')]);

        final u = await service(version: '1.2.0').check();

        expect(u!.mandatory, isFalse);
      });

      test(
        'a minimum above "latest" is a data slip: the minimum is shown',
        () async {
          answer([row(latest: '1.1.0', min: '1.5.0')]);

          final u = await service(version: '1.0.0').check();

          expect(u!.mandatory, isTrue);
          expect(u.latest, '1.5.0');
        },
      );

      test('a minimum we cannot read does not force anything', () async {
        answer([row(latest: '1.1.0', min: 'soon')]);

        final u = await service().check();

        expect(u!.mandatory, isFalse);
      });
    });

    group('where to get it', () {
      test('the link from the database', () async {
        answer([row(url: 'https://apps.apple.com/app/id123')]);

        final u = await service(platform: TargetPlatform.android).check();

        expect(u!.storeUrl, 'https://apps.apple.com/app/id123');
      });

      test('Android falls back to the Play Store page of the package', () async {
        answer([row(url: null)]);

        final u = await service().check();

        expect(
          u!.storeUrl,
          'https://play.google.com/store/apps/details?id=com.carrywise.carrywise_app',
        );
      });

      test('iOS without a link has none', () async {
        answer([row(url: '  ')], platform: 'ios');

        final u = await service(platform: TargetPlatform.iOS).check();

        expect(u!.storeUrl, isNull);
      });

      test('a link that is not https is not trusted', () async {
        answer([row(url: 'http://evil.example')], platform: 'ios');

        final u = await service(platform: TargetPlatform.iOS).check();

        expect(u!.storeUrl, isNull);
      });
    });

    test('release notes are trimmed, and empty when missing', () async {
      answer([row(notes: '  Several items.  ')]);
      expect((await service().check())!.notes, 'Several items.');

      answer([row(notes: null)]);
      expect((await service().check())!.notes, '');
    });

    group('never gets in the way', () {
      test('offline', () async {
        answer(null, error: Exception('offline'));

        expect(await service().check(), isNull);
      });

      test('no row for the platform', () async {
        answer(<dynamic>[]);

        expect(await service().check(), isNull);
      });

      test('an unreadable answer', () async {
        answer('oops');
        expect(await service().check(), isNull);

        answer([row(latest: 'next week')]);
        expect(await service().check(), isNull);
      });

      test('an unreadable own version', () async {
        answer([row(latest: '9.0.0')]);

        expect(await service(version: 'dev').check(), isNull);
      });

      test('a single object instead of a list also works', () async {
        answer(row(latest: '1.1.0'));

        expect(await service().check(), isNotNull);
      });
    });

    group('"Later"', () {
      AppUpdate update({String latest = '1.1.0', bool mandatory = false}) =>
          AppUpdate(
            latest: latest,
            current: '1.0.0',
            mandatory: mandatory,
            storeUrl: 'https://x.example',
          );

      test('is shown when never postponed', () async {
        expect(await service().shouldPrompt(update()), isTrue);
      });

      test('is not shown again straight after "Later"', () async {
        final s = service();
        await s.postpone(update());

        expect(await s.shouldPrompt(update()), isFalse);
      });

      test('is shown again after a day', () async {
        final s = service();
        await s.postpone(update());

        now = now.add(const Duration(hours: 23, minutes: 59));
        expect(await s.shouldPrompt(update()), isFalse);
        now = now.add(const Duration(minutes: 2));
        expect(await s.shouldPrompt(update()), isTrue);
      });

      test('a newer version is shown right away', () async {
        final s = service();
        await s.postpone(update(latest: '1.1.0'));

        expect(await s.shouldPrompt(update(latest: '1.2.0')), isTrue);
      });

      test('a compulsory update is always shown', () async {
        final s = service();
        await s.postpone(update());

        expect(await s.shouldPrompt(update(mandatory: true)), isTrue);
      });

      test('survives restarting the app', () async {
        await service().postpone(update());

        expect(await service().shouldPrompt(update()), isFalse);
      });

      test('a damaged saved value does not block the notice', () async {
        SharedPreferences.setMockInitialValues({'update_dismissed': 'garbage'});
        expect(await service().shouldPrompt(update()), isTrue);

        SharedPreferences.setMockInitialValues({'update_dismissed': '1.1.0|x'});
        expect(await service().shouldPrompt(update()), isTrue);
      });
    });
  });
}
