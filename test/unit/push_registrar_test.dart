import 'package:carrywise_app/services/push_registrar.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone is registered for the signed-in member's pushes, which is what
/// lets the phone show them while the app is closed.
void main() {
  late String? user;
  late bool allowed;
  late String? apns;
  late String? fcm;
  late List<String> saved;
  late int asks;
  late bool saveFails;

  setUp(() {
    user = 'u1';
    allowed = true;
    apns = 'apns';
    fcm = 'fcm-1';
    saved = [];
    asks = 0;
    saveFails = false;
  });

  PushRegistrar registrar({bool ios = true, Duration? apnsWait}) =>
      PushRegistrar(
        requestPermission: () async {
          asks++;
          return allowed;
        },
        apnsToken: ios ? () async => apns : null,
        fcmToken: () async => fcm,
        save: (t) async {
          if (saveFails) throw Exception('offline');
          saved.add(t);
        },
        userId: () => user,
        apnsWait: apnsWait ?? const Duration(milliseconds: 200),
        apnsPoll: const Duration(milliseconds: 20),
      );

  test('registers the phone for the signed-in member', () async {
    expect(await registrar().ensure(), isTrue);
    expect(saved, ['fcm-1']);
  });

  test('Android needs no APNs token', () async {
    apns = null;
    expect(await registrar(ios: false).ensure(), isTrue);
    expect(saved, ['fcm-1']);
  });

  test('waits for an APNs token that arrives late', () async {
    apns = null;
    final r = registrar(apnsWait: const Duration(seconds: 2));
    Future.delayed(const Duration(milliseconds: 100), () => apns = 'apns');
    expect(await r.ensure(), isTrue);
    expect(saved, ['fcm-1']);
  });

  test(
    'no APNs token in time: not registered, and tried again later',
    () async {
      apns = null;
      final r = registrar();
      expect(await r.ensure(), isFalse);
      expect(saved, isEmpty);

      apns = 'apns';
      expect(await r.ensure(), isTrue);
      expect(saved, ['fcm-1']);
    },
  );

  test('nobody signed in: nothing is asked or saved', () async {
    user = null;
    expect(await registrar().ensure(), isFalse);
    expect(asks, 0);
    expect(saved, isEmpty);
  });

  test('notifications refused: nothing is saved', () async {
    allowed = false;
    expect(await registrar().ensure(), isFalse);
    expect(saved, isEmpty);
  });

  test('already registered: not saved again on each return', () async {
    final r = registrar();
    await r.ensure();
    await r.ensure();
    await r.ensure();
    expect(saved, ['fcm-1']);
  });

  test('a failed save is tried again next time', () async {
    final r = registrar();
    saveFails = true;
    expect(await r.ensure(), isFalse);
    saveFails = false;
    expect(await r.ensure(), isTrue);
    expect(saved, ['fcm-1']);
  });

  test(
    'another member signing in on the phone registers it for them',
    () async {
      final r = registrar();
      await r.ensure();
      r.forget();
      user = 'u2';
      await r.ensure();
      expect(saved, ['fcm-1', 'fcm-1']);
    },
  );

  test('a new Firebase token is saved', () async {
    final r = registrar();
    await r.ensure();
    await r.tokenChanged('fcm-2');
    expect(saved, ['fcm-1', 'fcm-2']);
    // ...and isn't saved again by the next check.
    fcm = 'fcm-2';
    await r.ensure();
    expect(saved, ['fcm-1', 'fcm-2']);
  });

  test('checks at the same moment save once', () async {
    final r = registrar();
    await Future.wait([r.ensure(), r.ensure(), r.ensure()]);
    expect(saved, ['fcm-1']);
  });

  test('signed out while waiting: nothing is saved', () async {
    apns = null;
    final r = registrar(apnsWait: const Duration(seconds: 2));
    Future.delayed(const Duration(milliseconds: 60), () {
      user = null;
      apns = 'apns';
    });
    expect(await r.ensure(), isFalse);
    expect(saved, isEmpty);
  });
}
