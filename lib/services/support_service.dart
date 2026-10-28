import 'package:supabase_flutter/supabase_flutter.dart';
import 'signed_urls.dart';

/// Whether the signed-in user is staff. Replaced in tests.
class SupportAccess {
  SupportAccess._();

  static Future<bool> Function() isAdmin = () => SupportService().amIAdmin();
}

/// The Support section for Nata staff (20240154_support_tools.sql). Every
/// call is refused with nata:not_admin for anyone not in nata.admins.
class SupportService {
  final SupabaseClient _client;

  SupportService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  static const _photoBucket = 'handover-photos';

  /// Whether the signed-in user is staff (Profile shows the Support row).
  Future<bool> amIAdmin() async {
    if (_client.auth.currentUser == null) return false;
    final result = await _client.rpc('am_i_admin');
    return result == true;
  }

  Future<SupportSummary> summary() async {
    final rows = await _client.rpc('support_summary') as List;
    return SupportSummary.fromJson(
      Map<String, dynamic>.from(rows.single as Map),
    );
  }

  Future<List<SupportActivity>> recentActivity({int limit = 10}) async {
    final rows =
        await _client.rpc('support_recent_activity', params: {'p_limit': limit})
            as List;
    return [
      for (final r in rows)
        SupportActivity.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Open (and under review) problems, or resolved ones. Newest first.
  Future<List<SupportProblem>> problems({required bool open}) async {
    final rows =
        await _client.rpc('support_problems', params: {'p_open': open}) as List;
    return [
      for (final r in rows)
        SupportProblem.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> resolve(String disputeId, String note) => _client.rpc(
    'support_resolve',
    params: {'p_dispute': disputeId, 'p_note': note},
  );

  /// Refunds the sender in full while the money is still held, and resolves
  /// the problem. The refund goes out with the next payment job.
  Future<void> refundSender(String disputeId, String note) => _client.rpc(
    'support_refund_sender',
    params: {'p_dispute': disputeId, 'p_note': note},
  );

  /// The pickup and handover photos, as short-lived links.
  Future<({String? pickup, String? handover})> photos(String requestId) async {
    final rows =
        await _client.rpc(
              'support_delivery_photos',
              params: {'p_request': requestId},
            )
            as List;
    if (rows.isEmpty) return (pickup: null, handover: null);
    final r = Map<String, dynamic>.from(rows.first as Map);
    Future<String?> url(String? path) async => path == null
        ? null
        : await SignedUrls.get(
            _photoBucket,
            path,
            lifetime: const Duration(seconds: 600),
            create: () =>
                _client.storage.from(_photoBucket).createSignedUrl(path, 600),
          );
    return (
      pickup: await url(r['pickup_photo_path'] as String?),
      handover: await url(r['handover_photo_path'] as String?),
    );
  }

  Future<List<FailedPayment>> failedPayments() async {
    final rows = await _client.rpc('support_failed_payments') as List;
    return [
      for (final r in rows)
        FailedPayment.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Puts a failed payout or refund back for the next payment job (returns
  /// 'pending').
  Future<String> retry(FailedPayment p) async {
    final result = await _client.rpc(
      'support_retry',
      params: {'p_kind': p.kind.wire, 'p_id': p.id},
    );
    return '$result';
  }

  Future<List<LockedDelivery>> lockedDeliveries() async {
    final rows = await _client.rpc('support_locked_deliveries') as List;
    return [
      for (final r in rows)
        LockedDelivery.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> unlock(String requestId) =>
      _client.rpc('support_unlock', params: {'p_request': requestId});

  /// Chat reports (20240190), open ones or reviewed ones, newest first.
  Future<List<SupportChatReport>> chatReports({required bool open}) async {
    final rows =
        await _client.rpc('support_chat_reports', params: {'p_open': open})
            as List;
    return [
      for (final r in rows)
        SupportChatReport.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// The reported conversation's latest messages, oldest first.
  Future<List<SupportReportMessage>> reportMessages(String reportId) async {
    final rows =
        await _client.rpc(
              'support_report_messages',
              params: {'p_report': reportId},
            )
            as List;
    return [
      for (final r in rows)
        SupportReportMessage.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> reviewReport(String reportId, String note) => _client.rpc(
    'support_review_report',
    params: {'p_report': reportId, 'p_note': note},
  );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse('$v').toLocal();
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
String _str(Object? v) => (v as String?)?.trim() ?? '';

class SupportSummary {
  final int openProblems;
  final int lockedDeliveries;
  final int failedPayments;
  final int openReports;

  const SupportSummary({
    required this.openProblems,
    required this.lockedDeliveries,
    required this.failedPayments,
    this.openReports = 0,
  });

  factory SupportSummary.fromJson(Map<String, dynamic> j) => SupportSummary(
    openProblems: (j['open_problems'] as num?)?.toInt() ?? 0,
    lockedDeliveries: (j['locked_deliveries'] as num?)?.toInt() ?? 0,
    failedPayments: (j['failed_payments'] as num?)?.toInt() ?? 0,
    openReports: (j['open_reports'] as num?)?.toInt() ?? 0,
  );
}

/// One support action: resolved, refunded, payout_retried, refund_retried,
/// unlocked or report_reviewed.
class SupportActivity {
  final String action;
  final String subject;
  final String adminName;
  final DateTime createdAt;

  const SupportActivity({
    required this.action,
    required this.subject,
    required this.adminName,
    required this.createdAt,
  });

  factory SupportActivity.fromJson(Map<String, dynamic> j) => SupportActivity(
    action: _str(j['action']),
    subject: _str(j['subject']),
    adminName: _str(j['admin_name']),
    createdAt: _date(j['created_at']) ?? DateTime.now(),
  );
}

class SupportProblem {
  final String disputeId;
  final String requestId;

  /// not_received, damaged, wrong_item, opened or other.
  final String reason;
  final String details;
  final String status;
  final String resolution;
  final bool reportedBySender;
  final String reporterName;
  final String? reporterAvatar;
  final String senderName;
  final String senderPhone;
  final String travelerName;
  final String travelerPhone;
  final String route;
  final String itemName;
  final double amount;
  final String currency;

  /// held, released or refunded; empty without a payment.
  final String paymentStatus;

  /// pending, processing, paid or failed; empty without a payout.
  final String payoutStatus;
  final DateTime? paidAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const SupportProblem({
    required this.disputeId,
    required this.requestId,
    required this.reason,
    required this.details,
    required this.status,
    required this.resolution,
    required this.reportedBySender,
    required this.reporterName,
    this.reporterAvatar,
    required this.senderName,
    required this.senderPhone,
    required this.travelerName,
    required this.travelerPhone,
    required this.route,
    required this.itemName,
    required this.amount,
    required this.currency,
    required this.paymentStatus,
    required this.payoutStatus,
    this.paidAt,
    this.pickedUpAt,
    this.deliveredAt,
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isOpen => status == 'open' || status == 'under_review';

  /// The money can still go back to the sender: held, and not paid out.
  bool get refundable =>
      isOpen &&
      paymentStatus == 'held' &&
      payoutStatus != 'processing' &&
      payoutStatus != 'paid';

  factory SupportProblem.fromJson(Map<String, dynamic> j) => SupportProblem(
    disputeId: _str(j['dispute_id']),
    requestId: _str(j['request_id']),
    reason: _str(j['reason']),
    details: _str(j['details']),
    status: _str(j['status']),
    resolution: _str(j['resolution']),
    reportedBySender: j['reported_by'] == 'sender',
    reporterName: _str(j['reporter_name']),
    reporterAvatar: j['reporter_avatar'] as String?,
    senderName: _str(j['sender_name']),
    senderPhone: _str(j['sender_phone']),
    travelerName: _str(j['traveler_name']),
    travelerPhone: _str(j['traveler_phone']),
    route: _str(j['route']),
    itemName: _str(j['item_name']),
    amount: _num(j['amount']),
    currency: _str(j['currency']),
    paymentStatus: _str(j['payment_status']),
    payoutStatus: _str(j['payout_status']),
    paidAt: _date(j['paid_at']),
    pickedUpAt: _date(j['picked_up_at']),
    deliveredAt: _date(j['delivered_at']),
    createdAt: _date(j['created_at']) ?? DateTime.now(),
    resolvedAt: _date(j['resolved_at']),
  );
}

enum FailedPaymentKind {
  payout('payout'),
  refund('refund');

  const FailedPaymentKind(this.wire);
  final String wire;
}

class FailedPayment {
  final FailedPaymentKind kind;

  /// The payout's id, or the payment's for a refund.
  final String id;
  final String requestId;
  final String personName;
  final double amount;
  final String currency;

  /// The provider's reason (pawaPay, Stripe).
  final String reason;
  final DateTime updatedAt;

  const FailedPayment({
    required this.kind,
    required this.id,
    required this.requestId,
    required this.personName,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.updatedAt,
  });

  factory FailedPayment.fromJson(Map<String, dynamic> j) => FailedPayment(
    kind: j['kind'] == 'refund'
        ? FailedPaymentKind.refund
        : FailedPaymentKind.payout,
    id: _str(j['id']),
    requestId: _str(j['request_id']),
    personName: _str(j['person_name']),
    amount: _num(j['amount']),
    currency: _str(j['currency']),
    reason: _str(j['reason']),
    updatedAt: _date(j['updated_at']) ?? DateTime.now(),
  );
}

class LockedDelivery {
  final String requestId;
  final String travelerName;
  final String senderName;
  final String route;
  final String itemName;
  final int attempts;
  final DateTime? pickedUpAt;

  const LockedDelivery({
    required this.requestId,
    required this.travelerName,
    required this.senderName,
    required this.route,
    required this.itemName,
    required this.attempts,
    this.pickedUpAt,
  });

  factory LockedDelivery.fromJson(Map<String, dynamic> j) => LockedDelivery(
    requestId: _str(j['request_id']),
    travelerName: _str(j['traveler_name']),
    senderName: _str(j['sender_name']),
    route: _str(j['route']),
    itemName: _str(j['item_name']),
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    pickedUpAt: _date(j['picked_up_at']),
  );
}

/// A member reported in chat (`public.support_chat_reports`).
class SupportChatReport {
  final String id;

  /// harassment, scam, spam, inappropriate, unsafe or other.
  final String reason;
  final String note;

  /// What the reported message said (empty when the whole chat was
  /// reported).
  final String messageBody;
  final bool isOpen;
  final String reviewNote;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? conversationId;
  final String? requestId;
  final String reporterId;
  final String reportedId;
  final String reporterName;
  final String? reporterAvatar;
  final String reportedName;
  final String? reportedAvatar;

  /// How many reports the reported member has had in all.
  final int reportedCount;

  /// The reporter blocked them.
  final bool blocked;

  const SupportChatReport({
    required this.id,
    required this.reason,
    required this.note,
    required this.messageBody,
    required this.isOpen,
    required this.reviewNote,
    required this.createdAt,
    required this.reviewedAt,
    required this.conversationId,
    required this.requestId,
    required this.reporterId,
    required this.reportedId,
    required this.reporterName,
    required this.reporterAvatar,
    required this.reportedName,
    required this.reportedAvatar,
    required this.reportedCount,
    required this.blocked,
  });

  factory SupportChatReport.fromJson(Map<String, dynamic> j) =>
      SupportChatReport(
        id: _str(j['id']),
        reason: _str(j['reason']),
        note: _str(j['note']),
        messageBody: _str(j['message_body']),
        isOpen: _str(j['status']) != 'reviewed',
        reviewNote: _str(j['review_note']),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
        reviewedAt: _date(j['reviewed_at']),
        conversationId: j['conversation_id'] as String?,
        requestId: j['request_id'] as String?,
        reporterId: _str(j['reporter_id']),
        reportedId: _str(j['reported_id']),
        reporterName: _str(j['reporter_name']),
        reporterAvatar: j['reporter_avatar'] as String?,
        reportedName: _str(j['reported_name']),
        reportedAvatar: j['reported_avatar'] as String?,
        reportedCount: (j['reported_count'] as num?)?.toInt() ?? 1,
        blocked: (j['blocked'] as bool?) ?? false,
      );
}

/// One message of a reported conversation.
class SupportReportMessage {
  final String id;
  final String authorId;
  final String body;
  final bool hasPhoto;
  final DateTime createdAt;

  const SupportReportMessage({
    required this.id,
    required this.authorId,
    required this.body,
    required this.hasPhoto,
    required this.createdAt,
  });

  factory SupportReportMessage.fromJson(Map<String, dynamic> j) =>
      SupportReportMessage(
        id: _str(j['id']),
        authorId: _str(j['author_id']),
        body: _str(j['body']),
        hasPhoto: (j['has_photo'] as bool?) ?? false,
        createdAt: _date(j['created_at']) ?? DateTime.now(),
      );
}
