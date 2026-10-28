import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/message_service.dart';

/// What the member chose in the report sheet.
class ChatReportDraft {
  final ChatReportReason reason;
  final String? note;
  final bool block;

  const ChatReportDraft({
    required this.reason,
    required this.note,
    required this.block,
  });
}

/// Reporting the other person in a chat (designed in Sleek, "Report
/// (Sheet)"): a reason, an optional note and "Also block". Pops a
/// [ChatReportDraft], or nothing when closed.
class ChatReportSheet extends StatefulWidget {
  /// The other person's first name.
  final String name;

  /// "Kwame B.", for the title.
  final String fullName;

  /// The message being reported, if any.
  final ChatMessage? message;

  /// Already blocked: "Also block" isn't offered.
  final bool alreadyBlocked;

  const ChatReportSheet({
    super.key,
    required this.name,
    required this.fullName,
    this.message,
    this.alreadyBlocked = false,
  });

  static String reasonLabel(AppLocalizations l, ChatReportReason r) =>
      switch (r) {
        ChatReportReason.harassment => l.reportReasonHarassment,
        ChatReportReason.scam => l.reportReasonScam,
        ChatReportReason.spam => l.reportReasonSpam,
        ChatReportReason.inappropriate => l.reportReasonInappropriate,
        ChatReportReason.unsafe => l.reportReasonUnsafe,
        ChatReportReason.other => l.reportReasonOther,
      };

  @override
  State<ChatReportSheet> createState() => _ChatReportSheetState();
}

class _ChatReportSheetState extends State<ChatReportSheet> {
  ChatReportReason? _reason;
  bool _block = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _send() {
    final reason = _reason;
    if (reason == null) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(
      ChatReportDraft(
        reason: reason,
        note: note.isEmpty ? null : note,
        block: _block,
      ),
    );
  }

  Widget _reasonRow(ChatReportReason r) {
    final selected = _reason == r;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('report-reason-${r.code}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _reason = r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.06)
                : AppColors.input,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ChatReportSheet.reasonLabel(context.l10n, r),
                  style: GoogleFonts.dmSans(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.accent : AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final message = widget.message;
    final quoted = message?.body ?? (message != null ? '📷' : null);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        key: const ValueKey('report-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.reportTitle(widget.fullName),
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('report-close'),
                      tooltip: l.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Text(
                  l.reportIntro(widget.name),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (quoted != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('report-quoted'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.reportAboutMessage.toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 1,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quoted,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                for (final r in ChatReportReason.values) _reasonRow(r),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('report-note'),
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.foreground,
                  ),
                  decoration: InputDecoration(
                    hintText: l.reportNoteHint,
                    counterText: '',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.mutedForeground,
                    ),
                    filled: true,
                    fillColor: AppColors.input,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                if (!widget.alreadyBlocked) ...[
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    key: const ValueKey('report-block'),
                    value: _block,
                    onChanged: (v) => setState(() => _block = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.accent,
                    dense: true,
                    title: Text(
                      l.reportAlsoBlock(widget.name),
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    key: const ValueKey('report-send'),
                    onPressed: _reason == null ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.accent.withValues(
                        alpha: 0.4,
                      ),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      l.reportSend,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
