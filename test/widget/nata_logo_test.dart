import 'package:carrywise_app/screens/login_screen.dart';
import 'package:carrywise_app/screens/sign_up_screen.dart';
import 'package:carrywise_app/screens/splash_screen.dart';
import 'package:carrywise_app/widgets/nata_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the logo image is bundled', () async {
    final data = await rootBundle.load(NataLogo.asset);
    expect(data.lengthInBytes, greaterThan(1000));
  });

  for (final (name, page) in [
    ('Splash', () => const SplashScreen()),
    ('Login', () => LoginScreen(authService: FakeAuthService())),
    ('Sign up', () => SignUpScreen(authService: FakeAuthService())),
  ]) {
    testWidgets('$name shows the logo, not the old paper plane', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appWrapper(page()));
      await tester.pump();

      expect(find.byType(NataLogo), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NataLogo),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });
  }
}
