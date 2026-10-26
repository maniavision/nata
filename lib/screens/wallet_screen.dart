import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/payment_service.dart';
import '../services/preferences_service.dart';
import '../services/wallet_money.dart';
import '../widgets/coach_tips.dart';
import '../widgets/nata_toast.dart';
import '../widgets/page_header.dart';
import 'payment_settings_screen.dart';
import 'wallet_history_screen.dart';
import '../services/screen_cache.dart';

/// The member's wallet (designed in Sleek, "Wallet"): the Nata Wallet card
/// with what's available and what's held in escrow, Payment Settings, and
/// the payouts and payments. Opened from Profile and from Home's balance.
class WalletScreen extends StatefulWidget {
  /// Overrides for tests; default to the real services.
  final AuthService? authService;
  final PaymentService? paymentService;

  const WalletScreen({super.key, this.authService, this.paymentService});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  /// What the page showed last time (ScreenCache), shown straight away.
  static const _kWallet = 'wallet';
  late final _kept = ScreenCache.read<Map<String, Object?>>(_kWallet);
  late double _available = _kept?['available'] as double? ?? 0;
  late double _escrow = _kept?['escrow'] as double? ?? 0;
  late String _holderName = _kept?['holder'] as String? ?? '';

  void _remember() => ScreenCache.write(_kWallet, {
    'available': _available,
    'escrow': _escrow,
    'holder': _holderName,
  });
  StreamSubscription<Map<String, double>>? _balances;

  /// Bumped to reload the activity after Payment Settings.
  int _activityVersion = 0;

  final _cardTipKey = GlobalKey();
  final _settingsTipKey = GlobalKey();

  AuthService get _auth => widget.authService ?? AuthService();

  @override
  void initState() {
    super.initState();
    _load();
    _loadRates();
    _balances = _auth.walletBalancesStream().listen(
      _setBalances,
      onError: (Object e) => debugPrint('[Wallet] balance stream: $e'),
    );
    CoachTips.showWhenSettled(
      context,
      name: 'wallet',
      tips: () => [
        CoachTip(
          target: _cardTipKey,
          icon: Icons.account_balance_wallet_outlined,
          title: context.l10n.tipWalletTitle,
          body: context.l10n.tipWalletBody,
        ),
        CoachTip(
          target: _settingsTipKey,
          icon: Icons.payments_outlined,
          title: context.l10n.tipPayoutTitle,
          body: context.l10n.tipPayoutBody,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _balances?.cancel();
    super.dispose();
  }

  void _setBalances(Map<String, double> balances) {
    if (!mounted) return;
    setState(() {
      _available = balances['available'] ?? 0.0;
      _escrow = balances['escrow'] ?? 0.0;
    });
    _remember();
  }

  Future<void> _load() async {
    try {
      final (balances, profile) = await (
        _auth.getWalletBalances(),
        _auth.getProfile(),
      ).wait;
      _setBalances(balances);
      if (profile != null && mounted) {
        final first = '${profile['first_name'] ?? ''}'.trim();
        final last = '${profile['last_name'] ?? ''}'.trim();
        setState(() => _holderName = '$first $last'.trim());
        _remember();
      }
    } catch (e) {
      debugPrint('[Wallet] load: $e');
    }
  }

  /// The wallet is shown in the member's currency once the rates are here
  /// (in dollars until then).
  Future<void> _loadRates() async {
    if (ExchangeRateService.shared.latest != null) return;
    try {
      await ExchangeRateService.shared.rates();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[Wallet] rates: $e');
    }
  }

  String _money(double usd) => WalletMoney.format(
    usd,
    PreferencesService().currency.code,
    ExchangeRateService.shared.latest,
  );

  String get _shownCurrency => WalletMoney.shown(
    PreferencesService().currency.code,
    ExchangeRateService.shared.latest,
  );

  Future<void> _openPaymentSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentSettingsScreen(
          availableBalance: _available,
          escrowBalance: _escrow,
          holderName: _holderName,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _activityVersion++);
    _load();
  }

  /// Sends the payouts waiting for this traveler (they also go out by
  /// themselves after each delivery).
  Future<void> _withdraw() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sent = await (widget.paymentService ?? PaymentService())
          .sendPayouts();
      messenger.showSnackBar(
        nataToast(
          sent > 0 ? l.withdrawSent(sent) : l.withdrawNothing,
          tone: sent > 0 ? ToastTone.success : ToastTone.info,
        ),
      );
    } catch (e) {
      debugPrint('[Wallet] withdraw: $e');
      messenger.showSnackBar(
        nataToast(l.errRequestFailed, tone: ToastTone.error),
      );
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
            PageHeader(title: l.wallet),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + bottom),
                children: [
                  KeyedSubtree(key: _cardTipKey, child: _walletCard()),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: _settingsTipKey,
                    child: _paymentSettingsRow(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.walletActivity,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  WalletActivity(
                    key: ValueKey(_activityVersion),
                    service: widget.paymentService,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentSettingsRow() {
    final l = context.l10n;
    return GestureDetector(
      key: const ValueKey('wallet-payment-settings'),
      onTap: _openPaymentSettings,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
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
              child: const Icon(
                Icons.credit_card_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.paymentSettings,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    l.paymentSettingsSub,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  // ── Wallet card ────────────────────────────────────────────────────────────
  Widget _walletCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      // The blob is cut by the card's rounded edge, not by its padding.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative blob
          Positioned(
            right: -40,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Column(
            children: [
              // Top row
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
                  Expanded(
                    child: Text(
                      context.l10n.natawallet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n.escrowProtected,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Balance + withdraw
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.availableForPayout,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _money(_available),
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: Colors.white,
                                letterSpacing: -1.0,
                              ),
                            ),
                            if (WalletMoney.hasSymbol(_shownCurrency)) ...[
                              const SizedBox(width: 6),
                              Text(
                                _shownCurrency,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: const ValueKey('wallet-withdraw'),
                    onTap: _withdraw,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        context.l10n.withdraw,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              // Escrow row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_money(_escrow)} ${context.l10n.heldInEscrow}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
