import 'package:carrywise_app/screens/home_screen.dart';
import 'package:carrywise_app/screens/identity_verification_screen.dart';
import 'package:carrywise_app/services/emergency_contact_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeEmergencyContactService service;

  setUp(() => service = FakeEmergencyContactService());

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    int step = 2,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      appWrapper(
        IdentityVerificationScreen(
          initialStep: step,
          emergencyService: service,
        ),
        locale: locale,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> enter(WidgetTester t, String key, String text) async {
    await t.enterText(find.byKey(ValueKey(key)), text);
    await t.pump();
  }

  Future<void> tapKey(WidgetTester t, String key) async {
    await t.tap(find.byKey(ValueKey(key)));
    // Twice: the first lets a save finish, the second plays the slide.
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 500));
  }

  Future<void> fill(WidgetTester t) async {
    await enter(t, 'contact-name', 'Jane Doe');
    await enter(t, 'contact-phone', '+44 7700 900123');
  }

  String errorText(WidgetTester t) => (t
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('contact-error')),
          matching: find.byType(Text),
        ),
      )
      .data!);

  group('what it shows', () {
    testWidgets('the content from the design', (tester) async {
      await pump(tester);

      for (final t in [
        'REQUIRED',
        'An emergency contact is required to finish verification',
        'It stays private and is only used if something goes wrong during a delivery.',
        'EMERGENCY CONTACT',
        'Step 2 of 2',
        'Add an emergency contact',
        'Someone we can reach if something goes wrong during a delivery.',
        'FULL NAME',
        'TELEPHONE NUMBER',
        'RELATIONSHIP',
        'Friend',
        'Relative',
        'Partner',
        'Colleague',
        'Finish Verification',
        'Your details are stored securely and used only for safety purposes.',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(
        find.textContaining('never shown to senders or travelers'),
        findsOneWidget,
      );
      expect(find.text("Contact's full name"), findsOneWidget);
      expect(find.text('e.g. 7700 900123'), findsOneWidget);
    });

    testWidgets('starts empty, with Friend chosen', (tester) async {
      await pump(tester);
      await fill(tester);

      await tapKey(tester, 'contact-finish');

      expect(service.saved.single.relationship, EmergencyRelationship.friend);
    });

    testWidgets('translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text("Ajoutez un contact d'urgence"), findsOneWidget);
      expect(find.text('Terminer la vérification'), findsOneWidget);
      expect(find.text('Étape 2 sur 2'), findsOneWidget);
    });
  });

  group('relationship', () {
    for (final r in EmergencyRelationship.values) {
      testWidgets('${r.name} is what is saved when chosen', (tester) async {
        await pump(tester);
        await fill(tester);
        await tapKey(tester, 'contact-rel-${r.name}');

        await tapKey(tester, 'contact-finish');

        expect(service.saved.single.relationship, r);
      });
    }

    testWidgets('the last choice wins', (tester) async {
      await pump(tester);
      await fill(tester);
      await tapKey(tester, 'contact-rel-partner');
      await tapKey(tester, 'contact-rel-colleague');

      await tapKey(tester, 'contact-finish');

      expect(
        service.saved.single.relationship,
        EmergencyRelationship.colleague,
      );
    });
  });

  group('validation', () {
    testWidgets('an empty form asks for the name first', (tester) async {
      await pump(tester);

      await tapKey(tester, 'contact-finish');

      expect(errorText(tester), "Enter the contact's full name.");
      expect(service.attempts, 0);
    });

    testWidgets('a one-letter name is not enough', (tester) async {
      await pump(tester);
      await enter(tester, 'contact-name', 'J');

      await tapKey(tester, 'contact-finish');

      expect(errorText(tester), "Enter the contact's full name.");
    });

    testWidgets('then the phone number', (tester) async {
      await pump(tester);
      await enter(tester, 'contact-name', 'Jane Doe');

      await tapKey(tester, 'contact-finish');

      expect(errorText(tester), contains('valid phone number'));
      expect(service.attempts, 0);
    });

    for (final bad in ['+44 77', '+44 7700', '123', '0000']) {
      testWidgets('"$bad" is not a valid number', (tester) async {
        await pump(tester);
        await enter(tester, 'contact-name', 'Jane Doe');
        await enter(tester, 'contact-phone', bad);

        await tapKey(tester, 'contact-finish');

        expect(service.attempts, 0, reason: bad);
        expect(find.byKey(const ValueKey('contact-error')), findsOneWidget);
      });
    }

    testWidgets('typing clears the error', (tester) async {
      await pump(tester);
      await tapKey(tester, 'contact-finish');
      expect(find.byKey(const ValueKey('contact-error')), findsOneWidget);

      await enter(tester, 'contact-name', 'Jane');

      expect(find.byKey(const ValueKey('contact-error')), findsNothing);
    });

    testWidgets('the error is translated', (tester) async {
      await pump(tester, locale: const Locale('es'));

      await tapKey(tester, 'contact-finish');

      expect(errorText(tester), 'Introduce el nombre completo del contacto.');
    });
  });

  group('country code', () {
    // The screen's pulse animation repeats forever, so no pumpAndSettle.
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> pickCountry(WidgetTester t, String name) async {
      await t.tap(find.byKey(const ValueKey('contact-country')));
      await settle(t);
      await t.enterText(
        find.widgetWithText(TextField, 'Search country...'),
        name,
      );
      await settle(t);
      await t.tap(find.text(name).last);
      await settle(t);
    }

    testWidgets('starts on the user\'s country code', (tester) async {
      await pump(tester);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('contact-country')),
          matching: find.text('+1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('prefixes the local number with the picked code', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'contact-name', 'Jane Doe');
      await pickCountry(tester, 'United Kingdom');
      // The UK trunk "0" is dropped: 07700 -> +44 7700.
      await enter(tester, 'contact-phone', '07700 900123');

      await tapKey(tester, 'contact-finish');

      expect(service.saved.single.phone, '+447700900123');
    });

    testWidgets('uses the default code when none is picked', (tester) async {
      await pump(tester);
      await enter(tester, 'contact-name', 'Jane Doe');
      await enter(tester, 'contact-phone', '(202) 555-0143');

      await tapKey(tester, 'contact-finish');

      expect(service.saved.single.phone, '+12025550143');
    });

    testWidgets('a number typed with its own + code is kept as is', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'contact-name', 'Jane Doe');
      await enter(tester, 'contact-phone', '+237 6 77 12 34 56');

      await tapKey(tester, 'contact-finish');

      expect(service.saved.single.phone, '+237677123456');
    });
  });

  group('saving', () {
    testWidgets('saves the cleaned-up contact, then shows the success step', (
      tester,
    ) async {
      await pump(tester);
      await enter(tester, 'contact-name', '  Jane Doe ');
      await enter(tester, 'contact-phone', '+44 (7700) 900-123');
      await tapKey(tester, 'contact-rel-relative');

      await tapKey(tester, 'contact-finish');

      final c = service.saved.single;
      expect(c.fullName, 'Jane Doe');
      expect(c.phone, '+447700900123');
      expect(c.relationship, EmergencyRelationship.relative);
      expect(find.byKey(const ValueKey('contact-finish')), findsNothing);
    });

    testWidgets('shows a spinner and blocks a second tap while saving', (
      tester,
    ) async {
      service.gate = Completer<void>();
      await pump(tester);
      await fill(tester);

      await tapKey(tester, 'contact-finish');

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('contact-finish')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(service.attempts, 1);

      service.gate!.complete();
      await tester.pump(const Duration(milliseconds: 600));
      expect(service.saved.length, 1);
    });

    testWidgets('a failure keeps the form and shows a message', (tester) async {
      service.fail = Exception('network');
      await pump(tester);
      await fill(tester);

      await tapKey(tester, 'contact-finish');

      expect(
        errorText(tester),
        'Could not save the contact. Please try again.',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('contact-name')))
            .controller!
            .text,
        'Jane Doe',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('and it can be tried again', (tester) async {
      service.fail = Exception('network');
      await pump(tester);
      await fill(tester);
      await tapKey(tester, 'contact-finish');

      service.fail = null;
      await tapKey(tester, 'contact-finish');

      expect(service.saved.length, 1);
      expect(find.byKey(const ValueKey('contact-error')), findsNothing);
    });
  });

  group('leaving', () {
    testWidgets('it can\'t be skipped: being verified needs it', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Skip for now'), findsNothing);
      expect(find.byKey(const ValueKey('contact-skip')), findsNothing);
      expect(
        find.byKey(const ValueKey('contact-required-note')),
        findsOneWidget,
      );
    });

    testWidgets('back returns to the ID step', (tester) async {
      await pump(tester);

      await tapKey(tester, 'contact-back');

      expect(find.byKey(const ValueKey('contact-finish')), findsNothing);
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('the success step goes to the home screen', (tester) async {
      // Only checks that the continue button exists on the success step.
      await pump(tester, step: 3);

      expect(find.byType(ElevatedButton), findsWidgets);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('the success step can open the profile', (tester) async {
      await pump(tester, step: 3);

      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('view-public-profile')),
      );
      expect(button.onPressed, isNotNull);
    });
  });
}
