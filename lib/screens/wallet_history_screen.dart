import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import '../services/request_service.dart';
import '../widgets/page_header.dart';

enum _Filter { all, payouts, payments }

/// The user's payouts and payments, newest first, grouped by month. Opened
/// from "View History" on the Profile wallet card.
class WalletHistoryScreen extends StatefulWidget {
  /// The wallet card's figures, already formatted.
  final String available;
  final String inEscrow;

  /// Override for tests; defaults to the real [PaymentService].
  final PaymentService? service;

  const WalletHistoryScreen({
    super.key,
    required this.available,
    required this.inEscrow,
    this.service,
  });

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  List<WalletEntry>? _entries;
  bool _failed = false;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final entries = await (widget.service ?? PaymentService())
          .walletHistory();
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      debugPrint('[WalletHistory] load error: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  List<WalletEntry> get _shown => [
    for (final e in _entries ?? const <WalletEntry>[])
      if (_filter == _Filter.all ||
          (_filter == _Filter.payouts) == (e.kind == WalletEntryKind.payout))
        e,
  ];

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
            PageHeader(title: l.walletHistory),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + bottom),
                children: [
                  _summary(l),
                  const SizedBox(height: 16),
                  _filters(l),
                  const SizedBox(height: 8),
                  ..._list(l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(AppLocalizations l) {
    Widget figure(String label, String value, {required Key key}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.primaryForeground.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                key: key,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.primaryForeground,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          figure(
            l.walletAvailable,
            widget.available,
            key: const ValueKey('wallet-history-available'),
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.primaryForeground.withValues(alpha: 0.2),
          ),
          figure(
            l.walletInEscrow,
            widget.inEscrow,
            key: const ValueKey('wallet-history-escrow'),
          ),
        ],
      ),
    );
  }

  Widget _filters(AppLocalizations l) {
    Widget chip(_Filter f, String label) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          key: ValueKey('wallet-filter-${f.name}'),
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected
                    ? AppColors.primaryForeground
                    : AppColors.foreground,
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_Filter.all, l.walletFilterAll),
          chip(_Filter.payouts, l.walletFilterPayouts),
          chip(_Filter.payments, l.walletFilterPayments),
        ],
      ),
    );
  }

  List<Widget> _list(AppLocalizations l) {
    if (_failed) {
      return [
        const SizedBox(height: 32),
        Text(
          l.errWalletHistory,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: _load, child: Text(l.retry)),
        ),
      ];
    }
    if (_entries == null) {
      return const [
        SizedBox(height: 48),
        Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ];
    }
    final shown = _shown;
    if (shown.isEmpty) {
      return [
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('wallet-history-empty'),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 32,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(height: 10),
              Text(
                l.walletEmpty,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final month = DateFormat('MMMM yyyy', locale);
    final widgets = <Widget>[];
    String? current;
    for (final e in shown) {
      final m = toBeginningOfSentenceCase(month.format(e.date), locale);
      if (m != current) {
        current = m;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              m,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        );
      }
      widgets.add(_EntryRow(entry: e, locale: locale));
    }
    return widgets;
  }
}

class _EntryRow extends StatelessWidget {
  final WalletEntry entry;
  final String locale;

  const _EntryRow({required this.entry, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final payout = entry.kind == WalletEntryKind.payout;
    final item = entry.item?.trim();
    final title = item == null || item.isEmpty
        ? (payout ? l.walletPayoutFallback : l.walletPaymentFallback)
        : (payout ? l.walletPayoutTitle(item) : l.walletPaymentTitle(item));
    final route = entry.fromCity != null && entry.toCity != null
        ? '${entry.fromCity} → ${entry.toCity}'
        : null;
    final who = !payout && entry.otherName != null
        ? l.walletPaymentTo(entry.otherName!)
        : null;
    final subtitle = [
      ?who,
      ?route,
      DateFormat('d MMM', locale).format(entry.date),
    ].join(' · ');
    final money = PriceFormatter.write(entry.amount, entry.currency);
    final (label, color) = _status(l, entry.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: payout ? const Color(0xFFE4F4EE) : AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              payout ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: payout ? const Color(0xFF168A68) : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payout ? '+$money' : '−$money',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: payout
                      ? const Color(0xFF168A68)
                      : AppColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static (String, Color) _status(AppLocalizations l, WalletEntryStatus s) {
    return switch (s) {
      WalletEntryStatus.pending => (
        l.walletStatusPending,
        AppColors.mutedForeground,
      ),
      WalletEntryStatus.sending => (
        l.walletStatusSending,
        const Color(0xFFA86B12),
      ),
      WalletEntryStatus.paid => (l.walletStatusPaid, const Color(0xFF168A68)),
      WalletEntryStatus.failed => (l.walletStatusFailed, AppColors.destructive),
      WalletEntryStatus.inEscrow => (l.walletStatusInEscrow, AppColors.primary),
      WalletEntryStatus.released => (
        l.walletStatusReleased,
        AppColors.mutedForeground,
      ),
      WalletEntryStatus.refunded => (
        l.walletStatusRefunded,
        AppColors.mutedForeground,
      ),
    };
  }
}
