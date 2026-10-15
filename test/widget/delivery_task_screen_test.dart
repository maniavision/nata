import 'dart:typed_data';
import 'package:carrywise_app/screens/delivery_confirm_screen.dart';
import 'package:carrywise_app/screens/delivery_task_screen.dart';
import 'package:carrywise_app/screens/requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';

const delivery = AcceptedDelivery(
  orderId: 'DEL-8842',
  senderName: 'Sarah Adeleke',
  senderPhotoUrl: 'https://example.com/sarah.jpg',
  senderSubtitle: 'Sender · Escrow Funded',
  senderPhone: '+234 803 555 0142',
  payout: '\$38.00',
  trip: 'Lagos (LOS) → London (LHR)',
  routeCodes: 'LOS → LHR',
  travelDate: 'Jun 22, 2025',
  destinationCity: 'London',
  itemSummary: 'iPad Mini (Sealed Box · 0.6 kg)',
  itemName: 'iPad Mini 64GB (Space Gray)',
  itemDetails: 'Factory Sealed Box · 0.60 kg · 20 × 14 × 4 cm',
  receivedPhotoUrl: 'https://example.com/box.jpg',
  receivedPhotoName: 'received_sealed_box.jpg',
  receivedPhotoCaption: 'Captured at Lagos Airport · Jun 22, 10:14 AM',
  recipientName: 'David Adeleke (London)',
  recipientPhone: '+44 7700 900456',
  meetingSpot: 'LHR Terminal 4 Arrivals Lounge',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(
    WidgetTester tester, {
    PhotoPicker? picker,
    Locale locale = const Locale('en'),
  }) async {
    bigScreen(tester);
    await tester.pumpWidget(
      appWrapper(
        DeliveryTaskScreen(delivery: delivery, photoPicker: picker),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  group('DeliveryTaskScreen', () {
    testWidgets('shows the order, sender, payout and route', (tester) async {
      await pump(tester);

      expect(find.text('Delivery Task Details'), findsOneWidget);
      expect(find.text('Order #DEL-8842'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Sarah Adeleke'), findsOneWidget);
      expect(find.text('Sender · Verified Identity'), findsOneWidget);
      expect(find.text('YOUR PAYOUT'), findsOneWidget);
      expect(find.textContaining('\$38.00'), findsWidgets);
      expect(find.text('LOS → LHR'), findsOneWidget);
      expect(find.text('Jun 22, 2025'), findsOneWidget);
    });

    testWidgets('shows the item and both proof steps', (tester) async {
      await pump(tester);

      expect(find.text('ITEM TO CARRY'), findsOneWidget);
      expect(find.text('iPad Mini 64GB (Space Gray)'), findsOneWidget);
      expect(find.text('Item Received from Sender'), findsOneWidget);
      expect(find.text('received_sealed_box.jpg'), findsOneWidget);
      expect(find.text('Item Delivered to Recipient'), findsOneWidget);
      expect(find.text('Pending Delivery'), findsOneWidget);
      expect(find.textContaining('at the London destination'), findsOneWidget);
      expect(find.text('David Adeleke (London)'), findsOneWidget);
      expect(find.text('+44 7700 900456'), findsOneWidget);
      expect(find.text('LHR Terminal 4 Arrivals Lounge'), findsOneWidget);
      expect(
        find.text('Confirm Delivery & Claim \$38.00 Payout'),
        findsOneWidget,
      );
    });

    testWidgets('Confirm Delivery & Claim opens the payout release', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('delivery-task-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryConfirmScreen), findsOneWidget);
      expect(find.text('Delivery & Payout Release'), findsOneWidget);
    });

    testWidgets('attaching the handover photo marks step 2 attached', (
      tester,
    ) async {
      // A 1x1 transparent PNG.
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);
      await pump(tester, picker: (_) async => png);

      await tester.tap(find.byKey(const ValueKey('delivery-task-handover')));
      await tester.pump();

      expect(find.text('Handover photo attached'), findsOneWidget);
      expect(find.text('Pending Delivery'), findsNothing);
      expect(find.text('Attached'), findsNWidgets(2));
    });

    testWidgets('a cancelled photo pick changes nothing', (tester) async {
      await pump(tester, picker: (_) async => null);

      await tester.tap(find.byKey(const ValueKey('delivery-task-handover')));
      await tester.pump();

      expect(find.text('Pending Delivery'), findsOneWidget);
    });

    testWidgets('is translated', (tester) async {
      await pump(tester, locale: const Locale('fr'));

      expect(find.text('Détails de la livraison'), findsOneWidget);
      expect(find.text('Commande n° DEL-8842'), findsOneWidget);
    });
  });

  group('from the Requests page', () {
    Future<void> openRequests(WidgetTester tester) async {
      bigScreen(tester);
      await tester.pumpWidget(appWrapper(const RequestsScreen()));
      await tester.pump();
    }

    testWidgets('tapping the accepted request opens its details', (
      tester,
    ) async {
      await openRequests(tester);

      await tester.tap(find.text('Sarah Adeleke'));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryTaskScreen), findsOneWidget);
      expect(find.text('Order #DEL-8842'), findsOneWidget);
    });

    testWidgets('so does Manage Delivery & Attach Proof', (tester) async {
      await openRequests(tester);

      await tester.tap(find.byKey(const ValueKey('manage-delivery')));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryTaskScreen), findsOneWidget);
    });

    testWidgets('back returns to the Requests page', (tester) async {
      await openRequests(tester);
      await tester.tap(find.text('Sarah Adeleke'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('delivery-task-back')));
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryTaskScreen), findsNothing);
      expect(find.byType(RequestsScreen), findsOneWidget);
    });
  });
}
