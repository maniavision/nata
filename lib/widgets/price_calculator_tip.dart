import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../screens/cost_estimate_screen.dart';

/// Once the sender and the traveler have both written in a chat, suggests
/// the cost calculator to help them agree on a price. Shown once per
/// conversation for each member on this device.
class PriceCalculatorTip {
  /// Off in tests, so the pop-up doesn't cover the chats under test.
  static bool enabled = true;

  /// Opens the calculator. Replaceable in tests.
  static WidgetBuilder calculator = (_) => const CostEstimateScreen();

  static String seenKey(String conversationId, String userId) =>
      'price_calculator_tip_seen_${conversationId}_$userId';

  /// Shows the suggestion unless it was shown for this conversation before.
  static Future<void> showOnce(
    BuildContext context, {
    required String conversationId,
    required String userId,
    required bool iAmTraveler,
  }) async {
    if (!enabled) return;
    final key = seenKey(conversationId, userId);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) ?? false) return;
      await prefs.setBool(key, true);
    } catch (_) {
      return;
    }
    if (!context.mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final open = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.foreground.withValues(alpha: 0.45),
      builder: (_) => PriceCalculatorTipSheet(iAmTraveler: iAmTraveler),
    );
    if (open == true && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: calculator));
    }
  }
}

class PriceCalculatorTipSheet extends StatelessWidget {
  final bool iAmTraveler;

  const PriceCalculatorTipSheet({super.key, required this.iAmTraveler});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      key: const ValueKey('price-tip'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calculate_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.priceTipTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              iAmTraveler ? l.priceTipTraveler : l.priceTipSender,
              key: const ValueKey('price-tip-body'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('price-tip-open'),
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.calculate_rounded, size: 20),
                label: Text(l.priceTipOpen),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentForeground,
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('price-tip-close'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                textStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: Text(l.notNow),
            ),
          ],
        ),
      ),
    );
  }
}
