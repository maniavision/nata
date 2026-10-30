import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/phone_number.dart';
import '../services/preferences_service.dart';
import '../services/request_service.dart';
import '../services/stripe_sheet.dart';
import '../widgets/nata_toast.dart';

/// The traveler pays the refundable deposit for items above their carrying
/// limit, before pickup (20240195): by card in Stripe's sheet, or by mobile
/// money with a prompt on their phone, as the request itself is paid. Pops
/// with true once the deposit is held.
class DepositScreen extends StatefulWidget {
  final String requestId;
  final RequestDeposit deposit;

  /// Overrides for tests; they default to the real services.
  final RequestService? service;
  final PaymentService? paymentService;

  /// Override for tests: Stripe's payment sheet.
  final Future<CardSheetResult> Function(StripeSheet sheet)? presentCardSheet;

  /// How often a payment in progress is checked.
  final Duration pollInterval;

  const DepositScreen({
    super.key,
    required this.requestId,
    required this.deposit,
    this.service,
    this.paymentService,
    this.presentCardSheet,
    this.pollInterval = const Duration(seconds: 3),
  });

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  RequestService get _service => widget.service ?? RequestService();
  RequestDeposit get _d => widget.deposit;
  bool get _mobile => _d.kind == CheckoutKind.mobileMoney;

  bool _agreed = false;

  /// Mobile money: the countries offered, the one picked, its network and
  /// number. A saved wallet fills them in and shows as a summary until
  /// Change is tapped.
  List<MobileMoneyOption>? _options;
  bool _optionsFailed = false;
  MobileMoneyOption? _choice;
  String? _pickedNetwork;
  final _phoneCtrl = TextEditingController();
  bool _editingWallet = true;

  /// The payment in progress, checked every [DepositScreen.pollInterval].
  PaymentLink? _payment;
  bool _starting = false;
  bool _checking = false;
  Timer? _poll;
  int _polls = 0;
  static const _maxPolls = 300;

  @override
  void initState() {
    super.initState();
    if (_mobile) _loadOptions();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _options = null;
      _optionsFailed = false;
    });
    try {
      final options = await _service.depositMobileMoneyOptions(
        widget.requestId,
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _choice ??= options.where((o) => o.suggested).firstOrNull;
      });
      await _prefillWallet(options);
    } catch (e) {
      debugPrint('[Deposit] mobile money options: $e');
      if (mounted) setState(() => _optionsFailed = true);
    }
  }

  /// The member's saved wallet (the default first) fills in the country,
  /// network and number.
  Future<void> _prefillWallet(List<MobileMoneyOption> options) async {
    try {
      final methods = await (widget.paymentService ?? PaymentService())
          .methods();
      final wallets =
          methods
              .where(
                (m) =>
                    m.kind == PaymentMethodKind.mobileMoney &&
                    m.mobileNetwork != null &&
                    m.mobileNumber != null,
              )
              .toList()
            ..sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
      for (final w in wallets) {
        final option = options
            .where((o) => o.networks.any((n) => n.code == w.mobileNetwork))
            .firstOrNull;
        if (option == null) continue;
        final code = option.dialCode.replaceAll(RegExp(r'\D'), '');
        final digits = w.mobileNumber!.replaceAll(RegExp(r'\D'), '');
        if (!mounted || _phoneCtrl.text.isNotEmpty) return;
        setState(() {
          _choice = option;
          _pickedNetwork = w.mobileNetwork;
          _phoneCtrl.text = digits.startsWith(code)
              ? digits.substring(code.length)
              : digits;
          _editingWallet = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[Deposit] saved wallet: $e');
    }
  }

  String? get _network {
    final networks = _choice?.networks ?? const [];
    if (networks.length == 1) return networks.single.code;
    return _pickedNetwork;
  }

  /// The number in international form, or null while it isn't a whole one.
  String? get _phone {
    final choice = _choice;
    if (choice == null) return null;
    final phone = internationalPhoneNumber(
      dialCode: choice.dialCode,
      input: _phoneCtrl.text,
      isoCode: choice.countryCode,
    );
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    final code = choice.dialCode.replaceAll(RegExp(r'\D'), '');
    if (!digits.startsWith(code) || digits.length < 10 || digits.length > 15) {
      return null;
    }
    return phone;
  }

  bool get _ready {
    if (!_agreed || _starting) return false;
    if (!_mobile) return true;
    final choice = _choice;
    return choice != null &&
        _phone != null &&
        (choice.networks.isEmpty || _network != null);
  }

  /// What is charged: the mobile money amount, else the declared value.
  String get _chargeText =>
      (_mobile ? _choice?.amountText : null) ?? _d.amountText ?? '';

  Future<void> _pay() async {
    if (!_ready) return;
    setState(() => _starting = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payment = await _service.startPayment(
        widget.requestId,
        _mobile ? PayMethod.mobileMoney : PayMethod.card,
        country: _mobile ? _choice?.countryCode : null,
        phone: _mobile ? _phone : null,
        network: _mobile ? _network : null,
        deposit: true,
      );
      if (!mounted) return;
      final sheet = payment.stripe;
      if (sheet != null) {
        final result = await (widget.presentCardSheet ?? presentStripeSheet)(
          sheet,
        );
        if (!mounted) return;
        switch (result) {
          case CardSheetResult.paid:
            setState(() => _payment = payment);
            _startPolling();
            _check();
          case CardSheetResult.cancelled:
            break;
          case CardSheetResult.failed:
            messenger.showSnackBar(
              nataToast(l.errPaymentFailed, tone: ToastTone.error),
            );
        }
        return;
      }
      // Mobile money: the prompt is on the traveler's phone.
      setState(() => _payment = payment);
      _startPolling();
    } on RequestException catch (e) {
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.notPayable => l.errRequestNotPayable,
          RequestFailure.paymentsUnavailable => l.errPaymentsUnavailable,
          RequestFailure.mobileMoneyUnavailable => l.errMobileMoneyUnavailable,
          RequestFailure.methodNotOffered => l.errMethodNotOffered,
          RequestFailure.phoneRejected => l.errPhoneRejected,
          RequestFailure.amountOutOfBounds => l.errMobileAmountOutOfBounds,
          RequestFailure.networkUnavailable => l.errMobileNetworkUnavailable,
          RequestFailure.rateUnavailable => l.errRateUnavailable,
          RequestFailure.notSignedIn => l.errSessionExpired,
          _ => l.errPaymentStart,
        }, tone: ToastTone.error),
      );
    } catch (e) {
      debugPrint('[Deposit] start payment: $e');
      messenger.showSnackBar(
        nataToast(l.errPaymentStart, tone: ToastTone.error),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
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
      _check();
    });
  }

  /// Asks where the payment stands; [manual] when the traveler tapped
  /// "I've approved it".
  Future<void> _check({bool manual = false}) async {
    final payment = _payment;
    if (payment == null || _checking) return;
    _checking = true;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final status = await _service.paymentStatus(payment.txRef);
      if (!mounted || _payment != payment) return;
      switch (status) {
        case PaymentStatus.successful:
          _poll?.cancel();
          messenger.showSnackBar(
            nataToast(l.depositReceived, tone: ToastTone.success),
          );
          Navigator.of(context).pop(true);
        case PaymentStatus.failed:
          _poll?.cancel();
          setState(() => _payment = null);
          messenger.showSnackBar(
            nataToast(l.errPaymentFailed, tone: ToastTone.error),
          );
        case PaymentStatus.pending:
          if (manual) {
            messenger.showSnackBar(nataToast(l.paymentNotReceivedYet));
          }
      }
    } catch (e) {
      debugPrint('[Deposit] payment status: $e');
      if (manual) {
        messenger.showSnackBar(
          nataToast(l.errRequestFailed, tone: ToastTone.error),
        );
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _summary(),
                  const SizedBox(height: 16),
                  _howItWorks(),
                  const SizedBox(height: 16),
                  if (_payment != null && _mobile)
                    _approveOnPhone()
                  else ...[
                    _method(),
                    const SizedBox(height: 16),
                    _agreement(),
                  ],
                ],
              ),
            ),
            if (_payment == null)
              Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    key: const ValueKey('deposit-pay'),
                    onPressed: _ready ? _pay : null,
                    icon: _starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_rounded, size: 18),
                    label: Text(
                      l.payDepositAmount(_chargeText),
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.foreground,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('deposit-back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            context.l10n.depositTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    ),
  );

  Widget _summary() {
    final l = context.l10n;
    final local = _mobile ? _choice?.amountText : null;
    TextStyle small(Color c) => GoogleFonts.dmSans(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: c,
    );
    Widget pill(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: small(Colors.white60)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      key: const ValueKey('deposit-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.foreground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.depositToPay, style: small(Colors.white60)),
          const SizedBox(height: 6),
          Text(
            _d.amountText ?? '',
            key: const ValueKey('deposit-amount'),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 34,
              color: Colors.white,
            ),
          ),
          if (local != null && local != _d.amountText)
            Text(
              l.depositViaMobile(local),
              key: const ValueKey('deposit-local-amount'),
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white70),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              pill(l.depositDeclaredValue, _d.amountText ?? ''),
              const SizedBox(width: 10),
              pill(
                l.depositYourLimit,
                _d.limitTextIn(
                  PreferencesService().currency.code,
                  ExchangeRateService.shared.latest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Key? key}) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: AppColors.mutedForeground,
    ),
  );

  Widget _howItWorks() {
    final l = context.l10n;
    Widget step(
      IconData icon,
      Color color,
      Color bg,
      String title, [
      String? body,
    ]) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.foreground,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return _card(
      key: const ValueKey('deposit-how'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(l.depositHowItWorks),
          step(
            Icons.lock_rounded,
            AppColors.primary,
            AppColors.secondary,
            l.depositStepHeld,
          ),
          step(
            Icons.replay_rounded,
            const Color(0xFF168A68),
            const Color(0xFFE4F4EE),
            l.depositStepRefund,
          ),
          step(
            Icons.warning_amber_rounded,
            AppColors.destructive,
            const Color(0xFFFEE2E2),
            l.depositStepKept,
            l.depositStepKeptBody,
          ),
        ],
      ),
    );
  }

  Widget _method() {
    final l = context.l10n;
    final Widget body;
    if (!_mobile) {
      body = _methodTile(
        key: const ValueKey('deposit-card'),
        icon: Icons.credit_card_rounded,
        title: l.depositCard,
        subtitle: l.depositCardNote,
      );
    } else if (_optionsFailed) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              l.errMobileMoneyOptions,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ),
          TextButton(onPressed: _loadOptions, child: Text(l.retry)),
        ],
      );
    } else if (_options == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_options!.isEmpty) {
      body = Text(
        l.errMobileMoneyUnavailable,
        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.destructive),
      );
    } else if (!_editingWallet && _choice != null) {
      final network = _choice!.networks
          .where((n) => n.code == _network)
          .firstOrNull;
      body = _methodTile(
        key: const ValueKey('deposit-wallet'),
        icon: Icons.phone_android_rounded,
        title: [
          ?network?.name,
          '${_choice!.dialCode} ${_phoneCtrl.text}',
        ].join(' · '),
        subtitle: _choice!.amountText,
      );
    } else {
      body = _walletEditor(_options!);
    }
    return _card(
      key: const ValueKey('deposit-method'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label(l.depositPaymentMethod)),
              if (_mobile && !_editingWallet)
                GestureDetector(
                  key: const ValueKey('deposit-wallet-change'),
                  onTap: () => setState(() => _editingWallet = true),
                  child: Text(
                    l.change,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }

  Widget _methodTile({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.accent, width: 1.5),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.foreground,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.radio_button_checked_rounded,
          size: 20,
          color: AppColors.accent,
        ),
      ],
    ),
  );

  Widget _walletEditor(List<MobileMoneyOption> options) {
    final l = context.l10n;
    final choice = _choice;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Column(
      key: const ValueKey('deposit-wallet-editor'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('deposit-country'),
          initialValue: choice?.countryCode,
          isExpanded: true,
          hint: Text(l.chooseCountry),
          decoration: InputDecoration(
            labelText: l.mobileMoneyCountry,
            isDense: true,
            filled: true,
            fillColor: AppColors.input,
            border: border,
          ),
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o.countryCode,
                child: Text(
                  '${o.countryName} · ${o.amountText}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (code) => setState(() {
            if (code != _choice?.countryCode) {
              _pickedNetwork = null;
              _phoneCtrl.clear();
            }
            _choice = options.firstWhere((o) => o.countryCode == code);
          }),
        ),
        if (choice != null) ...[
          if (choice.networks.length > 1) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in choice.networks)
                  ChoiceChip(
                    key: ValueKey('deposit-network-${n.code}'),
                    label: Text(n.name),
                    selected: _network == n.code,
                    onSelected: (_) => setState(() => _pickedNetwork = n.code),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('deposit-phone'),
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.mobileMoneyNumber,
              prefixText: '${choice.dialCode}  ',
              isDense: true,
              filled: true,
              fillColor: AppColors.input,
              border: border,
            ),
          ),
        ],
      ],
    );
  }

  Widget _agreement() => GestureDetector(
    key: const ValueKey('deposit-agree'),
    onTap: () => setState(() => _agreed = !_agreed),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              context.l10n.depositAgree,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.4,
                color: AppColors.foreground,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _approveOnPhone() {
    final l = context.l10n;
    return _card(
      key: const ValueKey('deposit-approve'),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text(
            l.approveOnPhone,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.approveOnPhoneSub(_chargeText, _phone ?? ''),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            key: const ValueKey('deposit-check'),
            onPressed: () => _check(manual: true),
            child: Text(l.iApprovedCheckNow),
          ),
          TextButton(
            key: const ValueKey('deposit-cancel'),
            onPressed: () {
              _poll?.cancel();
              setState(() => _payment = null);
            },
            child: Text(l.chooseAnotherWayToPay),
          ),
        ],
      ),
    );
  }
}
