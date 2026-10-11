import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'review_screen.dart';
import '../l10n/l10n_ext.dart';

/// Shown when the traveler has arrived and needs to confirm delivery
/// by entering the recipient's 4-digit code OR uploading a handoff photo.
class DeliveryConfirmScreen extends StatefulWidget {
  const DeliveryConfirmScreen({super.key});

  @override
  State<DeliveryConfirmScreen> createState() => _DeliveryConfirmScreenState();
}

class _DeliveryConfirmScreenState extends State<DeliveryConfirmScreen> {
  final List<TextEditingController> _digitCtrl =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _photoUploaded = false;
  bool _confirmed = false;

  String get _code => _digitCtrl.map((c) => c.text).join();
  bool get _codeComplete => _code.length == 4;

  void _confirm() {
    if (!_codeComplete && !_photoUploaded) return;
    setState(() => _confirmed = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const ReviewScreen()));
      }
    });
  }

  @override
  void dispose() {
    for (final c in _digitCtrl) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  children: [
                    _buildOrderSummary(),
                    const SizedBox(height: 20),
                    _buildCodeSection(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildPhotoSection(),
                    const SizedBox(height: 24),
                    _buildConfirmButton(context),
                    const SizedBox(height: 12),
                    _buildEscrowNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.primary, size: 20),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                context.l10n.confirmDelivery,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded,
                color: AppColors.primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: ClipOval(
              child: Image.network(
                'https://randomuser.me/api/portraits/women/44.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Container(color: AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amara Kalu',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.foreground,
                    )),
                Text('iPhone 15 Pro (Sealed Box) · Order #CW-8921',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F4EE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('\$48 Held',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: const Color(0xFF168A68),
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _codeComplete
                ? const Color(0xFF168A68).withValues(alpha: 0.4)
                : AppColors.border,
            width: _codeComplete ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.enter4DigitCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.recipientWillGive,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // PIN digits
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              return SizedBox(
                width: 60,
                height: 64,
                child: TextField(
                  controller: _digitCtrl[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _digitCtrl[i].text.isNotEmpty
                        ? AppColors.primary.withValues(alpha: 0.06)
                        : AppColors.input,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _digitCtrl[i].text.isNotEmpty
                            ? AppColors.primary
                            : AppColors.border,
                        width: _digitCtrl[i].text.isNotEmpty ? 2 : 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _digitCtrl[i].text.isNotEmpty
                            ? AppColors.primary
                            : AppColors.border,
                        width: _digitCtrl[i].text.isNotEmpty ? 2 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.accent, width: 2),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {});
                    if (v.isNotEmpty && i < 3) {
                      _focusNodes[i + 1].requestFocus();
                    } else if (v.isEmpty && i > 0) {
                      _focusNodes[i - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          if (_codeComplete) ...[
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F4EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Color(0xFF168A68)),
                  const SizedBox(width: 6),
                  Text(context.l10n.codeEntered,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: const Color(0xFF168A68),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
            child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.4,
                color: AppColors.mutedForeground,
              )),
        ),
        const Expanded(
            child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _photoUploaded
                ? const Color(0xFF168A68).withValues(alpha: 0.4)
                : AppColors.border,
            width: _photoUploaded ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.uploadHandoffPhoto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.handoffPhotoSub,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('handoff-photo'),
            onTap: () => setState(() => _photoUploaded = !_photoUploaded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 100,
              decoration: BoxDecoration(
                color: _photoUploaded
                    ? const Color(0xFFE4F4EE)
                    : AppColors.input,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _photoUploaded
                      ? const Color(0xFF168A68)
                      : AppColors.border,
                  style: _photoUploaded
                      ? BorderStyle.solid
                      : BorderStyle.solid,
                  width: _photoUploaded ? 2 : 1,
                ),
              ),
              child: _photoUploaded
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 28, color: Color(0xFF168A68)),
                        const SizedBox(height: 6),
                        Text('handoff_photo.jpg',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: const Color(0xFF168A68),
                            )),
                        Text('Tap to remove',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: AppColors.mutedForeground,
                            )),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_rounded,
                            size: 28, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text('Tap to take or upload photo',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            )),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final enabled = _codeComplete || _photoUploaded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        key: const ValueKey('delivery-confirm'),
        onPressed: enabled ? _confirm : null,
        icon: _confirmed
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.verified_rounded,
                size: 18, color: Colors.white),
        label: Text(
          _confirmed ? 'Confirming delivery...' : context.l10n.confirmDeliveryButton,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF168A68) : AppColors.muted,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF168A68).withValues(alpha: 0.4),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  Widget _buildEscrowNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_rounded,
            size: 14, color: Color(0xFF168A68)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(context.l10n.disputeWindow,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.mutedForeground,
              )),
        ),
      ],
    );
  }
}
