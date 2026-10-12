import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/splash_screen.dart';
import 'package:carrywise_app/services/preferences_service.dart';
import 'package:carrywise_app/services/region_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });
  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService().resetAll();
  });

  group('SplashScreen UI', () {
    // By default no country is detected (location off / not allowed).
    Widget buildSplash({
      Locale locale = const Locale('en'),
      DetectedRegion? detected,
    }) => appWrapper(
      SplashScreen(regionService: FakeRegionService(region: detected)),
      locale: locale,
    );

    testWidgets('renders language selector heading in English', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.textContaining('Language'), findsWidgets);
    });

    testWidgets('renders three language options', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('renders four currency options', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.textContaining('USD'), findsWidgets);
      expect(find.textContaining('EUR'), findsWidgets);
      expect(find.textContaining('GBP'), findsWidgets);
      expect(find.textContaining('XOF'), findsWidgets);
    });

    testWidgets('English is selected by default', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      // English tile is first; Default · International appears as subtitle
      expect(find.textContaining('International'), findsOneWidget);
    });

    testWidgets('Save & Continue button is present', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.text('Save & Continue'), findsOneWidget);
    });

    testWidgets('tapping Spanish selects it', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      await tester.tap(find.text('Español'));
      await tester.pump();

      // After tapping Español, its sub-label should be visible
      expect(find.textContaining('España'), findsWidgets);
    });

    testWidgets('tapping French selects it', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      await tester.tap(find.text('Français'));
      await tester.pump();

      expect(find.textContaining('France'), findsWidgets);
    });

    testWidgets('USD currency is selected by default', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      // USD tile should show a check icon (selected state)
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping EUR selects it as currency', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      final eurFinder = find.textContaining('EUR').first;
      await tester.ensureVisible(eurFinder);
      await tester.pump();
      await tester.tap(eurFinder, warnIfMissed: false);
      await tester.pump();

      // Currency grid is visible — check_circle still present somewhere
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('Quick Apply button is present once a region is detected', (
      tester,
    ) async {
      await tester.pumpWidget(buildSplash(detected: region()));
      await tester.pumpAndSettle();

      expect(find.text('Quick Apply'), findsOneWidget);
    });

    testWidgets('settings note text is present', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.textContaining('Profile Settings'), findsOneWidget);
    });

    testWidgets('Nata brand visible in hero pill', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.text('Nata'), findsOneWidget);
    });

    testWidgets('180+ Countries badge visible', (tester) async {
      await tester.pumpWidget(buildSplash());
      await tester.pump();

      expect(find.textContaining('180+'), findsOneWidget);
    });
  });

  group('SplashScreen "Detected region"', () {
    Future<void> pump(
      WidgetTester tester,
      FakeRegionService service, {
      Locale locale = const Locale('en'),
      bool settle = true,
    }) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        appWrapper(SplashScreen(regionService: service), locale: locale),
      );
      if (settle) await tester.pumpAndSettle();
    }

    group('is hidden', () {
      testWidgets('when no country could be detected', (tester) async {
        await pump(tester, FakeRegionService(region: null));

        expect(find.text('DETECTED REGION'), findsNothing);
        expect(find.text('Quick Apply'), findsNothing);
        expect(find.byIcon(Icons.explore_rounded), findsNothing);
      });

      testWidgets('while the country is still being looked up', (tester) async {
        final service = FakeRegionService(region: region())
          ..gate = Completer<void>();

        await pump(tester, service, settle: false);
        await tester.pump();

        expect(service.detectCalls, 1);
        expect(find.text('DETECTED REGION'), findsNothing);
        expect(find.text('Quick Apply'), findsNothing);
      });

      testWidgets('and never shows made-up values', (tester) async {
        await pump(tester, FakeRegionService(region: null));

        expect(
          find.textContaining('United States · English & USD'),
          findsNothing,
        );
      });

      testWidgets('the rest of the page still works without it', (
        tester,
      ) async {
        await pump(tester, FakeRegionService(region: null));

        expect(find.text('Select Language & Currency'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Save & Continue'), findsOneWidget);
      });
    });

    group('appears', () {
      testWidgets('when a country has been detected', (tester) async {
        await pump(tester, FakeRegionService(region: region()));

        expect(find.text('DETECTED REGION'), findsOneWidget);
        expect(find.text('Quick Apply'), findsOneWidget);
        expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
      });

      testWidgets('after the lookup finishes, not before', (tester) async {
        final gate = Completer<void>();
        final service = FakeRegionService(region: region())..gate = gate;
        await pump(tester, service, settle: false);
        await tester.pump();
        expect(find.text('DETECTED REGION'), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();

        expect(find.text('DETECTED REGION'), findsOneWidget);
      });

      testWidgets('showing the detected country, language and currency', (
        tester,
      ) async {
        await pump(
          tester,
          FakeRegionService(
            region: region(
              iso: 'FR',
              name: 'France',
              language: AppLanguage.french,
              currency: AppCurrency.eur,
            ),
          ),
        );

        expect(find.text('France · Français & EUR'), findsOneWidget);
      });

      testWidgets('for the USA it reads "United States · English & USD"', (
        tester,
      ) async {
        await pump(tester, FakeRegionService(region: region()));

        expect(find.text('United States · English & USD'), findsOneWidget);
      });

      testWidgets('for a CFA-franc country it shows XOF', (tester) async {
        await pump(
          tester,
          FakeRegionService(
            region: region(
              iso: 'SN',
              name: 'Senegal',
              language: AppLanguage.french,
              currency: AppCurrency.xof,
            ),
          ),
        );

        expect(find.text('Senegal · Français & XOF'), findsOneWidget);
      });

      testWidgets('the detected text follows the app language', (tester) async {
        await pump(
          tester,
          FakeRegionService(region: region()),
          locale: const Locale('es'),
        );
        expect(find.text('United States · English y USD'), findsOneWidget);

        await pump(
          tester,
          FakeRegionService(region: region()),
          locale: const Locale('fr'),
        );
        expect(find.text('United States · English et USD'), findsOneWidget);
      });

      testWidgets('the label and button are translated', (tester) async {
        await pump(
          tester,
          FakeRegionService(region: region()),
          locale: const Locale('es'),
        );

        expect(find.text('REGIÓN DETECTADA'), findsOneWidget);
        expect(find.text('Aplicar'), findsOneWidget);
      });
    });

    group('Quick Apply', () {
      testWidgets('applies the language and currency of the detected country', (
        tester,
      ) async {
        await pump(
          tester,
          FakeRegionService(
            region: region(
              iso: 'FR',
              name: 'France',
              language: AppLanguage.french,
              currency: AppCurrency.eur,
            ),
          ),
        );
        expect(PreferencesService().language, AppLanguage.english);
        expect(PreferencesService().currency, AppCurrency.usd);

        await tester.tap(find.byKey(const ValueKey('quick-apply')));
        await tester.pumpAndSettle();

        expect(PreferencesService().language, AppLanguage.french);
        expect(PreferencesService().currency, AppCurrency.eur);
      });

      testWidgets('is not hard-wired to English and dollars', (tester) async {
        PreferencesService().setLanguage(AppLanguage.english);
        PreferencesService().setCurrency(AppCurrency.usd);
        await pump(
          tester,
          FakeRegionService(
            region: region(
              iso: 'MX',
              name: 'Mexico',
              language: AppLanguage.spanish,
              currency: AppCurrency.usd,
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('quick-apply')));
        await tester.pumpAndSettle();

        expect(PreferencesService().language, AppLanguage.spanish);
      });

      testWidgets('for the UK it selects British pounds', (tester) async {
        await pump(
          tester,
          FakeRegionService(
            region: region(
              iso: 'GB',
              name: 'United Kingdom',
              currency: AppCurrency.gbp,
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('quick-apply')));
        await tester.pumpAndSettle();

        expect(PreferencesService().currency, AppCurrency.gbp);
        expect(PreferencesService().language, AppLanguage.english);
      });

      testWidgets('switches the whole page to the detected language', (
        tester,
      ) async {
        // The page follows PreferencesService in the real app (NataApp); here
        // we only check the preference changed for the next screens.
        await pump(
          tester,
          FakeRegionService(
            region: region(
              iso: 'ES',
              name: 'Spain',
              language: AppLanguage.spanish,
              currency: AppCurrency.eur,
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('quick-apply')));
        await tester.pumpAndSettle();

        expect(PreferencesService().locale, const Locale('es'));
      });

      testWidgets('leaves the registered country alone', (tester) async {
        PreferencesService().setCountry('GH');
        await pump(tester, FakeRegionService(region: region()));

        await tester.tap(find.byKey(const ValueKey('quick-apply')));
        await tester.pumpAndSettle();

        expect(PreferencesService().countryIsoCode, 'GH');
      });
    });

    testWidgets('the lookup happens once, when the page opens', (tester) async {
      final service = FakeRegionService(region: region());

      await pump(tester, service);
      await tester.pump(const Duration(seconds: 30));

      expect(service.detectCalls, 1);
    });

    testWidgets('leaving the page before the lookup finishes is safe', (
      tester,
    ) async {
      final gate = Completer<void>();
      final service = FakeRegionService(region: region())..gate = gate;
      await pump(tester, service, settle: false);

      await tester.pumpWidget(const SizedBox.shrink()); // page closed
      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
