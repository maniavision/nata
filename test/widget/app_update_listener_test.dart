import 'package:carrywise_app/services/app_update_service.dart';
import 'package:carrywise_app/widgets/app_update_listener.dart';
import 'package:carrywise_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/fakes.dart';

AppUpdate update({
  String latest = '1.1.0',
  bool mandatory = false,
  String? url = 'https://play.google.com/store/apps/details?id=x',
  String notes = '',
}) => AppUpdate(
  latest: latest,
  current: '1.0.0',
  mandatory: mandatory,
  storeUrl: url,
  notes: notes,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final key = GlobalKey<NavigatorState>();
  var now = DateTime(2030, 6, 1, 12);
  final opened = <String>[];
  var launchResult = true;

  Future<bool> launcher(String url) async {
    opened.add(url);
    return launchResult;
  }

  setUp(() {
    opened.clear();
    launchResult = true;
    now = DateTime(2030, 6, 1, 12);
  });

  Future<void> pump(
    WidgetTester tester,
    FakeAppUpdateService service, {
    Locale locale = const Locale('en'),
    Size size = const Size(402, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      AppUpdateListener(
        navigatorKey: key,
        service: service,
        launcher: launcher,
        now: () => now,
        child: MaterialApp(
          navigatorKey: key,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  const notice = ValueKey('update-notice');

  group('when a new version is available', () {
    testWidgets('tells the user, with both version numbers', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update()));

      expect(find.byKey(notice), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(
        find.text('Nata 1.1.0 is available. You are using version 1.0.0.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('update-now')), findsOneWidget);
      expect(find.byKey(const ValueKey('update-later')), findsOneWidget);
    });

    testWidgets('the screen underneath is still there', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update()));

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('"Update" opens the store page', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update()));

      await tester.tap(find.byKey(const ValueKey('update-now')));
      await tester.pump();

      expect(opened, ['https://play.google.com/store/apps/details?id=x']);
      expect(find.byKey(const ValueKey('update-open-failed')), findsNothing);
    });

    testWidgets('if the store cannot be opened it says so, and can retry', (
      tester,
    ) async {
      launchResult = false;
      await pump(tester, FakeAppUpdateService(update: update()));

      await tester.tap(find.byKey(const ValueKey('update-now')));
      await tester.pump();

      expect(find.byKey(const ValueKey('update-open-failed')), findsOneWidget);
      expect(find.byKey(notice), findsOneWidget);

      launchResult = true;
      await tester.tap(find.byKey(const ValueKey('update-now')));
      await tester.pump();
      expect(find.byKey(const ValueKey('update-open-failed')), findsNothing);
      expect(opened.length, 2);
    });

    testWidgets('a launcher that throws is the same as failing', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = const Size(402, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppUpdateListener(
          navigatorKey: key,
          service: FakeAppUpdateService(update: update()),
          launcher: (_) async => throw Exception('no browser'),
          child: MaterialApp(
            navigatorKey: key,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('update-now')));
      await tester.pump();

      expect(find.byKey(const ValueKey('update-open-failed')), findsOneWidget);
    });

    testWidgets('"Later" closes it and remembers the choice', (tester) async {
      final service = FakeAppUpdateService(update: update());
      await pump(tester, service);

      await tester.tap(find.byKey(const ValueKey('update-later')));
      await tester.pump();

      expect(find.byKey(notice), findsNothing);
      expect(service.postponed.single.latest, '1.1.0');
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a tap outside the card does nothing', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update()));

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();

      expect(find.byKey(notice), findsOneWidget);
    });

    testWidgets('shows what is new when there are notes', (tester) async {
      await pump(
        tester,
        FakeAppUpdateService(
          update: update(notes: 'Several items per request.'),
        ),
      );

      expect(find.text("WHAT'S NEW"), findsOneWidget);
      expect(find.text('Several items per request.'), findsOneWidget);
    });

    testWidgets('no notes, no "what is new" box', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update()));

      expect(find.byKey(const ValueKey('update-notes')), findsNothing);
    });

    testWidgets('without a store link there is no Update button', (
      tester,
    ) async {
      await pump(tester, FakeAppUpdateService(update: update(url: null)));

      expect(find.byKey(notice), findsOneWidget);
      expect(find.byKey(const ValueKey('update-now')), findsNothing);
      expect(find.byKey(const ValueKey('update-later')), findsOneWidget);
    });

    testWidgets('translated', (tester) async {
      await pump(
        tester,
        FakeAppUpdateService(update: update()),
        locale: const Locale('fr'),
      );

      expect(find.text('Mise à jour disponible'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);
    });
  });

  group('when the update is compulsory', () {
    testWidgets('says the version is no longer supported', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update(mandatory: true)));

      expect(find.text('Update required'), findsOneWidget);
      expect(
        find.text(
          'This version of Nata is no longer supported. Please update to keep using the app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cannot be put off', (tester) async {
      await pump(tester, FakeAppUpdateService(update: update(mandatory: true)));

      expect(find.byKey(const ValueKey('update-later')), findsNothing);
      expect(find.byKey(const ValueKey('update-now')), findsOneWidget);
    });

    testWidgets('is shown even if "Later" was chosen before', (tester) async {
      final service = FakeAppUpdateService(update: update(mandatory: true))
        ..prompt = true;
      await pump(tester, service);

      expect(find.byKey(notice), findsOneWidget);
    });
  });

  group('when nothing is to be shown', () {
    testWidgets('up to date', (tester) async {
      await pump(tester, FakeAppUpdateService());

      expect(find.byKey(notice), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('postponed earlier', (tester) async {
      await pump(
        tester,
        FakeAppUpdateService(update: update())..prompt = false,
      );

      expect(find.byKey(notice), findsNothing);
    });

    testWidgets('a failing check is ignored', (tester) async {
      // The real check() never throws; even so the app must not break if it did.
      final service = FakeAppUpdateService(update: update())
        ..throwOnCheck = true;
      await pump(tester, service);

      expect(find.byKey(notice), findsNothing);
      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('checking again', () {
    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('checks once when the app opens', (tester) async {
      final service = FakeAppUpdateService();
      await pump(tester, service);

      expect(service.checks, 1);
    });

    testWidgets('coming back soon does not check again', (tester) async {
      final service = FakeAppUpdateService();
      await pump(tester, service);

      now = now.add(const Duration(hours: 5));
      await resume(tester);

      expect(service.checks, 1);
    });

    testWidgets('coming back after six hours checks again', (tester) async {
      final service = FakeAppUpdateService();
      await pump(tester, service);

      now = now.add(const Duration(hours: 6, minutes: 1));
      service.update = update();
      await resume(tester);

      expect(service.checks, 2);
      expect(find.byKey(notice), findsOneWidget);
    });

    testWidgets('a notice already showing is not stacked', (tester) async {
      final service = FakeAppUpdateService(update: update());
      await pump(tester, service);

      now = now.add(const Duration(hours: 7));
      await resume(tester);

      expect(find.byKey(notice), findsOneWidget);
      expect(service.checks, 1);
    });

    testWidgets('after "Later" it can show again at the next check', (
      tester,
    ) async {
      final service = FakeAppUpdateService(update: update());
      await pump(tester, service);
      await tester.tap(find.byKey(const ValueKey('update-later')));
      await tester.pump();

      now = now.add(const Duration(hours: 7));
      service.prompt = true;
      await resume(tester);

      expect(find.byKey(notice), findsOneWidget);
    });
  });

  group('layout', () {
    for (final size in const [Size(360, 640), Size(402, 874)]) {
      for (final scale in const [1.12, 1.3]) {
        for (final locale in const ['en', 'es', 'fr']) {
          testWidgets('no overflow: $locale ${size.width.toInt()}px x$scale', (
            tester,
          ) async {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            await pump(
              tester,
              FakeAppUpdateService(
                update: update(
                  notes:
                      'Several items in one request, an emergency contact for your '
                      'safety, and a new way to see when updates are available.',
                ),
              ),
              locale: Locale(locale),
              size: size,
            );

            expect(tester.takeException(), isNull);
            expect(find.byKey(notice), findsOneWidget);
          });
        }
      }
    }
  });
}
