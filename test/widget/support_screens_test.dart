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

  final List<String> depositPaidIds = [];

  @override
  Future<void> payDepositToSender(String disputeId, String note) async =>
      depositPaidIds.add(disputeId);

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

  List<SupportChatReport> openReports = [];
  List<SupportChatReport> reviewedReports = [];
  List<SupportReportMessage> conversation = [];
  final List<({String id, String note})> reviewed = [];

  @override
  Future<List<SupportChatReport>> chatReports({required bool open}) async =>
      open ? openReports : reviewedReports;

  @override
  Future<List<SupportReportMessage>> reportMessages(String reportId) async =>
      conversation;

  @override
  Future<void> reviewReport(String reportId, String note) async =>
      reviewed.add((id: reportId, note: note));
}

SupportChatReport chatReport({String id = 'cr1', int count = 1}) =>
    SupportChatReport(
      id: id,
      reason: 'scam',
      note: 'Wanted me to pay him directly.',
      messageBody: 'Send the money to my bank instead',
      isOpen: true,
      reviewNote: '',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      reviewedAt: null,
      conversationId: 'c1',
      requestId: 'r1',
      reporterId: 'u-amara',
      reportedId: 'u-kwame',
      reporterName: 'Amara Mensah',
      reporterAvatar: null,
      reportedName: 'Kwame Boateng',
      reportedAvatar: null,
      reportedCount: count,
      blocked: true,
    );

SupportProblem problem({
  String id = 'd1',
  String paymentStatus = 'held',
  String status = 'open',
  String depositStatus = '',
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
  depositAmount: depositStatus.isEmpty ? null : 450,
  depositCurrency: depositStatus.isEmpty ? '' : 'USD',
  depositStatus: depositStatus,
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

  testWidgets('a held deposit can be paid to the sender, after confirming', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      appWrapper(
        SupportProblemDetailScreen(
          problem: problem(depositStatus: 'held'),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'Deposit $450 · held'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-pay-deposit')));
    await tester.pumpAndSettle();
    expect(service.depositPaidIds, isEmpty);
    expect(
      find.byKey(const ValueKey('support-pay-deposit-confirm')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('support-pay-deposit-confirm-button')),
    );
    await tester.pumpAndSettle();
    expect(service.depositPaidIds, ['d1']);
  });

  testWidgets('no deposit, or one refunded: nothing to pay', (tester) async {
    tall(tester);
    for (final status in ['', 'refunded']) {
      await tester.pumpWidget(
        appWrapper(
          SupportProblemDetailScreen(
            key: ValueKey(status),
            problem: problem(depositStatus: status),
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-pay-deposit')), findsNothing);
    }
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

  testWidgets('the dashboard counts open chat reports', (tester) async {
    tall(tester);
    service.summaryValue = const SupportSummary(
      openProblems: 0,
      lockedDeliveries: 0,
      failedPayments: 0,
      openReports: 3,
    );
    await tester.pumpWidget(appWrapper(SupportScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('CHAT REPORTS'), findsOneWidget);
    expect(find.byKey(const ValueKey('support-reports')), findsOneWidget);
  });

  testWidgets('a chat report opens with the conversation and is reviewed', (
    tester,
  ) async {
    tall(tester);
    service.openReports = [chatReport(count: 2)];
    service.conversation = [
      SupportReportMessage(
        id: 'm1',
        authorId: 'u-kwame',
        body: 'Send the money to my bank instead',
        hasPhoto: false,
        createdAt: DateTime(2026, 10, 20, 9),
      ),
      SupportReportMessage(
        id: 'm2',
        authorId: 'u-amara',
        body: 'No, I paid in the app.',
        hasPhoto: false,
        createdAt: DateTime(2026, 10, 20, 9, 5),
      ),
    ];
    await tester.pumpWidget(appWrapper(SupportReportsScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Kwame Boateng'), findsOneWidget);
    expect(find.text('Scam or asking to pay outside Nata'), findsOneWidget);
    expect(find.text('Reported 2 times'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('report-cr1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-message-body')), findsOneWidget);
    expect(find.text('No, I paid in the app.'), findsOneWidget);
    expect(find.text('Blocked by the reporter'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('report-review-note')),
      'Warned the traveler.',
    );
    final button = find.byKey(const ValueKey('report-mark-reviewed'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(service.reviewed.single, (id: 'cr1', note: 'Warned the traveler.'));
  });

  testWidgets('no chat reports says so', (tester) async {
    await tester.pumpWidget(appWrapper(SupportReportsScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reports-empty')), findsOneWidget);
  });
}
