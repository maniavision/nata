import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';
import '../services/request_service.dart';
import '../widgets/avatar_image.dart';

/// Pays for an accepted request. Step 1: the sender checks the traveler's
/// flight ticket; step 2: the photo on the traveler's ID and their verified
/// name; step 3: they pay into escrow (payment itself is not live yet).
class CheckoutEscrowScreen extends StatefulWidget {
  final SentRequest request;

  /// Shows amounts that are not fixed yet in the user's currency.
  final PriceFormatter money;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  /// Override for tests; defaults to [DateTime.now].
  final DateTime Function()? now;

  const CheckoutEscrowScreen({
    super.key,
    required this.request,
    this.money = PriceFormatter.usd,
    this.service,
    this.now,
  });

  @override
  State<CheckoutEscrowScreen> createState() => _CheckoutEscrowScreenState();
}

class _CheckoutEscrowScreenState extends State<CheckoutEscrowScreen> {
  int _paymentMethod = 0; // 0=Apple Pay, 1=Card, 2=Mobile Money

  SentRequest get _r => widget.request;
  RequestService get _service => widget.service ?? RequestService();
  DateTime _now() => (widget.now ?? DateTime.now)();

  /// Seconds left to pay; null when there is no deadline.
  int? _seconds;
  Timer? _timer;

  /// The ticket: a link to show it, or a failure to load it.
  String? _ticketUrl;
  bool _ticketFailed = false;

  /// The sender confirmed the ticket (now, or on an earlier visit).
  late bool _ticketChecked = _r.ticketCheckedAt != null;
  bool _confirming = false;

  /// The photo on the traveler's ID; null while loading or unavailable.
  TravelerIdPhoto? _idPhoto;
  bool _idPhotoLoading = false;
  bool _idPhotoFailed = false;
  late bool _idChecked = _r.idCheckedAt != null;
  bool _confirmingId = false;

  bool get _hasTicket => _r.ticketReceiptPath != null;
  bool get _expired => _seconds != null && _seconds! <= 0;
  bool get _ticketIsPdf =>
      (_r.ticketReceiptPath ?? '').toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    final expires = _r.expiresAt;
    if (expires != null) {
      _seconds = expires.difference(_now()).inSeconds.clamp(0, 1 << 31);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if ((_seconds ?? 0) > 0) {
          setState(() => _seconds = _seconds! - 1);
        } else {
          _timer?.cancel();
        }
      });
    }
    if (_hasTicket) _loadTicket();
    if (_r.travelerVerified) _loadIdPhoto();
  }

  Future<void> _loadIdPhoto() async {
    setState(() {
      _idPhotoLoading = true;
      _idPhotoFailed = false;
    });
    try {
      final photo = await _service.travelerIdPhoto(_r.id);
      if (!mounted) return;
      setState(() {
        _idPhoto = photo;
        _idPhotoFailed = photo == null;
      });
    } catch (e) {
      debugPrint('[Checkout] ID photo: $e');
      if (mounted) setState(() => _idPhotoFailed = true);
    } finally {
      if (mounted) setState(() => _idPhotoLoading = false);
    }
  }

  Future<void> _confirmId() async {
    if (_confirmingId || _idChecked) return;
    setState(() => _confirmingId = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.confirmIdChecked(_r.id);
      if (mounted) setState(() => _idChecked = true);
    } on RequestException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.reason == RequestFailure.notPayable
                ? l.errRequestNotPayable
                : l.errRequestFailed,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errRequestFailed)));
    } finally {
      if (mounted) setState(() => _confirmingId = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() => _ticketFailed = false);
    try {
      final url = await _service.ticketUrl(_r.ticketReceiptPath!);
      if (mounted) setState(() => _ticketUrl = url);
    } catch (e) {
      debugPrint('[Checkout] ticket: $e');
      if (mounted) setState(() => _ticketFailed = true);
    }
  }

  Future<void> _confirmTicket() async {
    if (_confirming || _ticketChecked) return;
    setState(() => _confirming = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.confirmTicketChecked(_r.id);
      if (mounted) setState(() => _ticketChecked = true);
    } on RequestException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.reason == RequestFailure.notPayable
                ? l.errRequestNotPayable
                : l.errRequestFailed,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errRequestFailed)));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  /// Opens the ticket full screen (an image) or in the browser (a PDF).
  void _openTicket() {
    final url = _ticketUrl;
    if (url == null) return;
    if (_ticketIsPdf) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, key: const ValueKey('ticket-full')),
            ),
          ),
        ),
      ),
    );
  }

  /// The fixed price once the traveler accepted (it always is by now);
  /// otherwise today's conversion of the dollar total, as an estimate.
  String _amount(double? fixed, double? usd) {
    final currency = _r.displayCurrency;
    if (fixed != null && currency != null) {
      return PriceFormatter.write(fixed, currency);
    }
    if (usd == null) return '—';
    final shown = widget.money.format(usd);
    return widget.money.currency == 'USD' ? shown : '≈ $shown';
  }

  String get _totalText => _r.fixedTotalText ?? _amount(null, _r.totalUsd);

  String get _countdownLabel {
    final left = _seconds ?? 0;
    final h = left ~/ 3600;
    final m = (left % 3600) ~/ 60;
    final s = left % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildStickyHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                children: [
                  if (_seconds != null) ...[
                    _buildCountdownBanner(),
                    const SizedBox(height: 16),
                  ],
                  _buildEscrowExplainerCard(),
                  const SizedBox(height: 16),
                  _buildOrderSummaryCard(),
                  const SizedBox(height: 16),
                  _buildTicketCard(),
                  const SizedBox(height: 16),
                  _buildIdCard(),
                  const SizedBox(height: 16),
                  _buildPaymentMethodCard(),
                  const SizedBox(height: 16),
                  _buildBreakdownCard(),
                  const SizedBox(height: 16),
                  _buildRefundGuaranteeCard(),
                  const SizedBox(height: 20),
                  _buildPayButton(context),
                  const SizedBox(height: 12),
                  _buildSecurityNote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sticky header ──────────────────────────────────────────────────────────
  Widget _buildStickyHeader(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.95),
          border: const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.7),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.foreground,
                  size: 20,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  context.l10n.secureEscrowCheckout,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Countdown banner ───────────────────────────────────────────────────────
  Widget _buildCountdownBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              size: 18,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.paymentWindowActive,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: const Color(0xFF78350F),
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF92400E),
                    ),
                    children: [
                      TextSpan(text: context.l10n.requestExpiresInPrefix),
                      TextSpan(
                        text: context.l10n.hoursMinutes(
                          (_seconds ?? 0) ~/ 3600,
                          ((_seconds ?? 0) % 3600) ~/ 60,
                        ),
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _countdownLabel,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Escrow explainer ───────────────────────────────────────────────────────
  Widget _buildEscrowExplainerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.howEscrowWorks,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(text: context.l10n.escrowNotePart1),
                          TextSpan(
                            text: context.l10n.escrowNotePart2,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                          TextSpan(text: context.l10n.escrowNotePart3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Order summary ──────────────────────────────────────────────────────────
  Widget _buildOrderSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipOval(
                  child: AvatarImage(
                    path: _r.trip.avatarPath,
                    fallback: Container(
                      color: AppColors.secondary,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 20,
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
                      _r.trip.fullName,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      '${_r.trip.departureCity} → ${_r.trip.arrivalCity} · ${DateFormat.MMMd(Localizations.localeOf(context).toString()).format(_r.trip.departureDate)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.accepted,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _summaryRow(
            Icons.inventory_2_outlined,
            context.l10n.itemPlain,
            _r.itemsSummary,
          ),
          const SizedBox(height: 8),
          _summaryRow(
            Icons.monitor_weight_outlined,
            context.l10n.weightPlain,
            '${NumberFormat('0.##', Localizations.localeOf(context).toString()).format(_r.weightKg)} kg',
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
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
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }

  // ── Payment method ─────────────────────────────────────────────────────────
  Widget _buildPaymentMethodCard() {
    final methods = [
      _PayMethod(
        icon: Icons.apple,
        iconBg: Colors.black,
        iconColor: Colors.white,
        title: context.l10n.applePay,
        subtitle: context.l10n.applePaySub,
      ),
      _PayMethod(
        icon: Icons.credit_card_rounded,
        iconBg: AppColors.card,
        iconColor: AppColors.primary,
        title: context.l10n.creditCard,
        subtitle: context.l10n.creditCardSub,
        iconBorder: true,
      ),
      _PayMethod(
        icon: null,
        iconBg: const Color(0xFF00A859),
        iconColor: Colors.white,
        iconLabel: 'M',
        title: context.l10n.mobileMoney,
        subtitle: context.l10n.mobileMoneyPhoneSub,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.step3PaymentMethod,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          ...methods.asMap().entries.map((e) {
            final m = e.value;
            final selected = _paymentMethod == e.key;
            return Padding(
              padding: EdgeInsets.only(
                bottom: e.key < methods.length - 1 ? 8 : 0,
              ),
              child: GestureDetector(
                onTap: () => setState(() => _paymentMethod = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.05)
                        : AppColors.input.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: m.iconBg.withValues(
                            alpha: m.iconBg == const Color(0xFF00A859)
                                ? 0.15
                                : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: m.iconBorder == true
                              ? Border.all(color: AppColors.border)
                              : null,
                        ),
                        child: m.icon != null
                            ? Icon(m.icon!, size: 20, color: m.iconColor)
                            : Center(
                                child: Text(
                                  m.iconLabel ?? '',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: const Color(0xFF00A859),
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
                              m.title,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              m.subtitle,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? AppColors.accent
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? AppColors.accent
                                : AppColors.border,
                            width: selected ? 0 : 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Breakdown ──────────────────────────────────────────────────────────────
  Widget _buildBreakdownCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.paymentBreakdown,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          if (_r.displayCost != null && _r.displayFee != null) ...[
            _breakdownRow(
              context.l10n.travelerReward,
              _amount(_r.displayCost, null),
            ),
            const SizedBox(height: 8),
            _breakdownRow(
              context.l10n.platformFee,
              _amount(_r.displayFee, null),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.totalEscrow,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _totalText,
                key: const ValueKey('checkout-total'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  // ── Refund guarantee ───────────────────────────────────────────────────────
  Widget _buildRefundGuaranteeCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.l10n.cancellationTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _bulletPoint(
            context.l10n.refundFullBold,
            context.l10n.refundFullRest,
          ),
          const SizedBox(height: 4),
          _bulletPoint(context.l10n.cancelFeeBold, context.l10n.cancelFeeRest),
          const SizedBox(height: 4),
          _bulletPoint(
            context.l10n.disputeWindowBold,
            context.l10n.disputeWindowRest,
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String bold, String rest) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.dmSans(
          fontSize: 11,
          color: AppColors.mutedForeground,
          height: 1.5,
        ),
        children: [
          const TextSpan(text: '• '),
          TextSpan(
            text: bold,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: AppColors.foreground,
            ),
          ),
          TextSpan(text: ' $rest'),
        ],
      ),
    );
  }

  // ── Pay button ─────────────────────────────────────────────────────────────
  Widget _buildPayButton(BuildContext context) {
    final l = context.l10n;
    final unlocked = _ticketChecked && _idChecked && !_expired;
    return Column(
      children: [
        if (_expired) ...[
          Text(
            l.requestExpiredPayment,
            key: const ValueKey('checkout-expired'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.destructive,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            key: const ValueKey('checkout-pay'),
            // Payment is not live yet: say so rather than pretend.
            onPressed: unlocked
                ? () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(l.paymentsComingSoon)),
                    )
                : null,
            icon: Icon(
              Icons.lock_rounded,
              size: 18,
              color: unlocked ? Colors.white : AppColors.mutedForeground,
            ),
            label: Text(
              unlocked
                  ? l.payAmountIntoEscrow(_totalText)
                  : l.validateTicketAndId,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: unlocked ? Colors.white : AppColors.mutedForeground,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.muted,
              elevation: unlocked ? 3 : 0,
              shadowColor: AppColors.accent.withValues(alpha: 0.4),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: the photo on the traveler's ID ─────────────────────────────────
  String _idTypeName(String? type) {
    final l = context.l10n;
    final name = switch (type) {
      'passport' => l.idTypePassport,
      'drivers_license' => l.idTypeDriversLicense,
      'national_id' => l.idTypeNationalId,
      _ => null,
    };
    if (name == null || name.isEmpty) return '—';
    return name[0].toUpperCase() + name.substring(1);
  }

  Widget _buildIdCard() {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
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
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );

    Widget photo;
    if (_idPhotoFailed) {
      photo = Row(
        children: [
          Expanded(
            child: Text(
              l.errIdPhotoLoad,
              key: const ValueKey('id-photo-error'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('id-photo-retry'),
            onPressed: _loadIdPhoto,
            child: Text(l.retry),
          ),
        ],
      );
    } else if (_idPhotoLoading || _idPhoto == null) {
      photo = const SizedBox(
        height: 144,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    } else {
      photo = Center(
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                key: const ValueKey('id-photo'),
                width: 132,
                height: 160,
                color: AppColors.secondary,
                child: Image.network(
                  _idPhoto!.url,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.person,
                    size: 48,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4EE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF168A68).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 11,
                      color: Color(0xFF168A68),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      l.identityVerifiedBadge,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                        color: const Color(0xFF168A68),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('id-card'),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.step2VerifyId,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('id-status'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _idChecked
                      ? const Color(0xFFE4F4EE)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _idChecked ? l.ticketValidated : l.ticketNotValidated,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: _idChecked
                        ? const Color(0xFF168A68)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_r.travelerVerified)
            Text(
              l.travelerNotVerified,
              key: const ValueKey('id-not-verified'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            )
          else ...[
            Text(
              l.idIntro(_r.trip.firstName),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            photo,
            const SizedBox(height: 4),
            // The profile name was checked against the ID when it was
            // uploaded, so it is the name on the ID.
            detail(l.nameOnId, _r.trip.fullName),
            if (_idPhoto?.idDocumentType != null)
              detail(l.idDocument, _idTypeName(_idPhoto!.idDocumentType)),
            if (_idPhoto?.verifiedAt != null)
              detail(
                l.idVerifiedOn,
                DateFormat.yMMMd(
                  locale,
                ).format(_idPhoto!.verifiedAt!.toLocal()),
              ),
            const SizedBox(height: 8),
            Text(
              l.idPhotoOnlyNote,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: AppColors.mutedForeground,
              ),
            ),
            if (!_idChecked) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('id-confirm'),
                  onPressed: _confirmingId || _expired || _idPhoto == null
                      ? null
                      : _confirmId,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    l.iCheckedId,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.accent),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Step 1: the traveler's ticket ──────────────────────────────────────────
  Widget _buildTicketCard() {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
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
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );

    Widget preview;
    if (_ticketFailed) {
      preview = Row(
        children: [
          Expanded(
            child: Text(
              l.errTicketLoad,
              key: const ValueKey('ticket-error'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ),
          TextButton(onPressed: _loadTicket, child: Text(l.retry)),
        ],
      );
    } else if (_ticketUrl == null) {
      preview = const SizedBox(
        height: 144,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    } else {
      preview = GestureDetector(
        key: const ValueKey('ticket-preview'),
        onTap: _openTicket,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 144,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ticketIsPdf)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 36,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.ticketPdf,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  )
                else
                  Image.network(
                    _ticketUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.open_in_full_rounded,
                          size: 12,
                          color: AppColors.foreground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l.viewFullTicket,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('ticket-card'),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.step1ValidateTicket,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('ticket-status'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _ticketChecked
                      ? const Color(0xFFE4F4EE)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _ticketChecked ? l.ticketValidated : l.ticketNotValidated,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: _ticketChecked
                        ? const Color(0xFF168A68)
                        : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_hasTicket)
            Text(
              l.noTicketUploaded,
              key: const ValueKey('ticket-missing'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            )
          else ...[
            Text(
              l.ticketIntro(_r.trip.firstName),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            preview,
            const SizedBox(height: 4),
            detail(
              l.ticketRoute,
              '${_r.trip.departureCity} → ${_r.trip.arrivalCity}',
            ),
            detail(
              l.ticketDeparture,
              DateFormat.yMMMd(locale).format(_r.trip.departureDate),
            ),
            if (_r.bookingReference != null)
              detail(l.ticketBookingRef, _r.bookingReference!),
            detail(l.ticketTraveler, _r.trip.fullName),
            if (!_ticketChecked) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('ticket-confirm'),
                  onPressed: _confirming || _expired || _ticketUrl == null
                      ? null
                      : _confirmTicket,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    l.iCheckedTicket,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppColors.accent),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF168A68)),
        const SizedBox(width: 4),
        Text(
          context.l10n.escrowEncrypted,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────
class _PayMethod {
  final IconData? icon;
  final Color iconBg;
  final Color iconColor;
  final String? iconLabel;
  final String title;
  final String subtitle;
  final bool? iconBorder;

  const _PayMethod({
    this.icon,
    required this.iconBg,
    required this.iconColor,
    this.iconLabel,
    required this.title,
    required this.subtitle,
    this.iconBorder,
  });
}
