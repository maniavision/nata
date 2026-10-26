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
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse('$v').toLocal();
double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
String _str(Object? v) => (v as String?)?.trim() ?? '';

class SupportSummary {
  final int openProblems;
  final int lockedDeliveries;
  final int failedPayments;

  const SupportSummary({
    required this.openProblems,
    required this.lockedDeliveries,
    required this.failedPayments,
  });

  factory SupportSummary.fromJson(Map<String, dynamic> j) => SupportSummary(
    openProblems: (j['open_problems'] as num?)?.toInt() ?? 0,
    lockedDeliveries: (j['locked_deliveries'] as num?)?.toInt() ?? 0,
    failedPayments: (j['failed_payments'] as num?)?.toInt() ?? 0,
  );
}

/// One support action: resolved, refunded, payout_retried, refund_retried
/// or unlocked.
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
