import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/request_service.dart';
import '../widgets/nata_toast.dart';
import '../widgets/page_header.dart';
import '../widgets/traveler_photo.dart';
import 'delivery_task_screen.dart';

/// The sender hands their item to the traveler: they check the traveler's
/// face from the ID check, and can take a photo of the traveler with the
/// item (optional). Open while the request is paid or picked up.
class HandoverCheckScreen extends StatefulWidget {
  final SentRequest request;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  /// Takes a photo; defaults to [DeliveryTaskScreen.pickPhoto].
  final Future<Uint8List?> Function(BuildContext context)? photoPicker;

  const HandoverCheckScreen({
    super.key,
    required this.request,
    this.service,
    this.photoPicker,
  });

  @override
  State<HandoverCheckScreen> createState() => _HandoverCheckScreenState();
}

class _HandoverCheckScreenState extends State<HandoverCheckScreen> {
  static const _green = Color(0xFF168A68);
  static const _greenBg = Color(0xFFE4F4EE);

  bool _loading = true;
  HandoverFace? _face;

  /// The photo taken here, or the link to the one taken before.
  Uint8List? _photo;
  String? _photoUrl;
  bool _saving = false;

  RequestService get _service => widget.service ?? RequestService();
  String get _name => widget.request.trip.firstName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    HandoverFace? face;
    String? photoUrl;
    try {
      face = await _service.handoverTravelerFace(widget.request.id);
    } catch (e) {
      debugPrint('[HandoverCheck] face: $e');
    }
    try {
      photoUrl = await _service.senderHandoverPhotoUrl(widget.request.id);
    } catch (e) {
      debugPrint('[HandoverCheck] photo: $e');
    }
    if (!mounted) return;
    setState(() {
      _face = face;
      _photoUrl = photoUrl;
      _loading = false;
    });
  }

  Future<void> _takePhoto() async {
    if (_saving) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final photo = await (widget.photoPicker ?? DeliveryTaskScreen.pickPhoto)(
      context,
    );
    if (photo == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.uploadSenderHandoverPhoto(widget.request.id, photo);
      if (!mounted) return;
      setState(() => _photo = photo);
      messenger.showSnackBar(
        nataToast(l.hoPhotoSaved, tone: ToastTone.success),
      );
    } catch (e) {
      debugPrint('[HandoverCheck] upload: $e');
      messenger.showSnackBar(
        nataToast(l.errHoPhotoFailed, tone: ToastTone.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.border),
  );

  Widget _faceCard() {
    final l = context.l10n;
    final url = _face?.selfieUrl;
    final fallback = TravelerPhoto(
      path: widget.request.trip.avatarPath,
      revealed: true,
      size: 120,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        children: [
          if (url != null)
            ClipRRect(
              key: const ValueKey('handover-traveler-face'),
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                url,
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            )
          else
            KeyedSubtree(
              key: const ValueKey('handover-traveler-avatar'),
              child: fallback,
            ),
          const SizedBox(height: 16),
          Text(
            l.hoCheckTitle(_name),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.3,
              color: AppColors.foreground,
            ),
          ),
          if (_face?.verified == true) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('handover-traveler-verified'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _greenBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 14, color: _green),
                  const SizedBox(width: 4),
                  Text(
                    l.hoIdVerified,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: _green,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            url != null ? l.hoCheckBody(_name) : l.hoNoFace(_name),
            key: const ValueKey('handover-face-note'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    final l = context.l10n;
    final hasPhoto = _photo != null || _photoUrl != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.hoPhotoTitle(_name),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.hoOptional,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.hoPhotoBody(_name),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 12),
            ClipRRect(
              key: const ValueKey('handover-sender-photo'),
              borderRadius: BorderRadius.circular(16),
              child: _photo != null
                  ? Image.memory(
                      _photo!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(height: 180, color: AppColors.secondary),
                    )
                  : Image.network(
                      _photoUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(height: 180, color: AppColors.secondary),
                    ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('handover-take-photo'),
              onPressed: _saving ? null : _takePhoto,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_rounded, size: 16),
              label: Text(
                hasPhoto ? l.retake : l.takePhoto,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            PageHeader(title: l.handOverItem),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      children: [
                        _faceCard(),
                        const SizedBox(height: 16),
                        _photoCard(),
                      ],
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('handover-done'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentForeground,
                    shape: const StadiumBorder(),
                    textStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text(l.hoDone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
