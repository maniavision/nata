import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../screens/identity_verification_screen.dart';

/// Shown when an unverified user tries to post a trip or send a request.
/// [message] says what they were trying to do. While their check is
/// [pending] they can only wait; otherwise they can start it from here.
Future<void> showVerifyPrompt(
  BuildContext context, {
  required String message,
  required bool pending,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.45),
    builder: (_) => VerifyPromptSheet(message: message, pending: pending),
  );
}

class VerifyPromptSheet extends StatelessWidget {
  final String message;
  final bool pending;

  const VerifyPromptSheet({
    super.key,
    required this.message,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    final buttonText = GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 16,
    );

    return Container(
      key: const ValueKey('verify-prompt'),
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
              child: Icon(
                pending
                    ? Icons.hourglass_top_rounded
                    : Icons.verified_user_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pending ? l.verifyPendingTitle : l.verifyPromptTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pending ? l.verifyPendingBody : message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            if (!pending) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('verify-prompt-start'),
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => const IdentityVerificationScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.badge_rounded, size: 20),
                  label: Text(l.verifyMyIdentity),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentForeground,
                    shape: const StadiumBorder(),
                    textStyle: buttonText,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            TextButton(
              key: const ValueKey('verify-prompt-close'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                textStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: Text(pending ? l.ok : l.notNow),
            ),
          ],
        ),
      ),
    );
  }
}
