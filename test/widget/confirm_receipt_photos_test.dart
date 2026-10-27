import 'package:carrywise_app/screens/confirm_receipt_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The sender sees the traveler's handover photos (up to 3) before
/// confirming they received the item.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, List<String> handover) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final service = FakeRequestService()
      ..photoUrls = (pickup: const [], handover: handover);
    await tester.pumpWidget(
      appWrapper(
        ConfirmReceiptScreen(
          request: sampleSentRequest(status: 'delivered'),
          service: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('one handover photo shows large', (tester) async {
    await pump(tester, ['https://x/1.jpg']);

    expect(
      find.byKey(const ValueKey('receipt-handover-photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('receipt-handover-photo-0')),
      findsNothing,
    );
  });

  testWidgets('several show side by side', (tester) async {
    await pump(tester, [
      'https://x/1.jpg',
      'https://x/2.jpg',
      'https://x/3.jpg',
    ]);

    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('receipt-handover-photo-$i')), findsOneWidget);
    }
  });

  testWidgets('no photo, no space for one', (tester) async {
    await pump(tester, const []);

    expect(find.byKey(const ValueKey('receipt-handover-photo')), findsNothing);
  });
}
