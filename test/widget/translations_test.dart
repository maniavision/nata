import 'package:carrywise_app/l10n/app_localizations.dart';
import 'package:carrywise_app/l10n/l10n_ext.dart';
import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/traveler_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Pages follow the language the user picked, not just English.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpHome(WidgetTester tester, String lang) async {
    tallScreen(tester);
    await tester.pumpWidget(
      appWrapper(
        HomeScreen(
          authService: FakeAuthService(),
          travelerService: FakeTravelerService(trips: [sampleTrip()]),
          capitalLookup: fakeCapitalLookup,
        ),
        locale: Locale(lang),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// English text that used to be hard-coded on Home.
  const homeEnglish = [
    'Hello,',
    'Where are you sending?',
    'DEPARTURE',
    'DESTINATION',
    'Anytime this month',
    'Search Travelers',
    'Add a Trip',
    'Available Travelers',
    'View all',
  ];

  group('Home', () {
    testWidgets('French', (tester) async {
      await pumpHome(tester, 'fr');

      expect(find.text('Bonjour,'), findsOneWidget);
      expect(find.text('Où envoyez-vous ?'), findsOneWidget);
      expect(find.text("N'importe quand ce mois-ci"), findsOneWidget);
      expect(find.text('Voyageurs disponibles'), findsOneWidget);
      expect(find.textContaining('28 livraisons'), findsOneWidget);
      // "Destination" is the same word in French.
      for (final s in homeEnglish.where((s) => s != 'DESTINATION')) {
        expect(find.text(s), findsNothing, reason: s);
      }
    });

    testWidgets('Spanish', (tester) async {
      await pumpHome(tester, 'es');

      expect(find.text('Hola,'), findsOneWidget);
      expect(find.text('¿A dónde envías?'), findsOneWidget);
      expect(find.text('Viajeros disponibles'), findsOneWidget);
      for (final s in homeEnglish) {
        expect(find.text(s), findsNothing, reason: s);
      }
    });

    testWidgets('dates use the language too', (tester) async {
      await pumpHome(tester, 'fr');
      // sampleTrip leaves on 22 June 2030.
      expect(find.text('22 juin'), findsOneWidget);
      expect(find.text('Jun 22'), findsNothing);
    });

    testWidgets('the date picker is translated', (tester) async {
      await pumpHome(tester, 'es');
      await tester.tap(find.byKey(const ValueKey('home-date-field')));
      await tester.pumpAndSettle();

      expect(find.text('Fecha de entrega deseada'), findsOneWidget);
      expect(find.text('Esta semana'), findsOneWidget);
      expect(find.text('Próxima semana'), findsOneWidget);
      expect(find.text('Confirmar fecha (cualquier día)'), findsOneWidget);
      expect(find.text('This Week'), findsNothing);
      // Week day headers in Spanish, starting on Sunday.
      expect(find.text('Do'), findsOneWidget);
      expect(find.text('Lu'), findsOneWidget);
      expect(find.text('Su'), findsNothing);
    });
  });

  testWidgets('Traveler results are translated', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      appWrapper(
        TravelerResultsScreen(
          service: FakeTravelerService(trips: [sampleTrip()]),
        ),
        locale: const Locale('fr'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Voyageurs trouvés'), findsOneWidget);
    expect(find.text('1 disponible'), findsOneWidget);
    expect(find.text('Accepte jusqu\'à 3.0 kg'), findsOneWidget);
    expect(find.text('Travelers Found'), findsNothing);
  });

  group('Trip sizes', () {
    Future<AppLocalizations> l10n(String lang) =>
        AppLocalizations.delegate.load(Locale(lang));

    test('are shown in the app language, keeping the dimensions', () async {
      final fr = await l10n('fr');
      expect(
        fr.tripSize('Shoebox (30×20×15 cm)'),
        'Boîte à chaussures (30×20×15 cm)',
      );
      expect(fr.tripSize('Backpack size'), 'Sac à dos');
      expect(fr.tripSize('Envelope / Document'), 'Enveloppe / Document');
      expect(fr.tripSizeShort('Shoebox (30×20×15 cm)'), 'Boîte à chaussures');

      final es = await l10n('es');
      expect(es.tripSize('Backpack size'), 'Mochila');
    });

    test('English keeps what the traveler picked', () async {
      final en = await l10n('en');
      expect(en.tripSize('Backpack size'), 'Backpack size');
      expect(en.tripSizeShort('Shoebox (30×20×15 cm)'), 'Shoebox');
    });

    test('unknown or missing sizes', () async {
      final fr = await l10n('fr');
      expect(fr.tripSize('Suitcase'), 'Suitcase');
      expect(fr.tripSize(null), '—');
      expect(fr.tripSize('  '), '—');
    });
  });
}
