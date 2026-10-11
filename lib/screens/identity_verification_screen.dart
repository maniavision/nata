import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';
import '../services/verification_service.dart';
import 'home_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  /// Which step to open on: 0 = ID upload, 1 = face scan, 2 = success.
  /// Only tests use anything other than the default.
  @visibleForTesting
  final int initialStep;

  const IdentityVerificationScreen({super.key, this.initialStep = 0});

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen>
    with SingleTickerProviderStateMixin {
  late int _step = widget.initialStep; // 0=ID upload, 1=face scan, 2=success
  int _idType = 0; // 0=passport, 1=driver's lic, 2=national id

  // Document picked by the user in Step 1
  Uint8List? _documentBytes;
  String? _documentFileName;
  String? _documentMimeType;

  bool _submitting = false;
  String? _submitError;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

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
      setState(() => _submitError = 'Please capture or upload your ID document first.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      // 1. Upload document to Supabase Storage
      final path = await VerificationService().uploadDocument(
        bytes: _documentBytes!,
        fileName: _documentFileName!,
        mimeType: _documentMimeType!,
      );

      // 2. Create identity_verifications record
      await VerificationService().submitVerification(
        idTypeIndex: _idType,
        documentPath: path,
      );

      if (mounted) setState(() => _step = 2); // Skip face scan, go to success
    } catch (e) {
      debugPrint('[VerificationScreen] submit error: $e');
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitError = 'Upload failed. Please try again.';
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
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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
                  ? _Step2(
                      key: const ValueKey(1),
                      pulseAnim: _pulseAnim,
                      onNext: () => setState(() => _step = 2),
                      onBack: () => setState(() => _step = 0),
                    )
                  : _Step3(
                      key: const ValueKey(2),
                      onContinue: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const HomeScreen()),
                          (route) => false,
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
  final void Function(Uint8List bytes, String fileName, String mimeType) onDocumentPicked;
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
                      fontSize: 12, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                _buildIdUploadCard(context),
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
              ? 'Uploading...'
              : documentBytes != null
                  ? 'Submit for Verification'
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
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.foreground, size: 20),
                ),
              ),
              Row(
                children: [
                  Text(
                    context.l10n.required,
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
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.skipForNowId,
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
          _buildProgressBar(step: 0, context: context),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.2)),
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
            child: const Icon(Icons.shield_outlined,
                size: 18, color: AppColors.accent),
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
                const SizedBox(height: 3),
                Text(
                  context.l10n.actionRequiredBody,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    height: 1.5,
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
      (Icons.book_outlined, 'Passport'),
      (Icons.credit_card_rounded, "Driver's Lic."),
      (Icons.badge_outlined, 'National ID'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2), width: 2),
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
                  child: Text('1',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primaryForeground,
                      )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.uploadOfficialId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.foreground,
                        )),
                    Text(context.l10n.passportOrId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(context.l10n.activeStep,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.0,
                      color: AppColors.accent,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ID type selector
          Row(
            children: types.asMap().entries.map((e) {
              final selected = idType == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onIdTypeChanged(e.key),
                  child: Container(
                    margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.input,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(e.value.$1,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppColors.mutedForeground),
                        const SizedBox(height: 4),
                        Text(e.value.$2,
                            style: GoogleFonts.dmSans(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 10,
                              color: selected
                                  ? Colors.white
                                  : AppColors.foreground,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
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
                    color: AppColors.destructive.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(submitError!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.destructive,
                        )),
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
                child: Icon(Icons.insert_drive_file_rounded,
                    size: 48, color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 16, color: Color(0xFF168A68)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                documentFileName ?? 'Document selected',
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
                'Change',
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo_rounded,
                size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.foreground,
                )),
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
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: Text(context.l10n.useCamera,
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: Text(context.l10n.chooseFile,
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${e.toString()}')),
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
          SnackBar(content: Text('File picker error: ${e.toString()}')),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('2',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.faceScan,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.foreground,
                    )),
                Text(context.l10n.faceScanSub,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    )),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(context.l10n.nextStep,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 1.0,
                  color: AppColors.mutedForeground,
                )),
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
            const Icon(Icons.lock_rounded,
                size: 14, color: Color(0xFF168A68)),
            const SizedBox(width: 4),
            Text(context.l10n.encrypted256,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded,
                size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Text(context.l10n.instantAi,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 2 — Face Scan
// ══════════════════════════════════════════════════════════════════════════════
class _Step2 extends StatelessWidget {
  final Animation<double> pulseAnim;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2({
    super.key,
    required this.pulseAnim,
    required this.onNext,
    required this.onBack,
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
              children: [
                _buildStep1DoneBanner(context),
                const SizedBox(height: 16),
                Text(
                  context.l10n.faceScanTitle,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.faceScanBody,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 16),
                _buildFaceCard(context),
                const SizedBox(height: 16),
                _buildSecurityRow(context),
              ],
            ),
          ),
        ),
        _buildFooter(
          buttonLabel: context.l10n.startBiometricScan,
          buttonColor: AppColors.accent,
          footnote:
              context.l10n.biometricLocalNote,
          onTap: onNext,
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
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.foreground, size: 20),
                ),
              ),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.l10n.almostDone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 1.4,
                            color: const Color(0xFF168A68),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: pulseAnim,
                        builder: (context, child) => Opacity(
                          opacity: pulseAnim.value,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF168A68),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.cancel,
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
          _buildProgressBar(step: 1, context: context),
        ],
      ),
    );
  }

  Widget _buildStep1DoneBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE4F4EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF168A68).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF168A68),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.step1Completed,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.foreground,
                    )),
                Text(context.l10n.passportVerified,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: const Color(0xFF168A68),
                    )),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(context.l10n.editId,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                  decoration: TextDecoration.underline,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Face frame
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (context, child) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent
                          .withValues(alpha: pulseAnim.value),
                      width: 4,
                      style: BorderStyle.solid,
                    ),
                    color: AppColors.secondary.withValues(alpha: 0.4),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing inner ring
                      Container(
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent
                                .withValues(alpha: 0.3 * pulseAnim.value),
                          ),
                        ),
                      ),
                      // Photo
                      ClipOval(
                        child: Container(
                          width: 144,
                          height: 144,
                          color: AppColors.primary
                              .withValues(alpha: 0.1),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                'https://lh3.googleusercontent.com/a/ACg8ocJ97aGjnJ1qNWsqUS-lOIkKvwls8WK-SI54YY8POZz7eBd4JRE=s96-c',
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stack) =>
                                        Container(
                                  color: AppColors.secondary,
                                  child: const Icon(Icons.person,
                                      size: 60,
                                      color: AppColors.primary),
                                ),
                              ),
                              Container(
                                color: AppColors.accent
                                    .withValues(alpha: 0.08),
                              ),
                              Center(
                                child: Container(
                                  width: 112,
                                  height: 112,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Scan icon badge
                Positioned(
                  top: 0,
                  right: 20,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.accent.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.face_retouching_natural,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Instruction card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(context.l10n.holdStill,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.foreground,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    context.l10n.nodHead,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Tips grid
          Row(
            children: [
              _tipTile(Icons.wb_sunny_rounded, context.l10n.goodLight,
                  const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _tipTile(Icons.remove_red_eye_outlined, context.l10n.noGlasses,
                  AppColors.primary),
              const SizedBox(width: 8),
              _tipTile(Icons.sentiment_neutral_rounded,
                  context.l10n.neutralFace, const Color(0xFF168A68)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipTile(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityRow(BuildContext context) {
    // A Wrap: the two notes sit side by side when there is room and stack
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
            const Icon(Icons.lock_rounded,
                size: 14, color: Color(0xFF168A68)),
            const SizedBox(width: 4),
            Text(context.l10n.encrypted256,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user_rounded,
                size: 14, color: Color(0xFF168A68)),
            const SizedBox(width: 4),
            Text(context.l10n.gdprCompliant,
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: AppColors.mutedForeground)),
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
  const _Step3({super.key, required this.onContinue});

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
                child: const Icon(Icons.shield_rounded,
                    color: AppColors.primary, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F4EE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: const Color(0xFF168A68)
                          .withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: Color(0xFF168A68)),
                    const SizedBox(width: 4),
                    Text(context.l10n.tier1Verified.split('·').first.trim() + ',',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1.0,
                          color: const Color(0xFF168A68),
                        )),
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
                            color: const Color(0xFF168A68), width: 4),
                        color: AppColors.background,
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://lh3.googleusercontent.com/a/ACg8ocJ97aGjnJ1qNWsqUS-lOIkKvwls8WK-SI54YY8POZz7eBd4JRE=s96-c',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              Container(
                            color: AppColors.secondary,
                            child: const Icon(Icons.person,
                                size: 48,
                                color: AppColors.primary),
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
                              color: AppColors.background, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.verified_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(context.l10n.fullyVerified,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.5,
                      color: AppColors.foreground,
                    )),
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
                    shadowColor:
                        AppColors.accent.withValues(alpha: 0.4),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.l10n.continueToHome,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          )),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward,
                          size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.account_circle_rounded,
                      size: 16, color: AppColors.primary),
                  label: Text(context.l10n.viewPublicProfile,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.foreground,
                      )),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(context.l10n.verificationReport,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: AppColors.mutedForeground,
                    )),
              ),
              const SizedBox(width: 8),
              Text(context.l10n.instantApproval,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: const Color(0xFF168A68),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          _reportRow(context, Icons.credit_card_rounded, context.l10n.passportIdDoc,
              'Verified', const Color(0xFF168A68)),
          const SizedBox(height: 10),
          _reportRow(context, Icons.face_retouching_natural,
              context.l10n.biometricLiveness, '99.8% Match',
              const Color(0xFF168A68)),
          const SizedBox(height: 10),
          _reportRow(context, Icons.shield_rounded,
              context.l10n.trustLimit, '\$2,500 / delivery',
              AppColors.accent),
        ],
      ),
    );
  }

  Widget _reportRow(BuildContext context,
      IconData icon, String label, String value, Color valueColor) {
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
          child: Text(label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.foreground,
              )),
        ),
        Row(
          children: [
            if (valueColor == const Color(0xFF168A68))
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: Color(0xFF168A68)),
            if (valueColor == const Color(0xFF168A68))
              const SizedBox(width: 4),
            Text(value,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: valueColor,
                )),
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
              const Icon(Icons.card_giftcard_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(context.l10n.unlockedPerks,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppColors.foreground,
                    )),
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
                    .map((p) => SizedBox(
                          width: itemWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: Color(0xFF168A68)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(p,
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                      color: AppColors.mutedForeground,
                                    )),
                              ),
                            ],
                          ),
                        ))
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
          Text(l.identityVerificationTitle.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.primary,
              )),
          Text(
            step == 0 ? l.step1of2 : l.step2of2,
            style: GoogleFonts.dmSans(
              fontWeight: step == 1 ? FontWeight.w800 : FontWeight.w700,
              fontSize: 11,
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
                color: step == 0
                    ? AppColors.accent
                    : const Color(0xFF168A68),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: step == 1
                    ? AppColors.accent
                    : AppColors.muted,
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
  return Builder(builder: (context) {
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
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_rounded,
                      size: 18, color: Colors.white),
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
          Text(footnote,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.mutedForeground,
              )),
        ],
      ),
    );
  });
}
