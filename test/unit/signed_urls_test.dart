import 'package:carrywise_app/services/signed_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var now = DateTime(2030, 1, 1, 12);
  setUp(() {
    now = DateTime(2030, 1, 1, 12);
    SignedUrls.clear();
    SignedUrls.now = () => now;
  });
  tearDown(() => SignedUrls.now = DateTime.now);

  var made = 0;
  Future<String> create() async => 'https://x/sign/b/p.jpg?token=${++made}';
  Future<String> link([String path = 'p.jpg']) => SignedUrls.get(
    'b',
    path,
    lifetime: const Duration(minutes: 10),
    create: create,
  );

  test('the same photo reuses its link while it is valid', () async {
    made = 0;
    final first = await link();
    now = now.add(const Duration(minutes: 7));
    expect(await link(), first);
    expect(made, 1);
  });

  test('a link about to expire is replaced', () async {
    made = 0;
    await link();
    now = now.add(const Duration(minutes: 9));
    expect(await link(), endsWith('token=2'));
  });

  test('asking twice at once makes one link', () async {
    made = 0;
    final both = await Future.wait([link(), link()]);
    expect(both[0], both[1]);
    expect(made, 1);
  });

  test('different photos get their own links', () async {
    made = 0;
    await link('a.jpg');
    await link('b.jpg');
    expect(made, 2);
  });

  test('a replaced photo gets a new link', () async {
    made = 0;
    await link();
    SignedUrls.forget('b', 'p.jpg');
    await link();
    expect(made, 2);
  });

  test('signing out forgets every link', () async {
    made = 0;
    await link();
    SignedUrls.clear();
    await link();
    expect(made, 2);
  });

  test('a failed link is not kept', () async {
    var fail = true;
    Future<String> flaky() async {
      if (fail) throw Exception('offline');
      return 'https://x/sign/b/p.jpg?token=ok';
    }

    Future<String> get() => SignedUrls.get(
      'b',
      'p.jpg',
      lifetime: const Duration(minutes: 10),
      create: flaky,
    );
    await expectLater(get(), throwsException);
    fail = false;
    expect(await get(), endsWith('token=ok'));
  });

  test('a photo is kept under its path, whatever the token', () {
    expect(
      SignedUrls.imageKey('https://x/sign/b/p.jpg?token=1'),
      SignedUrls.imageKey('https://x/sign/b/p.jpg?token=2'),
    );
    expect(
      SignedUrls.imageKey('https://x/sign/b/p.jpg?token=1'),
      isNot(SignedUrls.imageKey('https://x/sign/b/q.jpg?token=1')),
    );
    expect(
      SignedUrls.imageKey('https://x/public/a.jpeg'),
      'storage:https://x/public/a.jpeg',
    );
  });
}
