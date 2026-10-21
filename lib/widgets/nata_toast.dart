import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

/// What a short message is about: sets its icon and colour.
enum ToastTone { info, success, error }

const _success = Color(0xFF168A68);

/// The app's short feedback message (designed in Sleek, "In-app Messages
/// (Toasts)"): a white card floating above the tab bar, with a tinted round
/// icon, up to three lines of text and an optional action.
///
/// ```dart
/// messenger.showSnackBar(nataToast(l.codeTexted(name), tone: ToastTone.success));
/// ```
SnackBar nataToast(
  String message, {
  ToastTone tone = ToastTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final (icon, color) = switch (tone) {
    ToastTone.info => (Icons.info_rounded, AppColors.primary),
    ToastTone.success => (Icons.check_rounded, _success),
    ToastTone.error => (Icons.priority_high_rounded, AppColors.accent),
  };
  return SnackBar(
    key: ValueKey('toast-${tone.name}'),
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.card,
    elevation: 6,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
    duration: Duration(seconds: tone == ToastTone.error ? 5 : 4),
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, right: 6),
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ),
        ),
      ],
    ),
    action: actionLabel == null
        ? null
        : SnackBarAction(
            label: actionLabel,
            textColor: AppColors.accent,
            onPressed: onAction ?? () {},
          ),
  );
}
