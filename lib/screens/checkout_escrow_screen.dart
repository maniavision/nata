import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';

class CheckoutEscrowScreen extends StatefulWidget {
  const CheckoutEscrowScreen({super.key});

  @override
  State<CheckoutEscrowScreen> createState() => _CheckoutEscrowScreenState();
}

class _CheckoutEscrowScreenState extends State<CheckoutEscrowScreen> {
  int _paymentMethod = 0; // 0=Apple Pay, 1=Card, 2=Mobile Money

  // Countdown timer — 23h 48m 12s
  int _seconds = 23 * 3600 + 48 * 60 + 12;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdownLabel {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
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
                  _buildCountdownBanner(),
                  const SizedBox(height: 16),
                  _buildEscrowExplainerCard(),
                  const SizedBox(height: 16),
                  _buildOrderSummaryCard(),
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
                      const TextSpan(text: 'Request expires in '),
                      TextSpan(
                        text: '23h 48m',
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
                          const TextSpan(
                            text:
                                'Your payment is held safely by Nata. The traveler is only paid ',
                          ),
                          TextSpan(
                            text: 'after your recipient verifies delivery',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                          const TextSpan(
                            text:
                                ' with your secret 4-digit code or photo proof.',
                          ),
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
                  child: Image.network(
                    'https://randomuser.me/api/portraits/women/44.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
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
                    Row(
                      children: [
                        Text(
                          'Amara K.',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4F4EE),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Verified',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              color: const Color(0xFF168A68),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Lagos (LOS) → London (LHR) · Jun 22',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Accepted',
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
            'Item',
            'MacBook Air M2 (Sealed Box)',
          ),
          const SizedBox(height: 8),
          _summaryRow(Icons.monitor_weight_outlined, 'Weight', '1.24 kg'),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
          ],
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.foreground,
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
            context.l10n.selectPaymentMethod,
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
          _breakdownRow(context.l10n.travelerReward, '\$45.00'),
          const SizedBox(height: 8),
          _breakdownRow(context.l10n.platformFee, '\$5.00'),
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
                '\$50.00',
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
            'Full 100% refund',
            'if traveler cancels or item is not delivered.',
          ),
          const SizedBox(height: 4),
          _bulletPoint(
            'Free cancellation',
            'anytime before physical handoff to traveler.',
          ),
          const SizedBox(height: 4),
          _bulletPoint(
            '3-day dispute window',
            'after delivery before funds are finalized.',
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
        label: Text(
          context.l10n.payIntoEscrow,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.accent.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
        ),
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
