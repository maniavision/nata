import 'package:carrywise_app/screens/chat_thread_screen.dart';
import 'package:carrywise_app/screens/cost_estimate_screen.dart';
import 'package:carrywise_app/services/message_service.dart';
import 'package:carrywise_app/widgets/price_calculator_tip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_wrapper.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final fromThem = sampleMessage(
    id: 'm1',
    author: 'other-1',
    body: 'Hi! Can you carry my parcel?',
    createdAt: DateTime(2030, 6, 14, 18, 5),
  );
  final fromMe = sampleMessage(
    id: 'm2',
    author: meId,
    body: 'Yes, I have space.',
    createdAt: DateTime(2030, 6, 14, 18, 8),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PriceCalculatorTip.enabled = true;
    PriceCalculatorTip.calculator = (_) =>
        const Scaffold(body: Text('calculator'));
  });
  tearDown(() {
    PriceCalculatorTip.calculator = (_) => const CostEstimateScreen();
  });

  Future<void> open(
    WidgetTester tester, {
    required List<ChatMessage> messages,
    ConversationSummary? conversation,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final conv = conversation ?? sampleConversation(id: 'conv-1');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      appWrapper(
        ChatThreadScreen(
          conversation: conv,
          service: FakeMessageService(
            conversations: [conv],
            messages: {conv.id: messages},
          ),
          now: () => DateTime(2030, 6, 15, 12),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  final tip = find.byKey(const ValueKey('price-tip'));

  testWidgets('once both have written, the calculator is suggested', (
    tester,
  ) async {
    await open(tester, messages: [fromThem, fromMe]);
    expect(tip, findsOneWidget);
    expect(find.text('Agree on a fair price'), findsOneWidget);
    expect(
      find.textContaining('what to offer for this delivery'),
      findsOneWidget,
    );
    expect(find.textContaining('you and the traveler decide'), findsOneWidget);
  });

  testWidgets('the traveler is asked what to charge', (tester) async {
    await open(
      tester,
      messages: [fromThem, fromMe],
      conversation: sampleConversation(id: 'conv-1', iAmTraveler: true),
    );
    expect(
      find.textContaining('what to charge for this delivery'),
      findsOneWidget,
    );
    expect(find.textContaining('you and the sender decide'), findsOneWidget);
  });

  testWidgets('not while only one of them has written', (tester) async {
    await open(tester, messages: [fromThem]);
    expect(tip, findsNothing);
    await open(tester, messages: [fromMe]);
    expect(tip, findsNothing);
    await open(tester, messages: []);
    expect(tip, findsNothing);
  });

  testWidgets('its button opens the calculator', (tester) async {
    await open(tester, messages: [fromThem, fromMe]);
    await tester.tap(find.byKey(const ValueKey('price-tip-open')));
    await tester.pumpAndSettle();
    expect(tip, findsNothing);
    expect(find.text('calculator'), findsOneWidget);
  });

  testWidgets('shown only once per conversation', (tester) async {
    await open(tester, messages: [fromThem, fromMe]);
    await tester.tap(find.byKey(const ValueKey('price-tip-close')));
    await tester.pumpAndSettle();
    expect(tip, findsNothing);

    await open(tester, messages: [fromThem, fromMe]);
    expect(tip, findsNothing);

    // Another conversation still gets it.
    await open(
      tester,
      messages: [fromThem, fromMe],
      conversation: sampleConversation(id: 'conv-2'),
    );
    expect(tip, findsOneWidget);
  });

  testWidgets('not after the delivery', (tester) async {
    await open(
      tester,
      messages: [fromThem, fromMe],
      conversation: sampleConversation(id: 'conv-1', status: 'delivered'),
    );
    expect(tip, findsNothing);
  });

  testWidgets('in French', (tester) async {
    await open(
      tester,
      messages: [fromThem, fromMe],
      locale: const Locale('fr'),
    );
    expect(find.text('Fixez un prix juste'), findsOneWidget);
    expect(find.text('Ouvrir le calculateur'), findsOneWidget);
  });
}
