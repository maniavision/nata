import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/screens/login_screen.dart';
import '../helpers/app_wrapper.dart';

void main() {
  group('LoginScreen — country code picker', () {
    Widget buildLogin() => appWrapper(const LoginScreen());

    testWidgets('shows default USA flag and +1', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('shows dropdown arrow icon on the picker', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('tapping country picker opens bottom sheet', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      // Tap the country picker button (contains the flag + code)
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Sheet title appears
      expect(find.text('Select Country Code'), findsOneWidget);
    });

    testWidgets('bottom sheet shows search field', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Search country...'),
        findsOneWidget,
      );
    });

    testWidgets('bottom sheet shows close button', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets('bottom sheet shows country list with flags', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Nigeria should be in the list (it's a bundled country)
      expect(find.text('Nigeria'), findsOneWidget);
    });

    testWidgets('bottom sheet shows phone codes', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // +234 appears at least once (could be in picker button + list)
      expect(find.text('+234'), findsWidgets);
    });

    testWidgets('selected country is highlighted in the list', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Find the selected country (the USA) and check that it is marked.
      await tester.enterText(
        find.widgetWithText(TextField, 'Search country...'),
        'United States',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('searching filters the country list', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Type "United" in the search field
      await tester.enterText(
        find.widgetWithText(TextField, 'Search country...'),
        'United',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('United Kingdom'), findsOneWidget);
    });

    testWidgets('selecting a country updates the login screen prefix', (
      tester,
    ) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      // Open picker
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Search for Ghana (short, unambiguous)
      await tester.enterText(
        find.widgetWithText(TextField, 'Search country...'),
        'Ghana',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Ghana from the list (it's a Text widget in a ListTile row)
      // Use find.text and tap the last occurrence (list item, not search field)
      await tester.tap(find.text('Ghana').last);
      await tester.pumpAndSettle();

      // Sheet dismissed, phone prefix updated
      expect(find.text('+233'), findsOneWidget);
      expect(find.text('🇬🇭'), findsOneWidget);
    });

    testWidgets('closing sheet without selection keeps original country', (
      tester,
    ) async {
      await tester.pumpWidget(buildLogin());
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      // Tap close
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      // Still the USA
      expect(find.text('🇺🇸'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });
  });
}
