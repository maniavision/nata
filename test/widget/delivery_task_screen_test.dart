import 'package:carrywise_app/screens/delivery_confirm_screen.dart';
import 'package:carrywise_app/screens/delivery_task_screen.dart';
import 'package:carrywise_app/screens/recipient_chat_screen.dart';
import 'package:carrywise_app/services/request_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// The traveler's delivery: pick the item up, then hand it over with the
/// recipient's code (on Delivery & Payout Release).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeRequestService service;
  bool? popped;

  /// What the camera returns next (null: the traveler cancelled).
  Uint8List? nextPhoto;
  var photosTaken = 0;

  setUp(() {
    service = FakeRequestService();
    popped = null;
    nextPhoto = kTransparentPng;
    photosTaken = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    AcceptedDelivery delivery, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      appWrapper(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => DeliveryTaskScreen(
                      delivery: delivery,
                      requestService: service,
                      photoPicker: (_) async {
                        photosTaken++;
                        return nextPhoto;
                      },
                      paymentService: FakePaymentService(
                        accounts: [samplePayoutAccount()],
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ElevatedButton confirmButton(WidgetTester t) => t.widget<ElevatedButton>(
    find.byKey(const ValueKey('delivery-task-confirm')),
  );

  Future<void> attachHandover(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('delivery-task-attach-handover')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the order, sender, payout, route and item', (
    tester,
  ) async {
    await pump(tester, sampleDelivery());

    expect(find.text('Delivery Task Details'), findsOneWidget);
    expect(find.text('Order #DEL-8842'), findsOneWidget);
    expect(find.text('Sarah Adeleke'), findsOneWidget);
    expect(find.text('LOS → LHR'), findsOneWidget);
    expect(find.text('iPad Mini 64GB (Space Gray)'), findsOneWidget);
    expect(find.text('David Adeleke (London)'), findsOneWidget);
    expect(find.text('LHR Terminal 4 Arrivals Lounge'), findsOneWidget);
  });

  testWidgets('the recipient\'s name is shown, never their phone', (
    tester,
  ) async {
    await pump(tester, sampleDelivery());

    expect(find.text('David Adeleke (London)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-task-call-recipient')),
      findsNothing,
    );
    expect(find.textContaining('7700 900456'), findsNothing);
  });

  testWidgets('Message David opens the chat with the recipient', (
    tester,
  ) async {
    await pump(tester, sampleDelivery());

    expect(find.text('Message David'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('delivery-task-message-recipient')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecipientChatScreen), findsOneWidget);
  });

  testWidgets('before pickup: confirming delivery is locked', (tester) async {
    await pump(tester, sampleDelivery());

    expect(find.text('Not yet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-task-picked-up')),
      findsOneWidget,
    );
    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets("\"I've picked up the item\" records it and unlocks the code", (
    tester,
  ) async {
    await pump(tester, sampleDelivery());

    await tester.tap(find.byKey(const ValueKey('delivery-task-picked-up')));
    await tester.pumpAndSettle();

    // The sealed box is photographed first.
    expect(photosTaken, 1);
    expect(service.photos, [
      (id: 'req-1', kind: DeliveryPhotoKind.pickup, count: 1),
    ]);
    expect(
      find.byKey(const ValueKey('delivery-task-pickup-photo-0')),
      findsOneWidget,
    );
    expect(service.pickedUp, ['req-1']);
    expect(find.text('Picked up'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-task-picked-up-at')),
      findsOneWidget,
    );
    // Still locked until the handover photo is attached.
    expect(confirmButton(tester).onPressed, isNull);
    await attachHandover(tester);
    expect(confirmButton(tester).onPressed, isNotNull);

    // Requests reloads on return.
    await tester.tap(find.byKey(const ValueKey('delivery-task-back')));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
  });

  testWidgets('no photo, no pickup', (tester) async {
    nextPhoto = null;
    await pump(tester, sampleDelivery());

    await tester.tap(find.byKey(const ValueKey('delivery-task-picked-up')));
    await tester.pumpAndSettle();

    expect(photosTaken, 1);
    expect(service.photos, isEmpty);
    expect(service.pickedUp, isEmpty);
    expect(find.text('Not yet'), findsOneWidget);
  });

  testWidgets('a failed pickup is explained and can be retried', (
    tester,
  ) async {
    service.failPickUp = const RequestException(RequestFailure.other);
    await pump(tester, sampleDelivery());

    await tester.tap(find.byKey(const ValueKey('delivery-task-picked-up')));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't mark it as picked up. Please try again."),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('delivery-task-picked-up')),
      findsOneWidget,
    );
  });

  testWidgets('picked up: Confirm Delivery opens the code entry', (
    tester,
  ) async {
    await pump(tester, samplePickedUpDelivery());

    expect(find.text('Picked up'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);
    await attachHandover(tester);
    expect(find.text('Handover photo attached'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delivery-task-confirm')));
    await tester.pumpAndSettle();

    expect(service.photos, [
      (id: 'req-1', kind: DeliveryPhotoKind.handover, count: 1),
    ]);
    expect(find.byType(DeliveryConfirmScreen), findsOneWidget);
  });

  testWidgets('up to 3 photos of the sealed box go with the pickup', (
    tester,
  ) async {
    await pump(tester, sampleDelivery());
    Finder add() =>
        find.byKey(const ValueKey('delivery-task-add-pickup-photo'));

    for (var i = 0; i < 3; i++) {
      await tester.tap(add());
      await tester.pumpAndSettle();
    }
    expect(photosTaken, 3);
    expect(find.text('3/3'), findsOneWidget);
    // Full: no more room.
    expect(add(), findsNothing);

    await tester.tap(find.byKey(const ValueKey('delivery-task-picked-up')));
    await tester.pumpAndSettle();

    // No extra photo: the three already taken are sent together.
    expect(photosTaken, 3);
    expect(service.photos.length, 3);
    expect(service.photos.every((p) => p.count == 3), isTrue);
    expect(service.pickedUp, ['req-1']);
    // Sent: they can't be removed any more.
    expect(
      find.byKey(const ValueKey('delivery-task-remove-pickup-0')),
      findsNothing,
    );
  });

  testWidgets('a photo can be removed before it is sent', (tester) async {
    await pump(tester, sampleDelivery());
    final add = find.byKey(const ValueKey('delivery-task-add-pickup-photo'));
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('delivery-task-remove-pickup-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-task-pickup-photo-1')),
      findsNothing,
    );
  });

  testWidgets('several handover photos are sent together', (tester) async {
    await pump(tester, samplePickedUpDelivery());

    await attachHandover(tester);
    await tester.tap(
      find.byKey(const ValueKey('delivery-task-add-handover-photo')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delivery-task-confirm')));
    await tester.pumpAndSettle();

    expect(service.photos.length, 2);
    expect(
      service.photos.every(
        (p) => p.kind == DeliveryPhotoKind.handover && p.count == 2,
      ),
      isTrue,
    );
  });

  testWidgets('a failed handover upload is explained', (tester) async {
    await pump(tester, samplePickedUpDelivery());
    await attachHandover(tester);
    service.failPhoto = const RequestException(RequestFailure.other);

    await tester.tap(find.byKey(const ValueKey('delivery-task-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't upload the photo. Please try again."),
      findsOneWidget,
    );
    expect(find.byType(DeliveryConfirmScreen), findsNothing);
  });

  testWidgets('once delivered, it goes back to Requests', (tester) async {
    await pump(tester, samplePickedUpDelivery());
    await attachHandover(tester);
    await tester.tap(find.byKey(const ValueKey('delivery-task-confirm')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      await tester.enterText(
        find.byKey(ValueKey('delivery-confirm-pin-$i')),
        '1234'[i],
      );
    }
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('delivery-confirm-release')),
    );
    await tester.tap(find.byKey(const ValueKey('delivery-confirm-release')));
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryTaskScreen), findsNothing);
    expect(popped, isTrue);
    expect(find.textContaining('Delivered!'), findsOneWidget);
  });

  testWidgets('once delivered, the traveler rates the sender', (tester) async {
    await initializeDateFormatting('en');
    await pump(
      tester,
      AcceptedDelivery.fromIncoming(
        sampleIncoming(
          status: 'handed_off',
          pickedUpAt: DateTime(2030, 6, 22, 8),
        ),
        payout: r'$38',
        locale: 'en',
      ),
    );
    await attachHandover(tester);
    await tester.tap(find.byKey(const ValueKey('delivery-task-confirm')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.enterText(
        find.byKey(ValueKey('delivery-confirm-pin-$i')),
        '1234'[i],
      );
    }
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('delivery-confirm-release')),
    );
    await tester.tap(find.byKey(const ValueKey('delivery-confirm-release')));
    await tester.pumpAndSettle();

    expect(find.byType(DeliveryTaskScreen), findsNothing);
    expect(find.text('Rate Your Sender'), findsOneWidget);
    expect(popped, isTrue);

    await tester.tap(find.byKey(const ValueKey('review-star-5')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('review-submit')));
    await tester.tap(find.byKey(const ValueKey('review-submit')));
    await tester.pumpAndSettle();
    expect(service.senderReviews.single.id, 'in-1');
    expect(find.text('Rate Your Sender'), findsNothing);
  });

  testWidgets('no phone call button without the sender\'s number', (
    tester,
  ) async {
    await pump(
      tester,
      AcceptedDelivery.fromIncoming(
        sampleIncoming(status: 'paid'),
        payout: r'$38',
        locale: 'en',
      ),
    );

    expect(find.byKey(const ValueKey('delivery-task-call')), findsNothing);
    expect(find.byKey(const ValueKey('delivery-task-message')), findsOneWidget);
  });

  testWidgets('is translated', (tester) async {
    await pump(tester, sampleDelivery(), locale: const Locale('fr'));

    expect(find.text('Détails de la livraison'), findsOneWidget);
    expect(find.text("J'ai récupéré l'article"), findsOneWidget);
  });
}
