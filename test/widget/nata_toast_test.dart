import 'package:carrywise_app/widgets/nata_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> show(WidgetTester tester, SnackBar toast) async {
    await tester.pumpWidget(
      appWrapper(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).showSnackBar(toast),
              child: const Text('SHOW'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SHOW'));
    await tester.pumpAndSettle();
  }

  testWidgets('an info message floats with its icon and text', (tester) async {
    await show(tester, nataToast('Nothing to send right now.'));
    expect(find.byKey(const ValueKey('toast-info')), findsOneWidget);
    expect(find.text('Nothing to send right now.'), findsOneWidget);
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('a success message has a check', (tester) async {
    await show(tester, nataToast('Code texted.', tone: ToastTone.success));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('an error message has its own icon', (tester) async {
    await show(tester, nataToast('Failed.', tone: ToastTone.error));
    expect(find.byKey(const ValueKey('toast-error')), findsOneWidget);
    expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
  });

  testWidgets('an action runs when tapped', (tester) async {
    var retried = 0;
    await show(
      tester,
      nataToast(
        'Failed.',
        tone: ToastTone.error,
        actionLabel: 'Retry',
        onAction: () => retried++,
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retried, 1);
  });
}
