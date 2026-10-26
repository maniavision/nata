import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/exchange_rate_service.dart';
import '../services/payment_service.dart';
import '../services/preferences_service.dart';
import '../services/wallet_money.dart';

const _success = Color(0xFF168A68);

/// "\$45.00 added to your wallet" on Home (designed in Sleek, "Home (Money
/// Added)"): once a traveler is paid for a delivery, until they open the
/// wallet from it or close it with ✕ (remembered on this device, per member).
/// Payouts older than a week aren't celebrated.
class WalletAddedCard extends StatefulWidget {
  final String? userId;
  final PaymentService? service;

  /// Opens the wallet history.
  final VoidCallback onView;

  /// Lets tests fix "now".
  final DateTime Function() now;

  const WalletAddedCard({
    super.key,
    required this.userId,
    required this.onView,
    this.service,
    this.now = DateTime.now,
  });

  static String seenKey(String userId) => 'wallet_added_seen_$userId';

  @override
  State<WalletAddedCard> createState() => _WalletAddedCardState();
}

class _WalletAddedCardState extends State<WalletAddedCard> {
  /// The payouts not yet acknowledged, newest first.
  List<WalletEntry> _added = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WalletAddedCard old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final id = widget.userId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = DateTime.tryParse(
        prefs.getString(WalletAddedCard.seenKey(id)) ?? '',
      );
      final since = widget.now().subtract(const Duration(days: 7));
      final history = await (widget.service ?? PaymentService()).walletHistory(
        limit: 20,
      );
      final added = [
        for (final e in history)
          if (e.kind == WalletEntryKind.payout &&
              e.amount > 0 &&
              e.date.isAfter(since) &&
              (seen == null || e.date.isAfter(seen)))
            e,
      ]..sort((a, b) => b.date.compareTo(a.date));
      if (mounted) setState(() => _added = added);
    } catch (e) {
      debugPrint('[WalletAddedCard] $e');
    }
  }

  Future<void> _acknowledge() async {
    final id = widget.userId;
    if (id == null || _added.isEmpty) return;
    final newest = _added.first.date;
    setState(() => _added = const []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        WalletAddedCard.seenKey(id),
        newest.toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  /// One payout or several in one currency: in that currency. Several in
  /// different currencies: their total in the member's currency.
  String _amount() {
    final currencies = {for (final e in _added) e.currency};
    if (currencies.length == 1) {
      final total = _added.fold<double>(0, (sum, e) => sum + e.amount);
      return WalletMoney.inCurrency(total, currencies.first);
    }
    final rates = ExchangeRateService.shared.latest;
    final usd = WalletMoney.sumInUsd([
      for (final e in _added) {'amount': e.amount, 'currency': e.currency},
    ], rates);
    return WalletMoney.format(usd, PreferencesService().currency.code, rates);
  }

  String _body() {
    final l = context.l10n;
    if (_added.length > 1) return l.walletAddedMany(_added.length);
    final e = _added.first;
    final item = e.item, from = e.fromCity, to = e.toCity;
    if (item == null || from == null || to == null) return l.walletAddedOne;
    final name = e.otherName?.trim() ?? '';
    return name.isEmpty
        ? l.walletAddedFor(item, from, to)
        : l.walletAddedForName(item, from, to, name);
  }

  @override
  Widget build(BuildContext context) {
    if (_added.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final amount = _amount();
    // The amount in bold, wherever the language puts it.
    final title = l.walletAddedTitle('\u0000').split('\u0000');
    final titleStyle = GoogleFonts.manrope(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: AppColors.foreground,
    );
    return Padding(
      key: const ValueKey('wallet-added'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                _success.withValues(alpha: 0.10),
                AppColors.card,
              ),
              AppColors.card,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _success.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: _success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: AppColors.card,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: titleStyle,
                      children: [
                        TextSpan(text: title.first),
                        TextSpan(
                          text: amount,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (title.length > 1) TextSpan(text: title.last),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _body(),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 30,
                    child: FilledButton(
                      key: const ValueKey('wallet-added-view'),
                      onPressed: () {
                        _acknowledge();
                        widget.onView();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      child: Text(l.walletAddedView),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('wallet-added-dismiss'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: _acknowledge,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
