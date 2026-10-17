import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/request_service.dart';
import '../widgets/page_header.dart';

/// Tells support what went wrong with a delivery. Pops with true once the
/// report is sent.
class ReportProblemScreen extends StatefulWidget {
  final String requestId;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  const ReportProblemScreen({super.key, required this.requestId, this.service});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  ProblemReason? _reason;
  final _details = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _label(AppLocalizations l, ProblemReason r) => switch (r) {
    ProblemReason.notReceived => l.rpNotReceived,
    ProblemReason.damaged => l.rpDamaged,
    ProblemReason.wrongItem => l.rpWrongItem,
    ProblemReason.opened => l.rpOpened,
    ProblemReason.other => l.rpOther,
  };

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    final l = context.l10n;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await (widget.service ?? RequestService()).reportProblem(
        widget.requestId,
        reason: reason,
        details: _details.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = switch (e.reason) {
          RequestFailure.alreadyReported => l.errAlreadyReported,
          RequestFailure.reportWindowClosed => l.errReportWindowClosed,
          _ => l.errRequestFailed,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = l.errRequestFailed;
        });
      }
    }
  }

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
            PageHeader(title: l.reportProblem),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text(
                    l.rpBody,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.rpReason,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final r in ProblemReason.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReasonTile(
                        key: ValueKey('report-reason-${r.name}'),
                        label: _label(l, r),
                        selected: _reason == r,
                        onTap: () => setState(() {
                          _reason = r;
                          _error = null;
                        }),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    l.rpDetails,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('report-details'),
                    controller: _details,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: l.rpDetailsHint,
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColors.mutedForeground,
                      ),
                      filled: true,
                      fillColor: AppColors.input,
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
                        borderSide: const BorderSide(color: AppColors.ring),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      key: const ValueKey('report-error'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.destructive,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('report-send'),
                      onPressed: _reason == null || _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryForeground,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.4,
                        ),
                        shape: const StadiumBorder(),
                        textStyle: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.rpSend),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.06)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? AppColors.accent : AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
