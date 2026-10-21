import 'dart:async';
import 'package:flutter/material.dart';
import 'delivery_task_screen.dart';
import 'incoming_request_screen.dart';
import '../services/preferences_service.dart';
import '../services/exchange_rate_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/request_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/avatar_image.dart';
import 'checkout_escrow_screen.dart';
import 'delivery_request_screen.dart';
import 'confirm_receipt_screen.dart';
import 'review_screen.dart';
import 'traveler_results_screen.dart';
import '../l10n/l10n_ext.dart';
import '../widgets/nata_toast.dart';

class RequestsScreen extends StatefulWidget {
  /// Override for tests; defaults to the real [RequestService].
  final RequestService? requestService;

  /// Override for tests; defaults to the real [ExchangeRateService].
  final ExchangeRateService? exchangeRates;

  /// 0 = Incoming, 1 = Outgoing.
  final int initialTab;

  const RequestsScreen({
    super.key,
    this.requestService,
    this.exchangeRates,
    this.initialTab = 0,
  });

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late int _tab = widget.initialTab; // 0 = Incoming, 1 = Outgoing

  /// The user's sent requests (Outgoing); null while loading.
  List<SentRequest>? _sent;
  bool _sentFailed = false;

  /// Delivery codes of the paid requests, to give to the recipient.
  Map<String, DeliveryCode> _codes = const {};
  final Set<String> _texting = {};

  /// Amounts are stored in dollars and shown in the user's currency; dollars
  /// until the rate is known (or if it can't be had).
  PriceFormatter _money = PriceFormatter.usd;

  @override
  void initState() {
    super.initState();
    _loadSent();
    _loadIncoming();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final currency = PreferencesService().currency.code;
    if (currency == 'USD') return;
    try {
      final rates = await (widget.exchangeRates ?? ExchangeRateService())
          .rates();
      if (!mounted) return;
      setState(
        () => _money = PriceFormatter.forCurrency(
          currency,
          rates?.rateFor(currency),
        ),
      );
    } catch (e) {
      debugPrint('[Requests] exchange rates: $e');
    }
  }

  Future<void> _loadSent() async {
    setState(() {
      _sentFailed = false;
      _sent = null;
    });
    try {
      final sent = await (widget.requestService ?? RequestService())
          .myRequests();
      if (mounted) setState(() => _sent = sent);
      _loadCodes(sent);
    } catch (e) {
      debugPrint('[Requests] sent requests: $e');
      if (mounted) {
        setState(() {
          _sent = const [];
          _sentFailed = true;
        });
      }
    }
  }

  Future<void> _loadCodes(List<SentRequest> sent) async {
    final service = widget.requestService ?? RequestService();
    final codes = <String, DeliveryCode>{};
    for (final r in sent.where((r) => r.isPaid)) {
      try {
        final code = await service.deliveryCode(r.id);
        if (code != null) codes[r.id] = code;
      } catch (e) {
        debugPrint('[Requests] delivery code: $e');
      }
    }
    if (mounted) setState(() => _codes = codes);
  }

  /// Texts the delivery code to the recipient.
  Future<void> _textCode(SentRequest r) async {
    if (_texting.contains(r.id)) return;
    setState(() => _texting.add(r.id));
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await (widget.requestService ?? RequestService()).sendDeliveryCode(r.id);
      messenger.showSnackBar(
        nataToast(l.codeTexted(r.recipientName), tone: ToastTone.success),
      );
      final code = _codes[r.id];
      if (code != null && mounted) {
        setState(
          () => _codes = {
            ..._codes,
            r.id: DeliveryCode(code.code, smsSentAt: DateTime.now()),
          },
        );
      }
    } on RequestException catch (e) {
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.smsUnavailable => l.errSmsUnavailable,
          RequestFailure.tooSoon => l.errSmsTooSoon,
          _ => l.errRequestFailed,
        }, tone: ToastTone.error),
      );
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errRequestFailed, tone: ToastTone.error),
      );
    } finally {
      if (mounted) setState(() => _texting.remove(r.id));
    }
  }

  /// Opens checkout for an accepted request; reloads on return (the ticket
  /// check, or a payment, changes the request).
  Future<void> _pay(SentRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckoutEscrowScreen(
          request: request,
          money: _money,
          service: widget.requestService,
        ),
      ),
    );
    if (mounted) _loadSent();
  }

  /// The sender checks the traveler's "delivered" on Confirm Receipt: once
  /// confirmed they rate the traveler; a reported problem just reloads.
  Future<void> _confirmReceipt(SentRequest request) async {
    setState(() => _confirming.add(request.id));
    final outcome = await Navigator.of(context).push<ReceiptOutcome>(
      MaterialPageRoute(
        builder: (_) => ConfirmReceiptScreen(
          request: request,
          service: widget.requestService,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _confirming.remove(request.id));
    if (outcome == ReceiptOutcome.confirmed) {
      await _review(request);
    } else {
      _loadSent();
    }
  }

  /// Opens Rate Your Traveler; reloads afterwards either way, since receipt
  /// may just have been confirmed.
  Future<void> _review(SentRequest request) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            ReviewScreen(request: request, service: widget.requestService),
      ),
    );
    if (mounted) _loadSent();
  }

  /// Requests whose receipt is being confirmed.
  final Set<String> _confirming = {};

  /// Opens a pending request in the request form; reloads once it is saved.
  Future<void> _edit(SentRequest request) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DeliveryRequestScreen(
          trip: request.trip,
          editing: request,
          service: widget.requestService,
        ),
      ),
    );
    if (saved == true && mounted) _loadSent();
  }

  /// Asks for confirmation (showing the fee, if any), cancels the request and
  /// reloads the list.
  Future<void> _cancel(SentRequest request) async {
    final l = context.l10n;
    final fee = request.cancellationFeeNow;
    if (fee == null) return;
    // Fixed in the sender's currency once the traveler accepted.
    final feeText =
        request.fixedCancellationFeeText ??
        (_money.currency == 'USD'
            ? _money.format(fee)
            : '≈ ${_money.format(fee)}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('cancel-request-dialog'),
        title: Text(l.cancelRequestTitle),
        content: Text(
          fee > 0 ? l.cancelRequestFeeBody(feeText) : l.cancelRequestFreeBody,
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel-request-keep'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.keepRequest),
          ),
          TextButton(
            key: const ValueKey('cancel-request-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: Text(fee > 0 ? l.cancelWithFee(feeText) : l.cancelRequest),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final service = widget.requestService ?? RequestService();
    try {
      await service.cancel(request);
      messenger.showSnackBar(
        nataToast(l.requestCancelled, tone: ToastTone.success),
      );
      // Paid: the money (less the fee) goes back right away. If this call
      // fails the refund stays queued and is sent later.
      if (request.isPaid) {
        unawaited(
          service.sendRefunds().catchError(
            (Object e) => debugPrint('[Requests] refunds: $e'),
          ),
        );
      }
    } on RequestException catch (e) {
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.feeChanged => l.errFeeChanged,
          RequestFailure.notCancellable => l.errNotCancellable,
          RequestFailure.notSignedIn => l.errSessionExpired,
          RequestFailure.requestNotFound => l.errRequestNotFound,
          _ => l.errCancelFailed,
        }, tone: ToastTone.error),
      );
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errCancelFailed, tone: ToastTone.error),
      );
    }
    // Reload either way: the status may have changed under us.
    if (mounted) _loadSent();
  }

  // ── Incoming requests (the traveler's side) ────────────────────────────────
  /// Requests made on the user's trips; null while loading.
  List<IncomingRequest>? _incomingAll;
  bool _incomingFailed = false;

  /// Requests acted on just now (accept / decline in flight).
  final Set<String> _busy = {};

  Future<void> _loadIncoming() async {
    try {
      final list = await (widget.requestService ?? RequestService())
          .incomingRequests();
      if (mounted) {
        setState(() {
          _incomingAll = list;
          _incomingFailed = false;
        });
      }
    } catch (e) {
      debugPrint('[Requests] incoming requests: $e');
      if (mounted) {
        setState(() {
          _incomingAll = const [];
          _incomingFailed = true;
        });
      }
    }
  }

  /// Accepted and under way.
  List<IncomingRequest> get _inProgress =>
      (_incomingAll ?? const []).where((r) => r.isInProgress).toList();

  /// Waiting for the traveler's answer.
  List<IncomingRequest> get _pending =>
      (_incomingAll ?? const []).where((r) => r.isPending).toList();

  String _payoutText(IncomingRequest r) {
    final shown = _money.format(r.payoutUsd);
    return _money.currency == 'USD' ? shown : '≈ $shown';
  }

  String _date(DateTime d) =>
      DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);

  Future<void> _openIncoming(IncomingRequest r) async {
    // Paid: the delivery itself (pick up, hand over with the code).
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => r.isPaid
            ? DeliveryTaskScreen(
                delivery: AcceptedDelivery.fromIncoming(
                  r,
                  payout: _payoutText(r),
                  locale: Localizations.localeOf(context).toString(),
                ),
                requestService: widget.requestService,
              )
            : IncomingRequestScreen(
                request: r,
                money: _money,
                service: widget.requestService,
              ),
      ),
    );
    if (changed == true && mounted) _loadIncoming();
  }

  Future<void> _actOn(
    IncomingRequest r,
    Future<bool> Function(BuildContext, RequestService, IncomingRequest) act,
  ) async {
    if (_busy.contains(r.id)) return;
    setState(() => _busy.add(r.id));
    final changed = await act(
      context,
      widget.requestService ?? RequestService(),
      r,
    );
    if (!mounted) return;
    setState(() => _busy.remove(r.id));
    if (changed) _loadIncoming();
  }

  _AcceptedView _acceptedView(IncomingRequest r) {
    final l = context.l10n;
    final weight = NumberFormat(
      '0.##',
      Localizations.localeOf(context).toString(),
    ).format(r.weightKg);
    final (statusLabel, subtitle, next, icon) = switch (r.status) {
      'paid' => (
        l.statusPaid,
        l.senderEscrowFunded,
        l.nextPickUp,
        Icons.inventory_2_rounded,
      ),
      'handed_off' => (
        l.statusInTransit,
        l.senderItemWithYou,
        l.nextDeliver,
        Icons.pin_rounded,
      ),
      'delivered' => (
        l.statusDelivered,
        l.senderDelivered,
        l.nextDone,
        Icons.check_circle_rounded,
      ),
      _ => (
        l.accepted,
        l.senderAwaitingPayment,
        l.nextWaitPayment,
        Icons.hourglass_top_rounded,
      ),
    };
    return _AcceptedView(
      id: r.id,
      senderName: r.senderName,
      avatarPath: r.senderAvatarPath,
      statusLabel: statusLabel,
      subtitle: subtitle,
      payout: _payoutText(r),
      trip: r.routeLabel,
      item: '${r.itemsSummary} ($weight kg)',
      nextAction: next,
      nextIcon: icon,
      // Delivery steps come with the paid / in transit stages.
      buttonLabel: const {'paid', 'handed_off'}.contains(r.status)
          ? l.manageDeliveryAttachProof
          : l.viewRequest,
    );
  }

  _IncomingRequest _pendingView(IncomingRequest r) {
    final weight = NumberFormat(
      '0.##',
      Localizations.localeOf(context).toString(),
    ).format(r.weightKg);
    return _IncomingRequest(
      id: r.id,
      name: r.senderName,
      avatarPath: r.senderAvatarPath,
      subtitle: context.l10n.senderDeliveries(r.senderDeliveries),
      amount: _payoutText(r),
      trip: r.routeLabel,
      date: _date(r.departureDate),
      item: r.itemsSummary,
      weight: [
        '$weight kg',
        if (r.dimensions != null) r.dimensions!,
      ].join(' · '),
      photoCount: r.photoPaths.isEmpty ? null : r.photoPaths.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildTabSwitcher(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    child: _tab == 0
                        ? _buildIncomingSection()
                        : _buildOutgoingSection(),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AppBottomNav(current: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.deliveryRequests,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.foreground,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.filter_list_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab switcher ───────────────────────────────────────────────────────────
  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _tabButton(
              context.l10n.incoming,
              0,
              badge: '${_inProgress.length + _pending.length}',
              badgeBg: AppColors.accent,
            ),
            _tabButton(
              context.l10n.outgoing,
              1,
              badge: '${_sent?.length ?? 0}',
              badgeBg: AppColors.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(
    String label,
    int index, {
    required String badge,
    required Color badgeBg,
  }) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('requests-tab-$index'),
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  color: active
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: active ? badgeBg : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: active && index == 0
                          ? Colors.white
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Incoming section ───────────────────────────────────────────────────────
  Widget _buildIncomingSection() {
    final l = context.l10n;
    final all = _incomingAll;
    if (all == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (_incomingFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.errLoadRequests,
            key: const ValueKey('incoming-error'),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.destructive,
            ),
          ),
          TextButton(
            key: const ValueKey('incoming-retry'),
            onPressed: () {
              setState(() => _incomingAll = null);
              _loadIncoming();
            },
            child: Text(l.retry),
          ),
        ],
      );
    }
    if (all.isEmpty) {
      return Text(
        l.noIncomingRequests,
        key: const ValueKey('incoming-empty'),
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.mutedForeground,
        ),
      );
    }
    final inProgress = _inProgress;
    final pending = _pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inProgress.isNotEmpty) ...[
          _acceptedHeader(),
          const SizedBox(height: 10),
          for (final r in inProgress)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _AcceptedCard(
                request: _acceptedView(r),
                onOpen: () => _openIncoming(r),
              ),
            ),
        ],
        if (pending.isNotEmpty) ...[
          _sectionHeader(
            l.pendingRequestsCount(pending.length),
            l.awaitingYourResponse,
          ),
          const SizedBox(height: 10),
          for (final r in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _IncomingCard(
                request: _pendingView(r),
                busy: _busy.contains(r.id),
                onOpen: () => _openIncoming(r),
                onAccept: () => _actOn(r, IncomingRequestActions.accept),
                onDecline: () => _actOn(r, IncomingRequestActions.decline),
              ),
            ),
        ],
      ],
    );
  }

  Widget _acceptedHeader() {
    final l = context.l10n;
    return Row(
      children: [
        const Icon(Icons.inventory_rounded, size: 16, color: _green),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.acceptedInProgress.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.68,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: _greenBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l.activeCount(_inProgress.length),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: _green,
            ),
          ),
        ),
      ],
    );
  }

  // ── Outgoing section ───────────────────────────────────────────────────────
  Widget _buildOutgoingSection() {
    final l = context.l10n;
    final sent = _sent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          l.sentRequestsCount(sent?.length ?? 0),
          (sent ?? const []).any((r) => r.status == 'pending')
              ? l.waitingForTraveler
              : '',
        ),
        const SizedBox(height: 10),
        if (sent == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_sentFailed)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.errLoadRequests,
                key: const ValueKey('outgoing-error'),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
              TextButton(
                key: const ValueKey('outgoing-retry'),
                onPressed: _loadSent,
                child: Text(l.retry),
              ),
            ],
          )
        else if (sent.isEmpty)
          Text(
            l.noSentRequests,
            key: const ValueKey('outgoing-empty'),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          )
        else
          for (final r in sent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SentRequestCard(
                request: r,
                onTap: r.isEditable ? () => _edit(r) : null,
                onCancel: r.isCancellable ? () => _cancel(r) : null,
                onPay: r.awaitingPayment ? () => _pay(r) : null,
                onConfirmReceipt:
                    r.awaitingReceipt && !_confirming.contains(r.id)
                    ? () => _confirmReceipt(r)
                    : null,
                onReview: r.canReview ? () => _review(r) : null,
                deliveryCode: _codes[r.id],
                onTextCode: _texting.contains(r.id) ? null : () => _textCode(r),
                money: _money,
              ),
            ),
      ],
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.68,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          count,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
}

// ── Incoming request card ──────────────────────────────────────────────────
class _IncomingCard extends StatefulWidget {
  final _IncomingRequest request;

  /// Opens the request details.
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  /// An answer is being sent: the buttons wait.
  final bool busy;

  const _IncomingCard({
    required this.request,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  @override
  State<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends State<_IncomingCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('incoming-request-${widget.request.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: ClipOval(
                    child: AvatarImage(
                      path: widget.request.avatarPath,
                      fallback: Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.name,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        widget.request.subtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.request.amount,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            // Details
            _detailRow(context.l10n.yourTrip, widget.request.trip),
            const SizedBox(height: 8),
            _detailRow(context.l10n.travelDate, widget.request.date),
            const SizedBox(height: 8),
            _detailRow(context.l10n.item, widget.request.item),
            if (widget.request.weight != null) ...[
              const SizedBox(height: 8),
              _detailRow(context.l10n.weightAndSize, widget.request.weight!),
            ],
            const SizedBox(height: 12),
            // Photo row
            if (widget.request.photoCount != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.sealedPhotosAttached(
                          widget.request.photoCount!,
                        ),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onOpen,
                      child: Text(
                        widget.request.photoCount! > 1
                            ? context.l10n.viewPhotos
                            : context.l10n.viewPhoto,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 4),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('incoming-decline-${widget.request.id}'),
                    onTap: widget.busy ? null : widget.onDecline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cancel_rounded,
                            size: 16,
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.l10n.decline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    key: ValueKey('incoming-accept-${widget.request.id}'),
                    onTap: widget.busy ? null : widget.onAccept,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.l10n.acceptRequest,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sent request card ──────────────────────────────────────────────────────
class _SentRequestCard extends StatelessWidget {
  final SentRequest request;

  /// Opens the request for editing; null when it can't be edited.
  final VoidCallback? onTap;

  /// Cancels the request; null when it can no longer be cancelled.
  final VoidCallback? onCancel;

  /// Opens checkout for an accepted request.
  final VoidCallback? onPay;

  /// Confirms a delivered request was received, then opens the review.
  final VoidCallback? onConfirmReceipt;

  /// Opens the review for a delivered, confirmed request.
  final VoidCallback? onReview;

  /// The code to give the recipient (paid requests), and texting it.
  final DeliveryCode? deliveryCode;
  final VoidCallback? onTextCode;

  /// Shows the dollar amounts in the user's currency.
  final PriceFormatter money;

  /// The fixed price once the traveler accepted; before that, today's
  /// conversion, marked as an estimate ("≈ €99"). Dollars are exact.
  String get _totalText {
    final fixed = request.fixedTotalText;
    if (fixed != null) return fixed;
    final shown = money.format(request.totalUsd);
    return money.currency == 'USD' ? shown : '≈ $shown';
  }

  /// The cancellation fee charged, in the currency the price was fixed in.
  String get _cancelledFeeText {
    final local = request.displayCancellationFee;
    final currency = request.displayCurrency;
    if (local != null && currency != null) {
      return PriceFormatter.write(local, currency);
    }
    return money.format(request.cancellationFee!);
  }

  const _SentRequestCard({
    required this.request,
    this.onTap,
    this.onCancel,
    this.onPay,
    this.onConfirmReceipt,
    this.onReview,
    this.deliveryCode,
    this.onTextCode,
    this.money = PriceFormatter.usd,
  });

  static const _amber = Color(0xFFE5A83B);

  ({String label, Color color, Color bg}) _status(BuildContext context) {
    final l = context.l10n;
    return switch (request.status) {
      'pending' => (
        label: l.pending,
        color: _amber,
        bg: _amber.withValues(alpha: 0.1),
      ),
      'accepted' => (label: l.accepted, color: _green, bg: _greenBg),
      'paid' => (label: l.statusPaid, color: _green, bg: _greenBg),
      'handed_off' => (label: l.statusInTransit, color: _green, bg: _greenBg),
      'delivered' => (label: l.statusDelivered, color: _green, bg: _greenBg),
      'declined' => (
        label: l.declined,
        color: AppColors.destructive,
        bg: const Color(0xFFFDE8E8),
      ),
      'expired' => (
        label: l.statusExpired,
        color: AppColors.mutedForeground,
        bg: AppColors.muted,
      ),
      _ => (
        label: l.statusCancelled,
        color: AppColors.mutedForeground,
        bg: AppColors.muted,
      ),
    };
  }

  /// A full-width pill button, as in the design.
  /// The delivery code, big enough to read out, and texting it.
  Widget _codeBox(BuildContext context, DeliveryCode code) {
    final l = context.l10n;
    return Container(
      key: ValueKey('sent-request-code-${request.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_rounded, size: 14, color: _green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.deliveryCode.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: _green,
                  ),
                ),
              ),
              Text(
                code.code.split('').join(' '),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: 2,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.deliveryCodeNote(request.recipientName),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            key: ValueKey('sent-request-text-code-${request.id}'),
            // The whole row is the button, not just its text.
            behavior: HitTestBehavior.opaque,
            onTap: onTextCode,
            child: Row(
              children: [
                Icon(
                  code.smsSentAt != null
                      ? Icons.mark_chat_read_rounded
                      : Icons.sms_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    code.smsSentAt != null
                        ? l.codeTextedResend
                        : l.textCodeTo(request.recipientName),
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool filled = false,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: filled ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Key? key}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            key: key,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = _status(context);
    final trip = request.trip;
    final locale = Localizations.localeOf(context).toString();
    final closed = const [
      'declined',
      'expired',
      'cancelled',
    ].contains(request.status);
    final weight = NumberFormat('0.##', locale).format(request.weightKg);

    return GestureDetector(
      key: ValueKey('sent-request-${request.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: closed ? 0.8 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Traveler, status and price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: ClipOval(
                      child: AvatarImage(
                        path: trip.avatarPath,
                        fallback: Container(
                          color: AppColors.secondary,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trip.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: status.bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status.label,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: status.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          l.travelerDeliveries(trip.itemsDelivered),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _totalText,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              // Details
              _detailRow(
                l.routeLabel,
                '${trip.departureCity} → ${trip.arrivalCity}',
              ),
              const SizedBox(height: 8),
              _detailRow(
                l.travelDate,
                DateFormat.yMMMd(locale).format(trip.departureDate),
              ),
              const SizedBox(height: 8),
              _detailRow(
                l.item,
                '${request.itemsSummary} ($weight kg)',
                key: ValueKey('sent-request-item-${request.id}'),
              ),
              if (request.cancelledBySender) ...[
                const SizedBox(height: 8),
                Text(
                  (request.cancellationFee ?? 0) > 0
                      ? l.cancellationFeeCharged(_cancelledFeeText)
                      : l.cancelledFreeOfCharge,
                  key: ValueKey('sent-request-cancel-fee-${request.id}'),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l.tapToEdit,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
              // Actions
              if (request.status == 'accepted') ...[
                const SizedBox(height: 12),
                _button(
                  key: 'sent-request-pay-${request.id}',
                  icon: Icons.lock_rounded,
                  label: '${l.payEscrow} ($_totalText)',
                  color: AppColors.accent,
                  filled: true,
                  onTap: onPay ?? () {},
                ),
              ],
              if (deliveryCode != null && request.isPaid) ...[
                const SizedBox(height: 12),
                _codeBox(context, deliveryCode!),
              ],
              if (request.awaitingReceipt) ...[
                const SizedBox(height: 12),
                _button(
                  key: 'sent-request-confirm-receipt-${request.id}',
                  icon: Icons.check_circle_rounded,
                  label: l.confirmReceipt,
                  color: _green,
                  filled: true,
                  onTap: onConfirmReceipt ?? () {},
                ),
              ],
              if (request.canReview) ...[
                const SizedBox(height: 12),
                _button(
                  key: 'sent-request-review-${request.id}',
                  icon: Icons.star_rounded,
                  label: l.leaveAReview,
                  color: AppColors.accent,
                  onTap: onReview ?? () {},
                ),
              ],
              if (request.status == 'delivered' && request.reviewed) ...[
                const SizedBox(height: 12),
                Row(
                  key: ValueKey('sent-request-reviewed-${request.id}'),
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: _amber),
                    const SizedBox(width: 4),
                    Text(
                      l.youReviewed,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
              if (request.status == 'declined' ||
                  request.status == 'expired') ...[
                const SizedBox(height: 12),
                _button(
                  key: 'sent-request-find-${request.id}',
                  icon: Icons.search_rounded,
                  label: l.findAnotherTraveler,
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TravelerResultsScreen(),
                    ),
                  ),
                ),
              ],
              if (onCancel != null) ...[
                SizedBox(height: request.status == 'accepted' ? 8 : 12),
                _button(
                  key: 'sent-request-cancel-${request.id}',
                  icon: Icons.cancel_rounded,
                  label: l.cancelRequest,
                  color: AppColors.destructive,
                  onTap: onCancel!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────
/// What a pending request card shows, ready in the user's language.
class _IncomingRequest {
  final String id, name, subtitle, amount, trip, date, item;
  final String? avatarPath;

  /// Shown only when the sender gave them.
  final String? weight;
  final int? photoCount;
  const _IncomingRequest({
    required this.id,
    required this.name,
    this.avatarPath,
    required this.subtitle,
    required this.amount,
    required this.trip,
    required this.date,
    required this.item,
    this.weight,
    this.photoCount,
  });
}

/// What an accepted request card shows, ready in the user's language.
class _AcceptedView {
  final String id, senderName, statusLabel, subtitle, payout, trip, item;
  final String nextAction, buttonLabel;
  final String? avatarPath;
  final IconData nextIcon;
  const _AcceptedView({
    required this.id,
    required this.senderName,
    this.avatarPath,
    required this.statusLabel,
    required this.subtitle,
    required this.payout,
    required this.trip,
    required this.item,
    required this.nextAction,
    required this.nextIcon,
    required this.buttonLabel,
  });
}

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);

// ── Accepted request card ──────────────────────────────────────────────────
class _AcceptedCard extends StatelessWidget {
  final _AcceptedView request;

  /// Opens the request.
  final VoidCallback onOpen;
  const _AcceptedCard({required this.request, required this.onOpen});

  void _open(BuildContext context) => onOpen();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      key: const ValueKey('accepted-request-card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sender row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _green.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: AvatarImage(
                      path: request.avatarPath,
                      fallback: Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and status on one line, as in the design; a long
                      // name is shortened rather than pushing the pill down.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              request.senderName,
                              key: const ValueKey('accepted-sender-name'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            key: const ValueKey('accepted-status-pill'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _greenBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              request.statusLabel,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: _green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        request.subtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _greenBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        request.payout,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: _green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.yourPayout,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            _row(l.tripLabel, Text(request.trip, style: _value)),
            const SizedBox(height: 8),
            _row(l.item, Text(request.item, style: _value)),
            const SizedBox(height: 8),
            _row(
              l.nextAction,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(request.nextIcon, size: 13, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      request.nextAction,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const ValueKey('manage-delivery'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          request.buttonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primaryForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 15,
                        color: AppColors.primaryForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _value = GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.foreground,
  );

  Widget _row(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }
}
