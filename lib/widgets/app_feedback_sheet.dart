import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import 'nata_toast.dart';

/// Right after a review (designed in Sleek, "Review - Help us improve"): an
/// optional suggestion to make Nata better, for the Nata team only
/// (20240189_app_feedback.sql). Resolves once it is sent or skipped; sending
/// never blocks leaving.
Future<void> showAppFeedbackSheet(
  BuildContext context, {
  required Future<void> Function(String message) send,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.45),
    builder: (_) => AppFeedbackSheet(send: send),
  );
}

class AppFeedbackSheet extends StatefulWidget {
  final Future<void> Function(String message) send;

  const AppFeedbackSheet({super.key, required this.send});

  @override
  State<AppFeedbackSheet> createState() => _AppFeedbackSheetState();
}

class _AppFeedbackSheetState extends State<AppFeedbackSheet> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _text.text.trim();
    if (message.isEmpty || _sending) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    // In place of the review's "Thanks for reviewing", not queued behind it.
    messenger.removeCurrentSnackBar();
    try {
      await widget.send(message);
      messenger.showSnackBar(
        nataToast(l.feedbackThanks, tone: ToastTone.success),
      );
    } catch (e) {
      debugPrint('[AppFeedback] send failed: $e');
      messenger.showSnackBar(
        nataToast(l.feedbackFailed, tone: ToastTone.error),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom =
        MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    return Container(
      key: const ValueKey('app-feedback-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.accent,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.feedbackTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.feedbackBody,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('app-feedback-text'),
              controller: _text,
              minLines: 4,
              maxLines: 6,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: l.feedbackHint,
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.input,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                key: const ValueKey('app-feedback-send'),
                onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.35,
                  ),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  l.feedbackSend,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('app-feedback-skip'),
              onPressed: _sending ? null : () => Navigator.of(context).pop(),
              child: Text(
                l.notNow,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
