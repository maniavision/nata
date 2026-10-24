import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

/// An unread count: a coral badge with a thin ring, "9+" above 9. On Home's
/// bell and on the Messages tab.
class UnreadBadge extends StatelessWidget {
  final int count;

  /// The ring around it, the colour of what it sits on.
  final Color ringColor;

  const UnreadBadge({
    super.key,
    required this.count,
    this.ringColor = AppColors.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ringColor, width: 2),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: GoogleFonts.dmSans(
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: AppColors.accentForeground,
        ),
      ),
    );
  }
}
