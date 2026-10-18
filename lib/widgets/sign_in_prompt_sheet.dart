import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import '../screens/sign_up_screen.dart';

/// Shown when a visitor taps something that needs an account. [message] says
/// what they were trying to do; it defaults to a general line.
Future<void> showSignInPrompt(
  BuildContext context, {
  String? message,
  WidgetBuilder? next,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.45),
    builder: (_) => SignInPromptSheet(message: message, next: next),
  );
}

class SignInPromptSheet extends StatelessWidget {
  final String? message;

  /// The page the visitor was opening; Sign In leads there once done.
  final WidgetBuilder? next;

  const SignInPromptSheet({super.key, this.message, this.next});

  /// Closes the sheet, then opens [screen] from the page underneath.
  void _open(BuildContext context, Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      key: const ValueKey('sign-in-prompt'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle, with the close button on the same line.
            SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: 0,
                    child: IconButton(
                      key: const ValueKey('sign-in-prompt-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.mutedForeground,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.accent,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.signInPromptTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? l.signInPromptBody,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            _Benefit(
              icon: Icons.verified_rounded,
              label: l.signInBenefitVerified,
            ),
            _Benefit(icon: Icons.lock_rounded, label: l.signInBenefitEscrow),
            _Benefit(
              icon: Icons.phone_iphone_rounded,
              label: l.signInBenefitPhone,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('sign-in-prompt-create'),
                onPressed: () => _open(context, const SignUpScreen()),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: Text(l.createFreeAccount),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                key: const ValueKey('sign-in-prompt-sign-in'),
                onPressed: () => _open(context, LoginScreen(afterSignIn: next)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  side: const BorderSide(color: AppColors.border, width: 1.5),
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                child: Text(l.signIn),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('sign-in-prompt-not-now'),
              onPressed: () => Navigator.of(context).pop(),
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

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Benefit({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryForeground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
