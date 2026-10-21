import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/request_service.dart';
import '../widgets/page_header.dart';
import 'report_problem_screen.dart';
import '../widgets/nata_toast.dart';

/// How the sender left Confirm Receipt.
enum ReceiptOutcome { confirmed, reported }

/// The sender checks the traveler's "delivered": confirm it arrived (then
/// rate the traveler), or report a problem within 3 days. Pops with a
/// [ReceiptOutcome], or null when they just go back.
class ConfirmReceiptScreen extends StatefulWidget {
  final SentRequest request;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  const ConfirmReceiptScreen({super.key, required this.request, this.service});

  @override
  State<ConfirmReceiptScreen> createState() => _ConfirmReceiptScreenState();
}

class _ConfirmReceiptScreenState extends State<ConfirmReceiptScreen> {
  bool _confirming = false;

  /// The traveler's photo of the handover, when there is one.
  String? _handoverUrl;

  RequestService get _service => widget.service ?? RequestService();

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      final urls = await _service.deliveryPhotoUrls(widget.request.id);
      if (mounted) setState(() => _handoverUrl = urls.handover);
    } catch (e) {
      debugPrint('[ConfirmReceipt] photo error: $e');
    }
  }

  Future<void> _confirm() async {
    if (_confirming) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _confirming = true);
    try {
      await _service.confirmReceipt(widget.request.id);
      if (mounted) Navigator.of(context).pop(ReceiptOutcome.confirmed);
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errConfirmReceiptFailed, tone: ToastTone.error),
      );
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _report() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportProblemScreen(
          requestId: widget.request.id,
          service: widget.service,
        ),
      ),
    );
    if (sent != true || !mounted) return;
    messenger.showSnackBar(nataToast(l.rpSent, tone: ToastTone.success));
    Navigator.of(context).pop(ReceiptOutcome.reported);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = widget.request;
    final traveler = r.trip.firstName;
    final bottom = MediaQuery.of(context).padding.bottom;

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(title: l.confirmReceipt),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE4F4EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        size: 32,
                        color: Color(0xFF168A68),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.crHeadline(traveler, r.recipientName),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.3,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.crBody(traveler),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_handoverUrl != null) ...[
                    ClipRRect(
                      key: const ValueKey('receipt-handover-photo'),
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        _handoverUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        row(l.crItem, r.itemsSummary),
                        const Divider(height: 1, color: AppColors.border),
                        row(
                          l.crRoute,
                          '${r.trip.departureCity} → ${r.trip.arrivalCity}',
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        row(l.crRecipient, r.recipientName),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      key: const ValueKey('receipt-yes'),
                      onPressed: _confirming ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentForeground,
                        shape: const StadiumBorder(),
                        textStyle: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      child: _confirming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(l.crYes),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    key: const ValueKey('receipt-report'),
                    onPressed: _confirming ? null : _report,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                      textStyle: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    child: Text(l.reportProblem),
                  ),
                  Text(
                    l.crReportNote,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
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
