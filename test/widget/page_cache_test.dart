import 'dart:async';

import 'package:carrywise_app/screens/chat_thread_screen.dart';
import 'package:carrywise_app/screens/notifications_screen.dart';
import 'package:carrywise_app/screens/wallet_screen.dart';
import 'package:carrywise_app/services/message_service.dart';
import 'package:carrywise_app/services/notification_service.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:carrywise_app/services/screen_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

/// Notifications, a chat and the Wallet show what they had last time
/// straight away, while the server is still answering, then the latest.
class _SlowNotifications extends FakeNotificationService {
  _SlowNotifications({super.items});
  Completer<void> gate = Completer<void>();

  @override
  Future<List<AppNotification>> list({int limit = 100}) async {
    await gate.future;
    return super.list(limit: limit);
  }
}

class _SlowMessages extends FakeMessageService {
  _SlowMessages({super.messages});
  Completer<void> gate = Completer<void>();

  @override
  Future<List<ChatMessage>> messages(
    String conversationId, {
    int limit = 300,
  }) async {
    await gate.future;
    return super.messages(conversationId, limit: limit);
  }
}

class _SlowPayments extends FakePaymentService {
  Completer<void> gate = Completer<void>();

  @override
  Future<List<WalletEntry>> walletHistory({int limit = 100}) async {
    await gate.future;
    return super.walletHistory(limit: limit);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Notifications: shown at once the second time', (tester) async {
    bigScreen(tester);
    final service = _SlowNotifications(
      items: [sampleNotification(title: 'Your parcel was picked up')],
    )..gate.complete();
    await tester.pumpWidget(appWrapper(NotificationsScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.text('Your parcel was picked up'), findsOneWidget);

    // Reopened while the server is slow: no spinner, the list is there.
    service.gate = Completer<void>();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(appWrapper(NotificationsScreen(service: service)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Your parcel was picked up'), findsOneWidget);

    // Then the latest replaces it.
    service.items = [sampleNotification(id: 'n2', title: 'Payment received')];
    service.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Payment received'), findsOneWidget);
    expect(find.text('Your parcel was picked up'), findsNothing);
  });

  testWidgets('Notifications: Home can load them before a first visit', (
    tester,
  ) async {
    await NotificationsScreen.preload(
      FakeNotificationService(items: [sampleNotification(title: 'Ready')]),
    );
    bigScreen(tester);
    final slow = _SlowNotifications();
    await tester.pumpWidget(appWrapper(NotificationsScreen(service: slow)));
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    slow.gate.complete();
  });

  testWidgets('a chat shows its messages at once when reopened', (
    tester,
  ) async {
    bigScreen(tester);
    final conv = sampleConversation(id: 'c1');
    final service = _SlowMessages(
      messages: {
        'c1': [sampleMessage(body: 'See you at the airport')],
      },
    )..gate.complete();
    Widget chat() => appWrapper(
      ChatThreadScreen(
        conversation: conv,
        service: service,
        now: () => DateTime(2030, 6, 15, 12),
      ),
    );
    await tester.pumpWidget(chat());
    await tester.pumpAndSettle();
    expect(find.text('See you at the airport'), findsOneWidget);

    service.gate = Completer<void>();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(chat());
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('See you at the airport'), findsOneWidget);
    service.gate.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('each chat keeps its own messages', (tester) async {
    ScreenCache.write('chat:c1', [sampleMessage(body: 'From chat one')]);
    bigScreen(tester);
    final service = _SlowMessages();
    await tester.pumpWidget(
      appWrapper(
        ChatThreadScreen(
          conversation: sampleConversation(id: 'c2'),
          service: service,
          now: () => DateTime(2030, 6, 15, 12),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('From chat one'), findsNothing);
    service.gate.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Wallet shows its balance and activity at once', (
    tester,
  ) async {
    bigScreen(tester);
    final payments = _SlowPayments()
      ..history = [
        WalletEntry(
          kind: WalletEntryKind.payout,
          id: 'p1',
          amount: 45,
          currency: 'USD',
          status: WalletEntryStatus.paid,
          date: DateTime(2025, 6, 20),
          item: 'iPad Mini',
        ),
      ]
      ..gate.complete();
    Widget wallet(FakeAuthService auth) =>
        appWrapper(WalletScreen(authService: auth, paymentService: payments));
    await tester.pumpWidget(wallet(FakeAuthService()));
    await tester.pumpAndSettle();
    expect(find.text(r'$320.00'), findsOneWidget);
    expect(find.textContaining('iPad Mini'), findsOneWidget);

    // Reopened: the balance and the activity are there before any answer.
    payments.gate = Completer<void>();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(wallet(_NeverAnswers()));
    await tester.pump();
    expect(find.text(r'$320.00'), findsOneWidget);
    expect(find.textContaining('iPad Mini'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    payments.gate.complete();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a different member starts with nothing kept', (tester) async {
    ScreenCache.write(NotificationsScreen.cacheKey, [
      sampleNotification(title: 'Someone else'),
    ]);
    ScreenCache.userId = () => 'another-user';
    bigScreen(tester);
    final slow = _SlowNotifications();
    await tester.pumpWidget(appWrapper(NotificationsScreen(service: slow)));
    await tester.pump();
    expect(find.text('Someone else'), findsNothing);
    slow.gate.complete();
    await tester.pumpAndSettle();
  });
}

/// An account whose balance never arrives (the server is slow).
class _NeverAnswers extends FakeAuthService {
  @override
  Future<Map<String, double>> getWalletBalances() =>
      Completer<Map<String, double>>().future;
}
