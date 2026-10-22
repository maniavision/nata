import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../services/request_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/nata_toast.dart';

/// Pays for an accepted request. Step 1: the sender checks the traveler's
/// flight ticket; step 2: the photo on the traveler's ID and their verified
/// name; step 3: they pay into escrow on Flutterwave's page, which this
/// screen watches until the payment goes through.
class CheckoutEscrowScreen extends StatefulWidget {
  final SentRequest request;

  /// Shows amounts that are not fixed yet in the user's currency.
  final PriceFormatter money;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  /// Override for tests; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// Overrides for tests: opening and closing Flutterwave's payment page
  /// (an in-app browser by default), and how often the payment is checked.
  final Future<bool> Function(Uri link)? openPaymentPage;
  final Future<void> Function()? closePaymentPage;
  final Duration pollInterval;

  const CheckoutEscrowScreen({
    super.key,
    required this.request,
    this.money = PriceFormatter.usd,
    this.service,
    this.now,
    this.openPaymentPage,
    this.closePaymentPage,
    this.pollInterval = const Duration(seconds: 3),
  });

  @override
  State<CheckoutEscrowScreen> createState() => _CheckoutEscrowScreenState();
}

class _CheckoutEscrowScreenState extends State<CheckoutEscrowScreen> {
  int _paymentMethod = 0; // 0=Apple Pay, 1=Card, 2=Mobile Money, 3=Bank
  static const _payMethods = [
    PayMethod.applePay,
    PayMethod.card,
    PayMethod.mobileMoney,
    PayMethod.bankTransfer,
  ];

  /// The payment in progress on Flutterwave's page, checked every
  /// [CheckoutEscrowScreen.pollInterval] for up to [_maxPolls] times.
  PaymentLink? _payment;
  bool _startingPayment = false;
  bool _checkingPayment = false;
  Timer? _poll;
  int _polls = 0;
  static const _maxPolls = 300;

  /// Mobile money: the countries offered (loaded when it is chosen) and the
  /// one picked, whose currency the price is converted into.
  List<MobileMoneyOption>? _mobileOptions;
  bool _mobileLoading = false;
  bool _mobileFailed = false;
  MobileMoneyOption? _mobileChoice;
  bool get _payingByMobile => _paymentMethod == 2;

  /// Bank transfer is paid in naira: the amount, loaded when it is chosen.
  bool get _payingByBank => _paymentMethod == 3;
  LocalCharge? _bankQuote;
  bool _bankLoading = false;
  bool _bankFailed = false;

  Future<void> _loadBankQuote() async {
    if (_bankLoading || _bankQuote != null) return;
    setState(() {
      _bankLoading = true;
      _bankFailed = false;
    });
    try {
      final quote = await _service.bankTransferQuote(_r.id);
      if (mounted) setState(() => _bankQuote = quote);
    } catch (e) {
      debugPrint('[Checkout] bank transfer quote: $e');
      if (mounted) setState(() => _bankFailed = true);
    } finally {
      if (mounted) setState(() => _bankLoading = false);
    }
  }

  /// Accounts made with a phone number have no email, which Flutterwave
  /// needs: checkout asks for one (kept by create-payment for next time).
  bool _needsEmail = false;
  final _emailCtrl = TextEditingController();
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  bool get _emailValid => _emailPattern.hasMatch(_emailCtrl.text.trim());

  Future<void> _loadPayerEmail() async {
    try {
      final email = await _service.payerEmail();
      if (mounted && email == null) setState(() => _needsEmail = true);
    } catch (e) {
      // Pay anyway: create-payment answers email_required if one is needed.
      debugPrint('[Checkout] payer email: $e');
    }
  }

  Future<void> _loadMobileOptions() async {
    if (_mobileLoading || _mobileOptions != null) return;
    setState(() {
      _mobileLoading = true;
      _mobileFailed = false;
    });
    try {
      final options = await _service.mobileMoneyOptions(_r.id);
      if (!mounted) return;
      setState(() {
        _mobileOptions = options;
        _mobileChoice ??= options.where((o) => o.suggested).firstOrNull;
      });
    } catch (e) {
      debugPrint('[Checkout] mobile money options: $e');
      if (mounted) setState(() => _mobileFailed = true);
    } finally {
      if (mounted) setState(() => _mobileLoading = false);
    }
  }

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

  bool get _hasTicket => _r.hasTicket;

  /// The copy of the ticket with the booking reference blurred; a ticket
  /// without one is described but not shown.
  bool get _hasTicketImage => _r.ticketReceiptPath != null;
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
    if (_hasTicketImage) _loadTicket();
    _loadPayerEmail();
  }

  // ── Paying ─────────────────────────────────────────────────────────────────
  Future<void> _startPayment() async {
    if (_startingPayment) return;
    setState(() => _startingPayment = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payment = await _service.startPayment(
        _r.id,
        _payMethods[_paymentMethod],
        country: _payingByMobile ? _mobileChoice?.countryCode : null,
        email: _needsEmail ? _emailCtrl.text.trim() : null,
      );
      if (!mounted) return;
      setState(() => _payment = payment);
      _startPolling();
      await _openPaymentPage();
    } on RequestException catch (e) {
      if (e.reason == RequestFailure.emailRequired && mounted) {
        setState(() => _needsEmail = true);
      }
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.notPayable => l.errRequestNotPayable,
          RequestFailure.paymentsUnavailable => l.errPaymentsUnavailable,
          RequestFailure.emailRequired => l.errEmailRequired,
          RequestFailure.mobileMoneyUnavailable => l.errMobileMoneyUnavailable,
          RequestFailure.rateUnavailable => l.errRateUnavailable,
          RequestFailure.notSignedIn => l.errSessionExpired,
          _ => l.errPaymentStart,
        }, tone: ToastTone.error),
      );
    } catch (e) {
      debugPrint('[Checkout] start payment: $e');
      messenger.showSnackBar(
        nataToast(l.errPaymentStart, tone: ToastTone.error),
      );
    } finally {
      if (mounted) setState(() => _startingPayment = false);
    }
  }

  Future<void> _openPaymentPage() async {
    final payment = _payment;
    if (payment == null) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await (widget.openPaymentPage ?? _openInApp)(payment.link);
    } catch (e) {
      debugPrint('[Checkout] open payment page: $e');
    }
    if (!opened) {
      messenger.showSnackBar(
        nataToast(l.errPaymentStart, tone: ToastTone.error),
      );
    }
  }

  static Future<bool> _openInApp(Uri link) =>
      launchUrl(link, mode: LaunchMode.inAppBrowserView);

  static Future<void> _closeInApp() async {
    try {
      if (await supportsCloseForLaunchMode(LaunchMode.inAppBrowserView)) {
        await closeInAppWebView();
      }
    } catch (_) {
      // Already closed.
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _polls = 0;
    _poll = Timer.periodic(widget.pollInterval, (_) {
      if (++_polls > _maxPolls) {
        _poll?.cancel();
        return;
      }
      _checkPayment();
    });
  }

  /// Asks where the payment stands. [manual] when the sender tapped "I've
  /// paid", to tell them if it isn't there yet.
  Future<void> _checkPayment({bool manual = false}) async {
    final payment = _payment;
    if (payment == null || _checkingPayment) return;
    _checkingPayment = true;
    if (manual) setState(() {});
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final status = await _service.paymentStatus(payment.txRef);
      if (!mounted || _payment != payment) return;
      switch (status) {
        case PaymentStatus.successful:
          _poll?.cancel();
          await (widget.closePaymentPage ?? _closeInApp)();
          // Text the delivery code to the recipient straight away; the
          // sender can also do it, or resend it, from the request card.
          unawaited(
            _service.sendDeliveryCode(_r.id).catchError((Object e) {
              debugPrint('[Checkout] delivery code SMS: $e');
            }),
          );
          messenger.showSnackBar(
            nataToast(l.paymentReceived, tone: ToastTone.success),
          );
          navigator.pop(true);
        case PaymentStatus.failed:
          _poll?.cancel();
          await (widget.closePaymentPage ?? _closeInApp)();
          setState(() => _payment = null);
          messenger.showSnackBar(
            nataToast(l.errPaymentFailed, tone: ToastTone.error),
          );
        case PaymentStatus.pending:
          if (manual) {
            messenger.showSnackBar(nataToast(l.paymentNotReceivedYet));
            // Keep watching after a manual check.
            if (!(_poll?.isActive ?? false)) _startPolling();
          }
      }
    } catch (e) {
      debugPrint('[Checkout] payment status: $e');
      if (manual) {
        messenger.showSnackBar(
          nataToast(l.errRequestFailed, tone: ToastTone.error),
        );
      }
    } finally {
      _checkingPayment = false;
      if (manual && mounted) setState(() {});
    }
  }

  /// Leaves the payment in progress, to pick another way to pay.
  void _abandonPayment() {
    _poll?.cancel();
    setState(() => _payment = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poll?.cancel();
    _emailCtrl.dispose();
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
        nataToast(
          e.reason == RequestFailure.notPayable
              ? l.errRequestNotPayable
              : l.errRequestFailed,
          tone: ToastTone.error,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errRequestFailed, tone: ToastTone.error),
      );
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
                  _buildIdTip(),
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
            const SizedBox(width: 12),
            Expanded(
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
      _PayMethod(
        icon: Icons.account_balance_rounded,
        iconBg: AppColors.card,
        iconColor: AppColors.primary,
        title: context.l10n.bankTransfer,
        subtitle: context.l10n.bankTransferSub,
        iconBorder: true,
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
            context.l10n.step2PaymentMethod,
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
                onTap: () {
                  setState(() => _paymentMethod = e.key);
                  if (e.key == 2) _loadMobileOptions();
                  if (e.key == 3) _loadBankQuote();
                },
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
          if (_payingByMobile) _buildMobileMoneyPanel(),
          if (_payingByBank) _buildBankTransferPanel(),
          if (_needsEmail) _buildEmailField(),
        ],
      ),
    );
  }

  /// The wallet's country, and the amount it will be charged in its currency.
  Widget _buildMobileMoneyPanel() {
    final l = context.l10n;
    final options = _mobileOptions;
    final Widget body;
    if (_mobileLoading || (options == null && !_mobileFailed)) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    } else if (_mobileFailed || options!.isEmpty) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              _mobileFailed
                  ? l.errMobileMoneyOptions
                  : l.errMobileMoneyUnavailable,
              key: const ValueKey('mobile-money-error'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ),
          if (_mobileFailed)
            TextButton(onPressed: _loadMobileOptions, child: Text(l.retry)),
        ],
      );
    } else {
      final choice = _mobileChoice;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('mobile-money-country'),
            initialValue: choice?.countryCode,
            isExpanded: true,
            hint: Text(l.chooseCountry),
            decoration: InputDecoration(
              labelText: l.mobileMoneyCountry,
              isDense: true,
              filled: true,
              fillColor: AppColors.input,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o.countryCode,
                  child: Text(
                    '${o.countryName} · ${o.currency}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (code) => setState(
              () => _mobileChoice = options.firstWhere(
                (o) => o.countryCode == code,
              ),
            ),
          ),
          if (choice != null) ...[
            const SizedBox(height: 8),
            Text(
              l.mobileMoneyChargedAs(choice.amountText, _totalText),
              key: const ValueKey('mobile-money-charge'),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 12), child: body);
  }

  /// The amount in naira, for a bank transfer.
  Widget _buildBankTransferPanel() {
    final l = context.l10n;
    final quote = _bankQuote;
    final Widget body;
    if (_bankFailed) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              l.errBankTransferQuote,
              key: const ValueKey('bank-transfer-error'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ),
          TextButton(onPressed: _loadBankQuote, child: Text(l.retry)),
        ],
      );
    } else if (quote == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    } else {
      body = Text(
        l.bankTransferChargedAs(quote.amountText, _totalText),
        key: const ValueKey('bank-transfer-charge'),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          height: 1.4,
          color: AppColors.mutedForeground,
        ),
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 12), child: body);
  }

  /// The payer's email, for an account without one.
  Widget _buildEmailField() {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('checkout-email'),
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.payerEmail,
              hintText: l.payerEmailHint,
              isDense: true,
              filled: true,
              fillColor: AppColors.input,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.payerEmailNote,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
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
    final checked = _ticketChecked && !_expired;
    final countryChosen = !_payingByMobile || _mobileChoice != null;
    final bankReady = !_payingByBank || _bankQuote != null;
    final emailGiven = !_needsEmail || _emailValid;
    final unlocked = checked && countryChosen && bankReady && emailGiven;
    // Mobile money is charged in the wallet's currency, bank transfer in
    // naira.
    final amount = _payingByMobile && _mobileChoice != null
        ? _mobileChoice!.amountText
        : _payingByBank && _bankQuote != null
        ? _bankQuote!.amountText
        : _totalText;
    if (_payment != null) return _buildPaymentInProgress(l);
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
            onPressed: unlocked && !_startingPayment ? _startPayment : null,
            icon: _startingPayment
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.mutedForeground,
                    ),
                  )
                : Icon(
                    Icons.lock_rounded,
                    size: 18,
                    color: unlocked ? Colors.white : AppColors.mutedForeground,
                  ),
            label: Text(
              unlocked
                  ? l.payAmountIntoEscrow(amount)
                  : !checked
                  ? l.validateToUnlock
                  : !countryChosen
                  ? l.chooseCountry
                  : !bankReady
                  ? l.bankTransfer
                  : l.enterEmailToPay,
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

  /// While the sender pays on Flutterwave's page.
  Widget _buildPaymentInProgress(AppLocalizations l) {
    return Container(
      key: const ValueKey('checkout-payment-in-progress'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.completeYourPayment,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.completeYourPaymentSub,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              key: const ValueKey('checkout-check-payment'),
              onPressed: _checkingPayment
                  ? null
                  : () => _checkPayment(manual: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: Text(
                l.iPaidCheckNow,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              key: const ValueKey('checkout-open-payment'),
              onPressed: _openPaymentPage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l.openPaymentPage,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('checkout-abandon-payment'),
            onPressed: _abandonPayment,
            child: Text(
              l.chooseAnotherWayToPay,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tip: check the traveler's ID at the handover ───────────────────────────
  Widget _buildIdTip() {
    final l = context.l10n;
    return Container(
      key: const ValueKey('id-meeting-tip'),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: l.idMeetingTipTitle,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.foreground,
                    ),
                  ),
                  TextSpan(text: ' ${l.idMeetingTipBody(_r.trip.fullName)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The booking reference row: blurred placeholder letters, never the
  /// reference (senders aren't given it).
  Widget _hiddenBookingRef(AppLocalizations l) => Padding(
    key: const ValueKey('ticket-booking-ref-hidden'),
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      label: '${l.ticketBookingRef}: ${l.bookingRefHidden}',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            l.ticketBookingRef,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const Spacer(),
          Tooltip(
            message: l.bookingRefHidden,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: AppColors.mutedForeground,
                ),
                const SizedBox(width: 6),
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Text(
                    'XXXXXX',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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
            if (_hasTicketImage)
              preview
            else
              Text(
                l.ticketImageHidden,
                key: const ValueKey('ticket-image-hidden'),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.mutedForeground,
                ),
              ),
            const SizedBox(height: 4),
            detail(
              l.ticketRoute,
              '${_r.trip.departureCity} → ${_r.trip.arrivalCity}',
            ),
            detail(
              l.ticketDeparture,
              DateFormat.yMMMd(locale).format(_r.trip.departureDate),
            ),
            if (_r.hasBookingReference) _hiddenBookingRef(l),
            detail(l.ticketTraveler, _r.trip.fullName),
            if (!_ticketChecked) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('ticket-confirm'),
                  onPressed:
                      _confirming ||
                          _expired ||
                          (_hasTicketImage && _ticketUrl == null)
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
