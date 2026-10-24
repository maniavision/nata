import 'package:carrywise_app/screens/support_screens.dart';
import 'package:carrywise_app/services/support_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_wrapper.dart';

class FakeSupportService extends Fake implements SupportService {
  SupportSummary summaryValue = const SupportSummary(
    openProblems: 1,
    lockedDeliveries: 1,
    failedPayments: 1,
  );
  List<SupportActivity> activity = [];
  List<SupportProblem> open = [];
  List<SupportProblem> resolved = [];
  List<FailedPayment> failed = [];
  List<LockedDelivery> locked = [];
  bool fail = false;
  String retryResult = 'pending';

  final List<String> resolvedIds = [];
  final List<String> refundedIds = [];
  final List<String> retried = [];
  final List<String> unlocked = [];

  @override
  Future<SupportSummary> summary() async {
    if (fail) throw StateError('summary failed');
    return summaryValue;
  }

  @override
  Future<List<SupportActivity>> recentActivity({int limit = 10}) async =>
      activity;

  @override
  Future<List<SupportProblem>> problems({required bool open}) async =>
      open ? this.open : resolved;

  @override
  Future<void> resolve(String disputeId, String note) async =>
      resolvedIds.add(disputeId);

  @override
  Future<void> refundSender(String disputeId, String note) async =>
      refundedIds.add(disputeId);

  @override
  Future<({String? pickup, String? handover})> photos(String requestId) async =>
      (pickup: null, handover: null);

  @override
  Future<List<FailedPayment>> failedPayments() async => failed;

  @override
  Future<String> retry(FailedPayment p) async {
    retried.add(p.id);
    return retryResult;
  }

  @override
  Future<List<LockedDelivery>> lockedDeliveries() async => locked;

  @override
  Future<void> unlock(String requestId) async => unlocked.add(requestId);
}

SupportProblem problem({
  String id = 'd1',
  String paymentStatus = 'held',
  String status = 'open',
}) => SupportProblem(
  disputeId: id,
  requestId: 'r1',
  reason: 'damaged',
  details: 'The box was crushed on one corner.',
  status: status,
  resolution: '',
  reportedBySender: false,
  reporterName: 'Daniel O.',
  senderName: 'Amara K.',
  senderPhone: '2348030000000',
  travelerName: 'Daniel O.',
  travelerPhone: '2348031111111',
  route: 'Lagos → New York',
  itemName: 'Sony WH-1000XM5',
  amount: 80,
  currency: 'USD',
  paymentStatus: paymentStatus,
  payoutStatus: '',
  paidAt: DateTime(2026, 6, 18),
  pickedUpAt: DateTime(2026, 6, 19),
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late FakeSupportService service;
  setUp(() => service = FakeSupportService());

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the dashboard shows the three counts', (tester) async {
    tall(tester);
    service.summaryValue = const SupportSummary(
      openProblems: 4,
      lockedDeliveries: 1,
      failedPayments: 2,
    );
    await tester.pumpWidget(appWrapper(SupportScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('REPORTED PROBLEMS'), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
    expect(find.text('No support actions yet.'), findsOneWidget);
  });

  testWidgets('a dashboard that fails to load says so', (tester) async {
    service.fail = true;
    await tester.pumpWidget(appWrapper(SupportScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-error')), findsOneWidget);
  });

  testWidgets('problems open in detail and can be resolved', (tester) async {
    tall(tester);
    service.open = [problem()];
    await tester.pumpWidget(
      appWrapper(SupportProblemsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sony WH-1000XM5'), findsOneWidget);
    expect(find.text('REPORTED BY TRAVELER'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('problem-d1')));
    await tester.pumpAndSettle();

    expect(find.text('Problem Detail'), findsOneWidget);
    expect(find.text('The box was crushed on one corner.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('support-note')),
      'Traveler cleared.',
    );
    await tester.tap(find.byKey(const ValueKey('support-resolve')));
    await tester.pumpAndSettle();

    expect(service.resolvedIds, ['d1']);
  });

  testWidgets('refunding asks to confirm first', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      appWrapper(
        SupportProblemDetailScreen(problem: problem(), service: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('support-refund')));
    await tester.pumpAndSettle();
    expect(find.text('Refund \$80 to Amara K.?'), findsOneWidget);
    expect(service.refundedIds, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('support-refund-confirm-button')),
    );
    await tester.pumpAndSettle();
    expect(service.refundedIds, ['d1']);
  });

  testWidgets('money already paid out cannot be refunded', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      appWrapper(
        SupportProblemDetailScreen(
          problem: problem(paymentStatus: 'released'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-refund')), findsNothing);
    expect(find.byKey(const ValueKey('support-resolve')), findsOneWidget);
  });

  testWidgets('a failed payout can be retried', (tester) async {
    tall(tester);
    service.failed = [
      FailedPayment(
        kind: FailedPaymentKind.payout,
        id: 'p1',
        requestId: 'r1',
        personName: 'Daniel O.',
        amount: 153229,
        currency: 'NGN',
        reason: 'Recipient wallet is not active.',
        updatedAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(
      appWrapper(SupportPaymentsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Reason: "Recipient wallet is not active."'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('retry-p1')));
    await tester.pumpAndSettle();
    expect(service.retried, ['p1']);
    expect(
      find.text('Payout queued again. It goes out within 15 minutes.'),
      findsOneWidget,
    );
  });

  testWidgets('a locked delivery is unlocked after confirming', (tester) async {
    tall(tester);
    service.locked = const [
      LockedDelivery(
        requestId: 'r9',
        travelerName: 'Daniel O.',
        senderName: 'Amara K.',
        route: 'Lagos → New York',
        itemName: 'Sony WH-1000XM5',
        attempts: 5,
      ),
    ];
    await tester.pumpWidget(
      appWrapper(SupportPaymentsScreen(service: service, startOnLocks: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('5/5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unlock-r9')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock this delivery?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unlock-confirm')));
    await tester.pumpAndSettle();
    expect(service.unlocked, ['r9']);
  });

  testWidgets('empty lists say there is nothing to do', (tester) async {
    await tester.pumpWidget(
      appWrapper(SupportPaymentsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('failed-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payments-locked-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('locked-empty')), findsOneWidget);
  });
}
