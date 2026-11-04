import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import '../services/preferences_service.dart';
import '../services/stripe_sheet.dart';
import 'add_payment_method_screen.dart';

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);

/// Payment methods, opened from Profile: the cards saved with Stripe and the
/// mobile money wallets that pay Nata's fees, and the display currency.
/// There is no wallet any more: senders pay travelers directly (20240201).
///
/// Mobile money wallets are saved in nata.payment_methods (see
/// [PaymentService]); the default currency is the app's.
class PaymentSettingsScreen extends StatefulWidget {
  /// The account holder's name ("Fortune Niama").
  final String holderName;

  /// Override for tests; defaults to the real [PaymentService].
  final PaymentService? service;

  const PaymentSettingsScreen({
    super.key,
    required this.holderName,
    this.service,
  });

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  late final PaymentService _service = widget.service ?? PaymentService();

  List<PaymentMethod> _methods = const [];

  /// Cards saved with Stripe (20240196), the default first.
  List<StripeCard> _cards = const [];
  bool _loading = true;

  /// A load or save failed: shown above the payment methods. (A message
  /// picker, not the text: a load can fail before context can translate.)
  String Function(AppLocalizations)? _error;

  String get _firstName => widget.holderName.split(' ').first;

  @override
  void initState() {
    super.initState();
    PreferencesService().addListener(_onPrefsChanged);
    _load();
  }

  @override
  void dispose() {
    PreferencesService().removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCards() async {
    try {
      final cards = await _service.stripeCards();
      if (mounted) setState(() => _cards = cards);
    } catch (e) {
      debugPrint('[PaymentSettings] cards: $e');
    }
  }

  Future<void> _load() async {
    _loadCards();
    try {
      final methods = await _service.methods();
      if (!mounted) return;
      setState(() {
        // Cards live with Stripe now; older card rows (a brand and last 4
        // digits only) can't pay.
        _methods = [
          for (final m in methods)
            if (m.kind != PaymentMethodKind.card) m,
        ];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('[PaymentSettings] load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = (l) => l.errPaymentSettingsLoad;
      });
    }
  }

  Future<void> _addMethod() async {
    final added = await Navigator.of(context).push<PaymentMethod>(
      MaterialPageRoute(
        builder: (context) => AddPaymentMethodScreen(
          holderFirstName: _firstName,
          addCard: ({required bool makeDefault}) => _service.addStripeCard(
            present: presentStripeSetupSheet,
            makeDefault: makeDefault,
          ),
        ),
      ),
    );
    if (added == null || !mounted) return;
    // A card is already saved with Stripe by then.
    if (added.kind == PaymentMethodKind.card) {
      await _loadCards();
      return;
    }
    await _change(() => _service.addMethod(added));
  }

  /// Asks first: removing the default makes the latest other method the
  /// default.
  Future<void> _removeMethod(PaymentMethod method) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('payment-method-remove-dialog'),
        title: Text(l.removePaymentMethodTitle),
        content: Text(
          method.isDefault && _methods.length > 1
              ? l.removeDefaultPaymentMethodBody(method.title)
              : l.removePaymentMethodBody(method.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const ValueKey('payment-method-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(() => _service.removeMethod(method.id));
  }

  Future<void> _removeCard(StripeCard card) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('stripe-card-remove-dialog'),
        title: Text(l.removePaymentMethodTitle),
        content: Text(
          card.isDefault && _cards.length > 1
              ? l.removeDefaultPaymentMethodBody(card.title)
              : l.removePaymentMethodBody(card.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            key: const ValueKey('stripe-card-remove-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: Text(l.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _changeCards(() => _service.removeStripeCard(card.id));
  }

  /// A change to the Stripe cards, which answers with them.
  Future<void> _changeCards(Future<List<StripeCard>> Function() save) async {
    try {
      final cards = await save();
      if (mounted) {
        setState(() {
          _cards = cards;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('[PaymentSettings] card change: $e');
      if (mounted) setState(() => _error = (l) => l.errPaymentSettingsSave);
    }
  }

  /// Saves a change, then reloads: the database also moves the default.
  Future<void> _change(Future<void> Function() save) async {
    try {
      await save();
      await _load();
    } catch (e) {
      debugPrint('[PaymentSettings] save error: $e');
      // Not what fits where the member lives (20240174).
      final notOffered = '$e'.contains('_not_offered');
      if (mounted) {
        setState(
          () => _error = (l) => notOffered
              ? l.errPaymentMethodNotOffered
              : l.errPaymentSettingsSave,
        );
      }
    }
  }

  static ({IconData icon, Color bg, Color fg}) _look(PaymentMethodKind kind) =>
      switch (kind) {
        PaymentMethodKind.applePay => (
          icon: Icons.apple,
          bg: Colors.black,
          fg: Colors.white,
        ),
        PaymentMethodKind.card => (
          icon: Icons.credit_card_rounded,
          bg: AppColors.secondary,
          fg: AppColors.primary,
        ),
        PaymentMethodKind.mobileMoney => (
          icon: Icons.smartphone_rounded,
          bg: AppColors.secondary,
          fg: AppColors.primary,
        ),
      };

  /// The wallet's dollar figures in the member's currency.
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
                padding: EdgeInsets.fromLTRB(20, 16, 20, 40 + bottom),
                children: [
                  _paymentMethods(l),
                  const SizedBox(height: 16),
                  _preferences(l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
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
            key: const ValueKey('payment-settings-back'),
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
              l.paymentMethodsRow,
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

  // ── Payment methods ────────────────────────────────────────────────────────
  Widget _paymentMethods(AppLocalizations l) {
    return _section(
      title: l.paymentMethods,
      action: GestureDetector(
        key: const ValueKey('payment-methods-add'),
        onTap: _addMethod,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_circle_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              l.add,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(
                    _error!(l),
                    key: const ValueKey('payment-settings-error'),
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.destructive,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_methods.isEmpty && _cards.isEmpty)
                  _empty(l.noPaymentMethods)
                else
                  _list([
                    for (final c in _cards)
                      _row(
                        leading: _iconBox(
                          Icons.credit_card_rounded,
                          radius: 8,
                          size: 20,
                        ),
                        title: c.title,
                        subtitle: l.cardExpires(c.expiry),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Which card is offered first, once there are
                            // several.
                            if (c.isDefault && _cards.length > 1)
                              _chip(l.defaultLabel)
                            else if (!c.isDefault)
                              GestureDetector(
                                key: ValueKey('stripe-card-default-${c.id}'),
                                onTap: () => _changeCards(
                                  () => _service.setDefaultStripeCard(c.id),
                                ),
                                child: Text(
                                  l.makeDefault,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              key: ValueKey('stripe-card-remove-${c.id}'),
                              onTap: () => _removeCard(c),
                              child: Text(
                                l.remove,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final m in _methods)
                      _row(
                        leading: _iconBox(
                          _look(m.kind).icon,
                          bg: _look(m.kind).bg,
                          color: _look(m.kind).fg,
                          radius: 8,
                          size: 20,
                        ),
                        title: m.title,
                        subtitle: m.subtitle(l),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (m.isDefault) ...[
                              _chip(l.defaultLabel),
                              const SizedBox(width: 10),
                            ],
                            GestureDetector(
                              key: ValueKey('payment-method-remove-${m.id}'),
                              onTap: () => _removeMethod(m),
                              child: Text(
                                l.remove,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ]),
                if (_cards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    key: const ValueKey('stripe-cards-note'),
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l.stripeCardsNote,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  // ── Preferences ────────────────────────────────────────────────────────────
  Widget _preferences(AppLocalizations l) {
    final currency = PreferencesService().currency;
    return _section(
      title: l.preferences,
      child: _list([
        _row(
          leading: _iconBox(Icons.credit_card_rounded),
          title: l.defaultCurrency,
          subtitle: l.defaultCurrencySub,
          trailing: _accentText('${currency.code} (${currency.symbol})'),
        ),
      ]),
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────
  Widget _section({
    required String title,
    Widget? action,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.6,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _empty(String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _cardDecoration(),
    child: Text(
      text,
      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.mutedForeground),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
    ],
  );

  Widget _list(List<Widget> rows) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(color: AppColors.border, height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row({
    Widget? leading,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(child: _titled(title, subtitle)),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _titled(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 12,
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
    );
  }

  Widget _iconBox(
    IconData icon, {
    Color bg = AppColors.secondary,
    Color color = AppColors.primary,
    double radius = 12,
    double size = 18,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w800,
          fontSize: 10,
          color: _green,
        ),
      ),
    );
  }

  Widget _accentText(String text) => Text(
    text,
    style: GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 12,
      color: AppColors.accent,
    ),
  );
}
