import 'wallet_history_screen.dart';
import 'package:flutter/material.dart';
import 'add_payout_account_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import '../services/preferences_service.dart';
import 'add_payment_method_screen.dart';

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);

/// Payment Settings, opened from Profile: the wallet balance, payment
/// methods, the payout account, preferences and recent transactions.
///
/// Payment methods, payout accounts and the payout schedule are saved in
/// nata.payment_methods / payout_accounts / payment_preferences (see
/// [PaymentService]); the default currency is the app's. Transactions are
/// the latest three from the wallet history, with a link to all of them.
class PaymentSettingsScreen extends StatefulWidget {
  final double availableBalance;
  final double escrowBalance;

  /// The account holder's name ("Fortune Niama").
  final String holderName;

  /// Override for tests; defaults to the real [PaymentService].
  final PaymentService? service;

  const PaymentSettingsScreen({
    super.key,
    required this.availableBalance,
    required this.escrowBalance,
    required this.holderName,
    this.service,
  });

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  late final PaymentService _service = widget.service ?? PaymentService();

  List<PaymentMethod> _methods = const [];
  List<PayoutAccount> _payoutAccounts = const [];
  PayoutSchedule _schedule = PayoutSchedule.automatic;
  bool _loading = true;

  /// A load or save failed: shown above the payment methods. (A message
  /// picker, not the text: a load can fail before context can translate.)
  String Function(AppLocalizations)? _error;

  String get _firstName => widget.holderName.split(' ').first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The latest payouts and payments; null while loading.
  List<WalletEntry>? _recent;

  Future<void> _loadRecent() async {
    try {
      final all = await _service.walletHistory(limit: 3);
      if (mounted) setState(() => _recent = all.take(3).toList());
    } catch (e) {
      debugPrint('[PaymentSettings] history error: $e');
      if (mounted) setState(() => _recent = const []);
    }
  }

  Future<void> _load() async {
    _loadRecent();
    try {
      final results = await Future.wait([
        _service.methods(),
        _service.payoutAccounts(),
        _service.payoutSchedule(),
      ]);
      if (!mounted) return;
      setState(() {
        _methods = results[0] as List<PaymentMethod>;
        _payoutAccounts = results[1] as List<PayoutAccount>;
        _schedule = results[2] as PayoutSchedule;
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

  Future<void> _addPayoutAccount() async {
    final added = await Navigator.of(context).push<PayoutAccount>(
      MaterialPageRoute(
        builder: (_) => AddPayoutAccountScreen(service: widget.service),
      ),
    );
    if (added != null && mounted) _load();
  }

  Future<void> _addMethod() async {
    final added = await Navigator.of(context).push<PaymentMethod>(
      MaterialPageRoute(
        builder: (context) =>
            AddPaymentMethodScreen(holderFirstName: _firstName),
      ),
    );
    if (added == null || !mounted) return;
    await _change(() => _service.addMethod(added));
  }

  Future<void> _removeMethod(PaymentMethod method) =>
      _change(() => _service.removeMethod(method.id));

  /// Saves a change, then reloads: the database also moves the default.
  Future<void> _change(Future<void> Function() save) async {
    try {
      await save();
      await _load();
    } catch (e) {
      debugPrint('[PaymentSettings] save error: $e');
      if (mounted) setState(() => _error = (l) => l.errPaymentSettingsSave);
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

  String _usd(double v) =>
      NumberFormat.currency(symbol: r'$', decimalDigits: 2).format(v);

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
                  _walletCard(l),
                  const SizedBox(height: 16),
                  _paymentMethods(l),
                  const SizedBox(height: 16),
                  _payoutAccount(l),
                  const SizedBox(height: 16),
                  _preferences(l),
                  const SizedBox(height: 16),
                  _transactions(l),
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
              l.paymentSettings,
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

  // ── Wallet ─────────────────────────────────────────────────────────────────
  Widget _walletCard(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.natawallet,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l.availableForPayout,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _usd(widget.availableBalance),
                key: const ValueKey('payment-settings-available'),
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: -0.6,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'USD',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.lock_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_usd(widget.escrowBalance)} ${l.heldInEscrow}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
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
                if (_methods.isEmpty)
                  _empty(l.noPaymentMethods)
                else
                  _list([
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
                        trailing: m.isDefault
                            ? _chip(l.defaultLabel)
                            : GestureDetector(
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
                      ),
                  ]),
              ],
            ),
    );
  }

  // ── Payout account ─────────────────────────────────────────────────────────
  Widget _payoutAccount(AppLocalizations l) {
    return _section(
      title: l.payoutAccount,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.payoutAccountNote,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                height: 1.6,
                color: AppColors.mutedForeground,
              ),
            ),
            for (final a in _payoutAccounts) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _iconBox(
                      Icons.account_balance_rounded,
                      bg: _green.withValues(alpha: 0.15),
                      color: _green,
                      radius: 8,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _titled(a.institutionName, a.summary)),
                    if (a.isDefault)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: _green,
                      ),
                  ],
                ),
              ),
            ],
            if (!_loading && _payoutAccounts.isEmpty) ...[
              const SizedBox(height: 12),
              _empty(l.noPayoutAccount),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('payout-account-add'),
              onPressed: _addPayoutAccount,
              icon: const Icon(Icons.add_circle_rounded, size: 16),
              label: Text(
                l.addPayoutAccount,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
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
        _row(
          leading: _iconBox(Icons.calendar_month_rounded),
          title: l.payoutSchedule,
          subtitle: l.payoutScheduleSub,
          trailing: _accentText(switch (_schedule) {
            PayoutSchedule.automatic => l.automatic,
            PayoutSchedule.weekly => l.weekly,
            PayoutSchedule.manual => l.manual,
          }),
        ),
      ]),
    );
  }

  // ── Transactions ───────────────────────────────────────────────────────────
  Widget _transactions(AppLocalizations l) {
    final recent = _recent;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return _section(
      title: l.transactions,
      action: GestureDetector(
        key: const ValueKey('payment-transactions-all'),
        onTap: () {
          final money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WalletHistoryScreen(
                available: money.format(widget.availableBalance),
                inEscrow: money.format(widget.escrowBalance),
                service: widget.service,
              ),
            ),
          );
        },
        child: Text(
          l.viewAll,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.accent,
          ),
        ),
      ),
      child: recent == null
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          : recent.isEmpty
          ? Container(
              key: const ValueKey('payment-transactions-empty'),
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Text(
                l.walletEmpty,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          : Column(
              children: [
                for (final e in recent)
                  WalletEntryRow(entry: e, locale: locale),
              ],
            ),
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
