import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';

/// The warning travelers see before accepting and at pickup: keeping
/// someone's item is theft, and Nata gives their verified identity to the
/// local police and the sender.
class TheftWarning extends StatelessWidget {
  /// The pickup step's one-line form ("You're now responsible...").
  final bool compact;

  const TheftWarning({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = AppColors.destructive;
    return Container(
      key: ValueKey(compact ? 'theft-warning-compact' : 'theft-warning'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_maybe_rounded, size: compact ? 16 : 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: compact
                ? Text(
                    l.theftPickupNote,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.4,
                      color: color,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.theftWarningTitle,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.theftWarningBody,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Asks the traveler to confirm they will deliver, after the warning, before
/// a request is accepted. True once confirmed.
Future<bool> confirmTheftWarning(BuildContext context) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TheftConfirmSheet(),
  );
  return confirmed == true;
}

class _TheftConfirmSheet extends StatefulWidget {
  const _TheftConfirmSheet();

  @override
  State<_TheftConfirmSheet> createState() => _TheftConfirmSheetState();
}

class _TheftConfirmSheetState extends State<_TheftConfirmSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      key: const ValueKey('theft-confirm-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.theftConfirmTitle,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          const TheftWarning(),
          const SizedBox(height: 8),
          InkWell(
            key: const ValueKey('theft-confirm-check'),
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                Expanded(
                  child: Text(
                    l.theftConfirmCheck,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    key: const ValueKey('theft-confirm-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedForeground,
                      side: const BorderSide(color: AppColors.border),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l.cancel),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    key: const ValueKey('theft-confirm-accept'),
                    onPressed: _agreed
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      l.acceptRequest,
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
