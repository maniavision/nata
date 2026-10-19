import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../services/country_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/face_verification_service.dart';
import '../services/id_document_check_service.dart';
import '../services/preferences_service.dart';
import '../services/request_service.dart' show RequestInput;
import '../widgets/country_code_picker_sheet.dart';
import '../widgets/page_header.dart';
import '../widgets/face_scan_step.dart';
import '../services/verification_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../widgets/camera_denied_sheet.dart';

class IdentityVerificationScreen extends StatefulWidget {
  /// Which step to open on: 0 = ID upload, 1 = face scan (not part of the flow
  /// at the moment), 2 = emergency contact, 3 = success.
  /// Only tests use anything other than the default.
  @visibleForTesting
  final int initialStep;

  /// Override for tests; defaults to the real [EmergencyContactService].
  final EmergencyContactService? emergencyService;

  /// Override for tests; defaults to the real [IdDocumentCheckService].
  final IdDocumentCheckService? idCheck;

  /// Override for tests; defaults to the real [FaceVerificationService].
  final FaceVerificationService? faceService;

  const IdentityVerificationScreen({
    super.key,
    this.initialStep = 0,
    this.emergencyService,
    this.idCheck,
    this.faceService,
  });

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  late int _step = widget.initialStep; // 0=ID, 1=face scan, 2=contact, 3=done
  int _idType = 0; // index into IdDocumentType.values (the buttons' order)

  // Document picked by the user in Step 1
  Uint8List? _documentBytes;
  String? _documentFileName;
  String? _documentMimeType;

  bool _submitting = false;
  String? _submitError;

  void _onDocumentPicked(Uint8List bytes, String fileName, String mimeType) {
    setState(() {
      _documentBytes = bytes;
      _documentFileName = fileName;
      _documentMimeType = mimeType;
      _submitError = null;
    });
  }

  Future<void> _submitAndNext() async {
    if (_documentBytes == null) {
      setState(() => _submitError = context.l10n.errCaptureIdFirst);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      // 1. On-device checks: the document's text must be readable and hold
      //    ID labels and the profile name, and it must show a face. If face
      //    detection can't run, it goes through as pending for manual review.
      final idType = IdDocumentType.values[_idType];
      final check = await (widget.idCheck ?? IdDocumentCheckService()).check(
        bytes: _documentBytes!,
        fileName: _documentFileName!,
        idType: idType,
      );
      if (!mounted) return;
      final l = context.l10n;
      final checkError = switch (check) {
        IdCheckResult.notAnId => l.errIdNotRecognized,
        IdCheckResult.wrongType => l.errIdWrongType(switch (idType) {
          IdDocumentType.passport => l.idTypePassport,
          IdDocumentType.driversLicense => l.idTypeDriversLicense,
          IdDocumentType.nationalId => l.idTypeNationalId,
        }),
        IdCheckResult.nameMismatch => l.errIdNameMismatch,
        IdCheckResult.noFace => l.errIdNoFace,
        IdCheckResult.unreadable => l.errIdUnreadable,
        IdCheckResult.passed || IdCheckResult.unverifiable => null,
      };
      if (checkError != null) {
        setState(() {
          _submitting = false;
          _submitError = checkError;
        });
        return;
      }

      // 2. Upload document to Supabase Storage
      final path = await VerificationService()
          .uploadDocument(
            bytes: _documentBytes!,
            fileName: VerificationService.idDocumentFileName(
              _documentFileName!,
            ),
            mimeType: _documentMimeType!,
          )
          .timeout(const Duration(seconds: 60));

      // 3. Create identity_verifications record
      await VerificationService()
          .submitVerification(idType: idType, documentPath: path)
          .timeout(const Duration(seconds: 30));

      // 4. The ID image the selfie will be compared with. Without one (no
      //    face found on it) there is nothing to match: the ID goes to manual
      //    review and the face scan is skipped.
      var faceMatchReady = false;
      try {
        final idFace = await IdDocumentCheckService.faceImage(
          _documentBytes!,
          _documentFileName!,
        );
        if (idFace != null) {
          await (widget.faceService ?? FaceVerificationService()).uploadIdFace(
            idFace,
          );
          faceMatchReady = true;
        }
      } catch (e) {
        debugPrint('[VerificationScreen] ID face upload error: $e');
      }

      // On to the face scan, or the emergency contact. Clear the spinner
      // too, or coming back to this step shows it forever.
      if (mounted) {
        setState(() {
          _submitting = false;
          _step = faceMatchReady ? 1 : 2;
        });
      }
    } catch (e) {
      debugPrint('[VerificationScreen] submit error: $e');
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = context.l10n.errUploadFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _step == 0
              ? _Step1(
                  key: const ValueKey(0),
                  idType: _idType,
                  onIdTypeChanged: (t) => setState(() => _idType = t),
                  onNext: _submitAndNext,
                  onBack: () => Navigator.of(context).pop(),
                  documentBytes: _documentBytes,
                  documentFileName: _documentFileName,
                  onDocumentPicked: _onDocumentPicked,
                  submitting: _submitting,
                  submitError: _submitError,
                )
              : _step == 1
              ? FaceScanStep(
                  key: const ValueKey(1),
                  service: widget.faceService ?? FaceVerificationService(),
                  onDone: () => setState(() => _step = 2),
                  onBack: () => setState(() => _step = 0),
                )
              : _step == 2
              ? _StepEmergency(
                  key: const ValueKey(2),
                  service: widget.emergencyService ?? EmergencyContactService(),
                  onBack: () => setState(() => _step = 0),
                  onDone: () => setState(() => _step = 3),
                )
              : _Step3(
                  key: const ValueKey(3),
                  onContinue: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  onViewProfile: () {
                    // Same stack as opening Profile from the bottom nav: Home
                    // at the root, Profile on top. Profile loads fresh, so it
                    // shows the new verification status.
                    Navigator.of(context)
                      ..pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      )
                      ..push(
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                  },
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 1 — Upload ID
// ══════════════════════════════════════════════════════════════════════════════
class _Step1 extends StatelessWidget {
  final int idType;
  final ValueChanged<int> onIdTypeChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Uint8List? documentBytes;
  final String? documentFileName;
  final void Function(Uint8List bytes, String fileName, String mimeType)
  onDocumentPicked;
  final bool submitting;
  final String? submitError;

  const _Step1({
    super.key,
    required this.idType,
    required this.onIdTypeChanged,
    required this.onNext,
    required this.onBack,
    required this.documentBytes,
    required this.documentFileName,
    required this.onDocumentPicked,
    required this.submitting,
    this.submitError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWarningBanner(context),
                const SizedBox(height: 16),
                Text(
                  context.l10n.verifyIdentity,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.verifyIdentitySub,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                _buildIdUploadCard(context),
                const SizedBox(height: 8),
                // Travelers are told who sees what before they upload.
                Row(
                  key: const ValueKey('id-shared-note'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.idSharedWithSendersNote,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          height: 1.4,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFaceScanPreview(context),
                const SizedBox(height: 16),
                _buildSecurityRow(context),
              ],
            ),
          ),
        ),
        _buildFooter(
          buttonLabel: submitting
              ? context.l10n.uploadingEllipsis
              : documentBytes != null
              ? context.l10n.submitForVerification
              : context.l10n.scanIdToContinue,
          buttonColor: documentBytes != null
              ? AppColors.accent
              : AppColors.primary,
          footnote: context.l10n.biometricNote,
          onTap: submitting ? () {} : onNext,
          loading: submitting,
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.foreground,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Shrinks rather than overflow with long translations.
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        Text(
                          context.l10n.required,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    context.l10n.skipForNowId,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProgressBar(step: 0, context: context),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1ED),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gpp_maybe_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.actionRequired,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.actionRequiredBody,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    height: 1.625,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdUploadCard(BuildContext context) {
    final types = [
      (Icons.menu_book_rounded, context.l10n.passportOption),
      (Icons.credit_card_rounded, context.l10n.driversLicense),
      (Icons.badge_rounded, context.l10n.nationalId),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.primaryForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.uploadOfficialId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      context.l10n.passportOrId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.activeStep.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ID type selector
          Row(
            children: types.asMap().entries.map((e) {
              final selected = idType == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onIdTypeChanged(e.key),
                  child: Container(
                    margin: EdgeInsets.only(right: e.key < 2 ? 6 : 0),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.input,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          e.value.$1,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : AppColors.mutedForeground,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value.$2,
                          style: GoogleFonts.dmSans(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 11,
                            color: selected
                                ? Colors.white
                                : AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Upload zone — shows preview if document picked, else picker buttons
          documentBytes != null
              ? _buildDocumentPreview(context)
              : _buildPickerZone(context),
          // Error message
          if (submitError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      submitError!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Preview the picked document
  Widget _buildDocumentPreview(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            documentBytes!,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              height: 180,
              color: AppColors.secondary,
              child: const Center(
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Color(0xFF168A68),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                documentFileName ?? context.l10n.documentSelected,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showPickerOptions(context),
              child: Text(
                context.l10n.change,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Picker zone when no document selected
  Widget _buildPickerZone(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DashedRRectBorder(
        color: AppColors.border,
        radius: 28,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_rounded,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.takePhotoOrUpload,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              context.l10n.allCornersVisible,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _uploadButton(
                  context,
                  Icons.camera_alt_rounded,
                  context.l10n.useCamera,
                  onTap: () => _pickFromCamera(context),
                ),
                _uploadButton(
                  context,
                  Icons.photo_library_rounded,
                  context.l10n.chooseFile,
                  onTap: () => _pickFromGallery(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadButton(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.foreground),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  context.l10n.useCamera,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  context.l10n.chooseFile,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final ext = photo.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      onDocumentPicked(bytes, 'id_document_$ext.$ext', mime);
    } catch (e) {
      debugPrint('[Step1] camera error: $e');
      if (context.mounted && isCameraDenied(e)) {
        await showCameraDeniedSheet(context);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errCameraDetail(e.toString()))),
        );
      }
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
          ? 'image/png'
          : 'image/jpeg';
      onDocumentPicked(file.bytes!, file.name, mime);
    } catch (e) {
      debugPrint('[Step1] file picker error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errFilePicker(e.toString()))),
        );
      }
    }
  }

  Widget _buildFaceScanPreview(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.faceScan,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      context.l10n.faceScanSub,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.nextStep.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.faceScanLivenessNote,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      height: 1.375,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityRow(BuildContext context) {
    // A Wrap, so the two notes sit side by side when there is room and stack
    // when there is not (longer translations, small phones, large text).
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF168A68)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                context.l10n.encrypted256,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.mutedForeground.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.offline_bolt_rounded,
              size: 14,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                context.l10n.instantAi,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 3 — Verified success
// ══════════════════════════════════════════════════════════════════════════════
class _Step3 extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onViewProfile;
  const _Step3({
    super.key,
    required this.onContinue,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4EE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF168A68).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF168A68),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.tier1Verified.split('·').first.trim() + ',',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: const Color(0xFF168A68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                // Avatar with green ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF168A68),
                          width: 4,
                        ),
                        color: AppColors.background,
                      ),
                      child: ClipOval(
                        child: Container(
                          color: AppColors.secondary,
                          child: const Icon(
                            Icons.person,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF168A68),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.fullyVerified,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.fullyVerifiedSub,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Verification report card
                _reportCard(context),
                const SizedBox(height: 16),
                // Perks card
                _perksCard(context),
              ],
            ),
          ),
        ),
        // Footer
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.accent.withValues(alpha: 0.4),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.continueToHome,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  key: const ValueKey('view-public-profile'),
                  onPressed: onViewProfile,
                  icon: const Icon(
                    Icons.account_circle_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    context.l10n.viewPublicProfile,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    backgroundColor: AppColors.card,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.verificationReport,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.instantApproval,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: const Color(0xFF168A68),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _reportRow(
            context,
            Icons.credit_card_rounded,
            context.l10n.passportIdDoc,
            context.l10n.verifiedLabel,
            const Color(0xFF168A68),
          ),
          const SizedBox(height: 10),
          _reportRow(
            context,
            Icons.face_retouching_natural,
            context.l10n.biometricLiveness,
            context.l10n.matchPercent('99.8%'),
            const Color(0xFF168A68),
          ),
          const SizedBox(height: 10),
          _reportRow(
            context,
            Icons.shield_rounded,
            context.l10n.trustLimit,
            context.l10n.amountPerDelivery(r'$2,500'),
            AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _reportRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F4EE),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF168A68)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
        Row(
          children: [
            if (valueColor == const Color(0xFF168A68))
              const Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: Color(0xFF168A68),
              ),
            if (valueColor == const Color(0xFF168A68)) const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _perksCard(BuildContext context) {
    final perks = [
      context.l10n.perk1,
      context.l10n.perk2,
      context.l10n.perk3,
      context.l10n.perk4,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.card_giftcard_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.l10n.unlockedPerks,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Two columns whose rows grow with their text (a fixed-height grid
          // cannot fit longer translations).
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: perks
                    .map(
                      (p) => SizedBox(
                        width: itemWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Color(0xFF168A68),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────
Widget _buildProgressBar({required int step, required BuildContext context}) {
  final l = context.l10n;
  return Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Scales down rather than overflow with long translations.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                l.identityVerificationTitle.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.44,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            step == 0 ? l.step1of2 : l.step2of2,
            style: GoogleFonts.dmSans(
              fontWeight: step == 1 ? FontWeight.w800 : FontWeight.w700,
              fontSize: 12,
              color: step == 1 ? AppColors.accent : AppColors.mutedForeground,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: step == 0 ? AppColors.accent : const Color(0xFF168A68),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: step == 1 ? AppColors.accent : AppColors.muted,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildFooter({
  required String buttonLabel,
  required Color buttonColor,
  required String footnote,
  required VoidCallback onTap,
  bool loading = false,
}) {
  return Builder(
    builder: (context) {
      return Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  disabledBackgroundColor: AppColors.muted,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: buttonColor.withValues(alpha: 0.4),
                  shape: const StadiumBorder(),
                ),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              buttonLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              footnote,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Emergency contact (last step)
// ══════════════════════════════════════════════════════════════════════════════
class _StepEmergency extends StatefulWidget {
  final EmergencyContactService service;
  final VoidCallback onBack;

  /// Called once the contact is saved, or when the user chooses to skip.
  final VoidCallback onDone;

  /// Opened from Profile rather than during verification: a plain page
  /// header, no Skip or progress, "Save contact", and [initial] filled in.
  final bool standalone;
  final EmergencyContact? initial;

  const _StepEmergency({
    super.key,
    required this.service,
    required this.onBack,
    required this.onDone,
    this.standalone = false,
    this.initial,
  });

  @override
  State<_StepEmergency> createState() => _StepEmergencyState();
}

class _StepEmergencyState extends State<_StepEmergency> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  // Starts on the user's own country (as on the login screen); any other
  // country can be picked.
  Country _country = const Country(
    isoCode: 'US',
    name: 'United States',
    phoneCode: '+1',
  );
  bool _countryChosenByUser = false;
  EmergencyRelationship _relationship = EmergencyRelationship.friend;
  bool _saving = false;
  String? _error;

  static const _icons = {
    EmergencyRelationship.friend: Icons.group_rounded,
    EmergencyRelationship.relative: Icons.diversity_3_rounded,
    EmergencyRelationship.partner: Icons.favorite_rounded,
    EmergencyRelationship.colleague: Icons.work_rounded,
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      _applyUserCountry();
    } else {
      _nameCtrl.text = initial.fullName;
      _relationship = initial.relationship;
      _phoneCtrl.text = initial.phone;
      _applyCountryOf(initial.phone);
    }
  }

  /// Splits a saved "+233241234567" into its country and local number.
  Future<void> _applyCountryOf(String phone) async {
    final all = await CountryService().all();
    Country? best;
    for (final c in all) {
      if (phone.startsWith(c.phoneCode) &&
          (best == null || c.phoneCode.length > best.phoneCode.length)) {
        best = c;
      }
    }
    if (best == null || !mounted || _countryChosenByUser) return;
    final country = best;
    setState(() {
      _country = country;
      _phoneCtrl.text = phone.substring(country.phoneCode.length);
    });
  }

  Future<void> _applyUserCountry() async {
    final iso = PreferencesService().countryIsoCode;
    if (iso == _country.isoCode) return;
    final country = await CountryService().byIsoCode(iso);
    if (country == null || !mounted || _countryChosenByUser) return;
    setState(() => _country = country);
  }

  Future<void> _pickCountry() async {
    final country = await showCountryCodePicker(context, _country);
    if (country == null || !mounted) return;
    setState(() {
      _country = country;
      _countryChosenByUser = true;
      _error = null;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _relationshipName(EmergencyRelationship r) {
    final l = context.l10n;
    switch (r) {
      case EmergencyRelationship.friend:
        return l.relFriend;
      case EmergencyRelationship.relative:
        return l.relRelative;
      case EmergencyRelationship.partner:
        return l.relPartner;
      case EmergencyRelationship.colleague:
        return l.relColleague;
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    final l = context.l10n;
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = l.errContactName);
      return;
    }
    final phone = RequestInput.internationalPhone(
      _country.phoneCode,
      _phoneCtrl.text,
    );
    if (phone == null) {
      setState(() => _error = l.errContactPhone);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.save(
        EmergencyContact(
          fullName: name,
          phone: phone,
          relationship: _relationship,
        ),
      );
      if (mounted) widget.onDone();
    } catch (e) {
      debugPrint('[EmergencyContact] save error: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.errContactSave;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        if (widget.standalone)
          PageHeader(title: l.emergencyContactLabel)
        else
          _header(l),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              widget.standalone ? 20 : 8,
              20,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.standalone)
                  Text(
                    l.ecTitle,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.5,
                      color: AppColors.foreground,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  widget.standalone ? l.ecScreenBody : l.ecBody,
                  style: GoogleFonts.dmSans(
                    fontSize: widget.standalone ? 13 : 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                _formCard(l),
                const SizedBox(height: 16),
                _privacyNote(l),
              ],
            ),
          ),
        ),
        _footer(l),
      ],
    );
  }

  Widget _header(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                key: const ValueKey('contact-back'),
                onTap: widget.onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.foreground,
                    size: 20,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    l.required,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                key: const ValueKey('contact-skip'),
                behavior: HitTestBehavior.opaque,
                onTap: _saving ? null : widget.onDone,
                child: Text(
                  l.skipForNowId,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l.emergencyContactLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.ecStepOf,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _formCard(AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(l.ecFullName),
          const SizedBox(height: 6),
          _field(
            fieldKey: 'contact-name',
            icon: Icons.person_rounded,
            controller: _nameCtrl,
            hint: l.ecFullNameHint,
            capitalization: TextCapitalization.words,
            maxLength: 80,
          ),
          const SizedBox(height: 14),
          _label(l.ecPhone),
          const SizedBox(height: 6),
          Row(
            children: [
              GestureDetector(
                key: const ValueKey('contact-country'),
                onTap: _pickCountry,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        flagEmoji(_country.isoCode),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _country.phoneCode,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  fieldKey: 'contact-phone',
                  icon: Icons.phone_rounded,
                  controller: _phoneCtrl,
                  hint: l.ecPhoneHint,
                  keyboardType: TextInputType.phone,
                  maxLength: 24,
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-().\s]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label(l.ecRelationship),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.6,
            children: [
              for (final r in EmergencyRelationship.values) _relTile(r),
            ],
          ),
        ],
      ),
    );
  }

  Widget _relTile(EmergencyRelationship r) {
    final active = _relationship == r;
    return GestureDetector(
      key: ValueKey('contact-rel-${r.name}'),
      onTap: () => setState(() {
        _relationship = r;
        _error = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _icons[r],
              size: 16,
              color: active ? Colors.white : AppColors.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _relationshipName(r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                  color: active ? Colors.white : AppColors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyNote(AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.verified_user_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.ecPrivacy,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.6,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(AppLocalizations l) {
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Container(
              key: const ValueKey('contact-error'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const ValueKey('contact-finish'),
              onPressed: _saving ? null : _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.6,
                ),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: const StadiumBorder(),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.standalone ? l.ecSaveContact : l.ecFinish,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (!widget.standalone) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.ecFootnote,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 1.3,
      color: AppColors.mutedForeground,
    ),
  );

  Widget _field({
    required String fieldKey,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: ValueKey(fieldKey),
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: capitalization,
              maxLength: maxLength,
              inputFormatters: formatters,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed rounded-rectangle outline (border-2 border-dashed).
class _DashedRRectBorder extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRRectBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rect = (Offset.zero & size).deflate(1);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectBorder old) =>
      old.color != color || old.radius != radius;
}

/// The emergency contact form on its own page, opened from Profile. Pops
/// with true once the contact is saved.
class EmergencyContactScreen extends StatelessWidget {
  /// The saved contact, filled in for editing.
  final EmergencyContact? initial;

  /// Override for tests; defaults to the real [EmergencyContactService].
  final EmergencyContactService? service;

  const EmergencyContactScreen({super.key, this.initial, this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _StepEmergency(
          service: service ?? EmergencyContactService(),
          standalone: true,
          initial: initial,
          onBack: () => Navigator.of(context).pop(),
          onDone: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}
