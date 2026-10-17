import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/verification_service.dart';
import '../widgets/page_header.dart';

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);
const _amber = Color(0xFFA86B12);
const _amberBg = Color(0xFFFBF0DC);

/// Where a user's ID check stands, for someone who has already sent their ID:
/// verified, or under review. Opened from Profile > Identity Verification.
class IdentityStatusScreen extends StatefulWidget {
  /// True once the ID is verified; false while it is under review.
  final bool verified;

  /// Loads the user's verification record. Replaced in tests.
  final Future<Map<String, dynamic>?> Function()? loadVerification;

  const IdentityStatusScreen({
    super.key,
    required this.verified,
    this.loadVerification,
  });

  @override
  State<IdentityStatusScreen> createState() => _IdentityStatusScreenState();
}

class _IdentityStatusScreenState extends State<IdentityStatusScreen> {
  Map<String, dynamic>? _record;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final load =
          widget.loadVerification ?? VerificationService().getMyVerification;
      final record = await load();
      if (mounted) setState(() => _record = record);
    } catch (e) {
      debugPrint('[IdentityStatus] load error: $e');
    }
  }

  String _documentLabel(AppLocalizations l) {
    return switch (_record?['id_document_type']) {
      'drivers_license' => l.idDocDriversLicense,
      'national_id' => l.idDocNationalId,
      'passport' => l.idDocPassport,
      _ => '—',
    };
  }

  String _date(String key) {
    final raw = _record?[key] as String?;
    final date = raw == null ? null : DateTime.tryParse(raw);
    if (date == null) return '—';
    return DateFormat(
      'd MMM yyyy',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final verified = widget.verified;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(title: l.identityVerification),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: verified ? _greenBg : _amberBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        verified
                            ? Icons.verified_user_rounded
                            : Icons.schedule_rounded,
                        size: 38,
                        color: verified ? _green : _amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    verified ? l.idStatusVerifiedTitle : l.idStatusReviewTitle,
                    key: const ValueKey('identity-status-title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.4,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verified ? l.idStatusVerifiedBody : l.idStatusReviewBody,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _Row(
                          label: l.idStatusDocument,
                          value: verified
                              ? _documentLabel(l)
                              : l.idStatusReceived,
                          done: true,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _Row(
                          label: l.idStatusFaceMatch,
                          value: verified
                              ? l.idStatusPassed
                              : l.idStatusInReview,
                          done: verified,
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _Row(
                          label: verified
                              ? l.idStatusVerifiedOn
                              : l.idStatusSubmittedOn,
                          value: _date(
                            verified && _record?['verified_at'] != null
                                ? 'verified_at'
                                : 'updated_at',
                          ),
                          done: true,
                          icon: Icons.calendar_today_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.idStatusPrivacy,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            height: 1.5,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  key: const ValueKey('identity-status-back'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.foreground,
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text(l.backToProfile),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  /// Green check when done; an amber dot while still in review.
  final bool done;
  final IconData? icon;

  const _Row({
    required this.label,
    required this.value,
    required this.done,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: AppColors.mutedForeground)
          else if (done)
            const Icon(Icons.check_circle_rounded, size: 18, color: _green)
          else
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: _amber,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
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
  }
}
