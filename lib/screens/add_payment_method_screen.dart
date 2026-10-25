import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import '../services/phone_number.dart';
import '../widgets/one_line_text.dart';

/// Card checks, kept apart from the screen so they can be tested.
class CardInput {
  /// The digits of a card number, without spaces.
  static String digits(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// A plausible card number: 13 to 19 digits passing the Luhn checksum.
  static bool isValidNumber(String input) {
    final d = digits(input);
    if (d.length < 13 || d.length > 19) return false;
    var sum = 0;
    for (var i = 0; i < d.length; i++) {
      var n = int.parse(d[d.length - 1 - i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    return sum % 10 == 0;
  }

  /// "MM/YY" for a month that has not ended yet ([now] for tests).
  static bool isValidExpiry(String input, {DateTime? now}) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(input.trim());
    if (m == null) return false;
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    if (month < 1 || month > 12) return false;
    final today = now ?? DateTime.now();
    // Valid through the last day of the expiry month.
    return !DateTime(
      year,
      month + 1,
    ).isBefore(DateTime(today.year, today.month + 1));
  }

  static bool isValidCvv(String input) =>
      RegExp(r'^\d{3,4}$').hasMatch(input.trim());

  /// The card network from the number's first digits.
  static String brand(String input) {
    final d = digits(input);
    if (d.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(d)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(d)) return 'American Express';
    return 'Card';
  }
}

/// Groups card digits by four as the user types: "4242 4242 4242 4242".
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final d = CardInput.digits(newValue.text);
    final capped = d.length > 19 ? d.substring(0, 19) : d;
    final text = [
      for (var i = 0; i < capped.length; i += 4)
        capped.substring(i, i + 4 > capped.length ? capped.length : i + 4),
    ].join(' ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Adds the "/" in an expiry date as the user types: "0827" -> "08/27".
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = CardInput.digits(newValue.text);
    if (d.length > 4) d = d.substring(0, 4);
    final text = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Add Payment Method, opened from Payment Settings. What can be saved
/// follows where the member lives (my_payment_options, 20240174): a mobile
/// money wallet on their country's pawaPay networks when they live in such a
/// country, else a card or Apple Pay. Pops with the new (unsaved)
/// [PaymentMethod] once it is valid; Payment Settings saves it.
class AddPaymentMethodScreen extends StatefulWidget {
  /// The account holder's first name, for "Fortune's iPhone".
  final String holderFirstName;

  /// Override for tests; defaults to [PaymentService.paymentOptions].
  final Future<PaymentOptions> Function()? loadOptions;

  const AddPaymentMethodScreen({
    super.key,
    required this.holderFirstName,
    this.loadOptions,
  });

  @override
  State<AddPaymentMethodScreen> createState() => _AddPaymentMethodScreenState();
}

class _AddPaymentMethodScreenState extends State<AddPaymentMethodScreen> {
  /// What the member can save; null while loading (cards and Apple Pay if it
  /// can't be had: the database refuses what doesn't fit anyway).
  PaymentOptions? _options;
  String? _network;

  PaymentMethodKind _kind = PaymentMethodKind.card;
  bool _setAsDefault = false;
  String? _error;

  final _cardNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _mobileNumberCtrl = TextEditingController();
  final _mobileNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    PaymentOptions options;
    try {
      options =
          await (widget.loadOptions ??
              () => PaymentService().paymentOptions())();
    } catch (e) {
      debugPrint('[AddPaymentMethod] options: $e');
      options = PaymentOptions.cards;
    }
    if (!mounted) return;
    setState(() {
      _options = options;
      _kind = options.mobileMoney
          ? PaymentMethodKind.mobileMoney
          : PaymentMethodKind.card;
      // A country's only network is chosen already.
      if (options.networks.length == 1) _network = options.networks.single.code;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _cardNameCtrl,
      _cardNumberCtrl,
      _expiryCtrl,
      _cvvCtrl,
      _mobileNumberCtrl,
      _mobileNameCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l = context.l10n;
    PaymentMethod? method;
    String? error;
    switch (_kind) {
      case PaymentMethodKind.card:
        final number = CardInput.digits(_cardNumberCtrl.text);
        final expiry = RegExp(
          r'^(\d{2})/(\d{2})$',
        ).firstMatch(_expiryCtrl.text.trim());
        if (_cardNameCtrl.text.trim().length < 2) {
          error = l.errCardName;
        } else if (!CardInput.isValidNumber(number)) {
          error = l.errCardNumber;
        } else if (expiry == null ||
            !CardInput.isValidExpiry(_expiryCtrl.text)) {
          error = l.errCardExpiry;
        } else if (!CardInput.isValidCvv(_cvvCtrl.text)) {
          error = l.errCardCvv;
        } else {
          // Only the brand and last 4 digits leave this screen: never the
          // full number or the CVV.
          method = PaymentMethod(
            kind: PaymentMethodKind.card,
            cardBrand: CardInput.brand(number),
            cardLast4: number.substring(number.length - 4),
            cardExpMonth: int.parse(expiry.group(1)!),
            cardExpYear: 2000 + int.parse(expiry.group(2)!),
            cardHolderName: _cardNameCtrl.text.trim(),
          );
        }
      case PaymentMethodKind.mobileMoney:
        final options = _options ?? PaymentOptions.cards;
        final network = options.networks
            .where((n) => n.code == _network)
            .firstOrNull;
        final phone = _walletNumber(options);
        if (network == null) {
          error = l.errChooseNetwork;
        } else if (phone == null) {
          error = l.errWholeMobileNumber;
        } else if (_mobileNameCtrl.text.trim().length < 2) {
          error = l.errRegisteredName;
        } else {
          method = PaymentMethod(
            kind: PaymentMethodKind.mobileMoney,
            mobileProvider: network.name,
            mobileNetwork: network.code,
            mobileNumber: phone,
            mobileRegisteredName: _mobileNameCtrl.text.trim(),
          );
        }
      case PaymentMethodKind.applePay:
        method = PaymentMethod(
          kind: PaymentMethodKind.applePay,
          walletDeviceLabel: l.holdersIphone(widget.holderFirstName),
        );
    }
    if (method == null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(method.copyWith(isDefault: _setAsDefault));
  }

  /// The wallet's number with the country's calling code (+ code and
  /// number), or null while it isn't a whole one.
  String? _walletNumber(PaymentOptions options) {
    final phone = internationalPhoneNumber(
      dialCode: options.dialCode,
      input: _mobileNumberCtrl.text,
      isoCode: options.countryCode,
    );
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    final code = options.dialCode.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty ||
        !digits.startsWith(code) ||
        digits.length < 10 ||
        digits.length > 15) {
      return null;
    }
    return '+$digits';
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
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
            _header(l),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _securityNote(l),
                  const SizedBox(height: 16),
                  if (_options == null)
                    const Padding(
                      key: ValueKey('add-payment-loading'),
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  else if (_options!.mobileMoney) ...[
                    // Mobile money only: no tabs, and why.
                    _mobileOnlyNote(l, _options!),
                    const SizedBox(height: 12),
                    _mobileForm(l),
                  ] else ...[
                    _kindTabs(l),
                    const SizedBox(height: 16),
                    switch (_kind) {
                      PaymentMethodKind.card => _cardForm(l),
                      PaymentMethodKind.mobileMoney => _cardForm(l),
                      PaymentMethodKind.applePay => _appleNote(l),
                    },
                  ],
                  const SizedBox(height: 16),
                  _defaultToggle(l),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('add-payment-error'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _footer(l, bottom),
          ],
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('add-payment-back'),
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
                size: 20,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.addPaymentMethod,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.4,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityNote(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.verified_user_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.paymentSecurityNote,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                height: 1.6,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindTabs(AppLocalizations l) {
    Widget tab(
      PaymentMethodKind kind,
      IconData icon,
      String title,
      String subtitle,
    ) {
      final selected = _kind == kind;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('add-payment-kind-${kind.name}'),
          onTap: () => setState(() {
            _kind = kind;
            _error = null;
          }),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? AppColors.primaryForeground
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tab(
            PaymentMethodKind.card,
            Icons.credit_card_rounded,
            l.paymentKindCard,
            l.paymentKindCardSub,
          ),
          const SizedBox(width: 8),
          tab(
            PaymentMethodKind.applePay,
            Icons.apple,
            'Apple Pay',
            l.paymentKindAppleSub,
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardForm(AppLocalizations l) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(l.cardDetails),
          const SizedBox(height: 14),
          _label(l.nameOnCard),
          _field(
            fieldKey: 'add-payment-card-name',
            icon: Icons.person_rounded,
            controller: _cardNameCtrl,
            hint: l.nameOnCardHint,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _label(l.cardNumber),
          _field(
            fieldKey: 'add-payment-card-number',
            icon: Icons.credit_card_rounded,
            controller: _cardNumberCtrl,
            hint: '1234 5678 9012 3456',
            keyboardType: TextInputType.number,
            formatters: [_CardNumberFormatter()],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(l.expiryDate, small: true),
                    _field(
                      fieldKey: 'add-payment-card-expiry',
                      icon: Icons.calendar_month_rounded,
                      controller: _expiryCtrl,
                      hint: context.l10n.expiryHint,
                      keyboardType: TextInputType.number,
                      formatters: [_ExpiryFormatter()],
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('CVV', small: true),
                    _field(
                      fieldKey: 'add-payment-card-cvv',
                      icon: Icons.lock_rounded,
                      controller: _cvvCtrl,
                      hint: '•••',
                      keyboardType: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      obscure: true,
                      compact: true,
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

  /// "You live in …, so you pay by mobile money."
  Widget _mobileOnlyNote(AppLocalizations l, PaymentOptions options) {
    return Row(
      key: const ValueKey('add-payment-mobile-only'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.paymentMobileOnlyNote(options.countryName),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileForm(AppLocalizations l) {
    final options = _options ?? PaymentOptions.cards;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _title(l.mobileMoneyDetails),
          const SizedBox(height: 14),
          _label(l.mobileMoneyNetwork),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in options.networks)
                _networkPill(n.code, n.name, selected: _network == n.code),
            ],
          ),
          const SizedBox(height: 14),
          _label(l.mobileNumber),
          _field(
            fieldKey: 'add-payment-mobile-number',
            icon: Icons.phone_rounded,
            controller: _mobileNumberCtrl,
            hint: '',
            keyboardType: TextInputType.phone,
            prefixText: options.dialCode.isEmpty
                ? null
                : '${options.dialCode}  ',
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-().\s]')),
            ],
          ),
          const SizedBox(height: 14),
          _label(l.registeredName),
          _field(
            fieldKey: 'add-payment-mobile-name',
            icon: Icons.person_rounded,
            controller: _mobileNameCtrl,
            hint: l.registeredNameHint,
            capitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _networkPill(String code, String name, {required bool selected}) {
    return GestureDetector(
      key: ValueKey('add-payment-network-$code'),
      onTap: () => setState(() {
        _network = code;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          name,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppColors.primaryForeground
                : AppColors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _appleNote(AppLocalizations l) {
    return _card(
      child: Text(
        l.applePayNote,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          height: 1.6,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _defaultToggle(AppLocalizations l) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.setAsDefault,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  l.setAsDefaultSub,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            key: const ValueKey('add-payment-default'),
            value: _setAsDefault,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _setAsDefault = v ?? false),
          ),
        ],
      ),
    );
  }

  Widget _footer(AppLocalizations l, double bottom) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          key: const ValueKey('add-payment-save'),
          onPressed: _save,
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: Text(
            l.savePaymentMethod,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
    text,
    style: GoogleFonts.manrope(
      fontWeight: FontWeight.w800,
      fontSize: 14,
      color: AppColors.foreground,
    ),
  );

  Widget _label(String text, {bool small = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    // One line in every language, so side-by-side fields line up.
    child: OneLineText(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: small ? 10 : 12,
        letterSpacing: small ? 1.2 : 1.44,
        color: AppColors.mutedForeground,
      ),
    ),
  );

  BoxDecoration _fieldDecoration() => BoxDecoration(
    color: AppColors.input,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  );

  Widget _field({
    required String fieldKey,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    bool compact = false,
    String? prefixText,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
      decoration: _fieldDecoration(),
      child: Row(
        children: [
          Icon(icon, size: compact ? 16 : 18, color: AppColors.primary),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: TextField(
              key: ValueKey(fieldKey),
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: capitalization,
              inputFormatters: formatters,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => _clearError(),
              style: GoogleFonts.dmSans(
                fontWeight: compact ? FontWeight.w700 : FontWeight.w600,
                fontSize: compact ? 12 : 14,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: hint,
                prefixText: prefixText,
                prefixStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 14,
                  color: AppColors.mutedForeground,
                ),
                hintStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 12 : 14,
                  color: AppColors.mutedForeground,
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: compact ? 11 : 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
