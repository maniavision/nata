import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/payment_service.dart';
import 'delivery_confirm_screen.dart';
import 'messages_screen.dart';

/// A request the traveler accepted and is now carrying. Sample data for now,
/// like the rest of the Requests page.
class AcceptedDelivery {
  final String orderId;
  final String senderName;
  final String senderPhotoUrl;

  /// Shown under the name on the Requests card ("Sender · Escrow Funded").
  final String senderSubtitle;
  final String senderPhone;
  final String payout;

  /// "Lagos (LOS) → London (LHR)" on the Requests card.
  final String trip;

  /// "LOS → LHR" on the details page.
  final String routeCodes;
  final String travelDate;
  final String destinationCity;

  /// "iPad Mini (Sealed Box · 0.6 kg)" on the Requests card.
  final String itemSummary;
  final String itemName;
  final String itemDetails;

  final String receivedPhotoUrl;
  final String receivedPhotoName;
  final String receivedPhotoCaption;

  final String recipientName;
  final String recipientPhone;
  final String meetingSpot;

  /// The 4-digit code the sender gave the recipient, which the recipient
  /// tells the traveler at handoff. Sample data: checked on the device.
  final String? deliveryPin;

  const AcceptedDelivery({
    required this.orderId,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.senderSubtitle,
    required this.senderPhone,
    required this.payout,
    required this.trip,
    required this.routeCodes,
    required this.travelDate,
    required this.destinationCity,
    required this.itemSummary,
    required this.itemName,
    required this.itemDetails,
    required this.receivedPhotoUrl,
    required this.receivedPhotoName,
    required this.receivedPhotoCaption,
    required this.recipientName,
    required this.recipientPhone,
    required this.meetingSpot,
    this.deliveryPin,
  });
}

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);

/// Takes a photo or picks one from the library; returns its bytes.
typedef PhotoPicker = Future<Uint8List?> Function(BuildContext context);

/// Delivery task details: who sent it, what to carry, and the two proof
/// steps (item received from the sender, item handed to the recipient).
class DeliveryTaskScreen extends StatefulWidget {
  final AcceptedDelivery delivery;

  /// Override for tests; defaults to a camera / library sheet.
  final PhotoPicker? photoPicker;

  /// Passed on to Delivery & Payout Release (tests); defaults to the real
  /// [PaymentService].
  final PaymentService? paymentService;

  const DeliveryTaskScreen({
    super.key,
    required this.delivery,
    this.photoPicker,
    this.paymentService,
  });

  /// Takes a photo or picks one from the library (camera / library sheet).
  static Future<Uint8List?> pickPhoto(BuildContext context) async {
    final l = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: Text(l.takePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: Text(l.chatChoosePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      return photo?.readAsBytes();
    } catch (e) {
      debugPrint('[DeliveryTask] photo error: $e');
      return null;
    }
  }

  @override
  State<DeliveryTaskScreen> createState() => _DeliveryTaskScreenState();
}

class _DeliveryTaskScreenState extends State<DeliveryTaskScreen> {
  /// The handover photo the traveler attached (step 2), if any.
  Uint8List? _handoverPhoto;
  String? _error;

  AcceptedDelivery get d => widget.delivery;

  Future<void> _attachHandoverPhoto() async {
    final photo = await (widget.photoPicker ?? DeliveryTaskScreen.pickPhoto)(
      context,
    );
    if (photo == null || !mounted) return;
    setState(() {
      _handoverPhoto = photo;
      _error = null;
    });
  }

  void _call(String phone) {
    launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
  }

  /// Opens Delivery & Payout Release: the handoff is confirmed there with
  /// the recipient's PIN or this handoff photo.
  void _confirmDelivery() {
    setState(() => _error = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeliveryConfirmScreen(
          delivery: d,
          handoverPhoto: _handoverPhoto,
          photoPicker: widget.photoPicker,
          paymentService: widget.paymentService,
        ),
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
            _header(l),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
                children: [
                  _senderCard(l),
                  const SizedBox(height: 16),
                  _itemCard(l),
                  const SizedBox(height: 16),
                  _receivedStep(l),
                  const SizedBox(height: 16),
                  _deliveredStep(l),
                  const SizedBox(height: 24),
                  _confirm(l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _header(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _circleButton(
            key: const ValueKey('delivery-task-back'),
            icon: Icons.arrow_back,
            size: 40,
            iconSize: 20,
            background: AppColors.card,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.deliveryTaskDetails,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  l.orderNumber(d.orderId),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  l.inProgress,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sender ─────────────────────────────────────────────────────────────────
  Widget _senderCard(AppLocalizations l) {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _green.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    d.senderPhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: AppColors.secondary,
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                    Text(
                      l.senderVerifiedIdentity,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              _circleButton(
                key: const ValueKey('delivery-task-message'),
                icon: Icons.chat_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MessagesScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _circleButton(
                key: const ValueKey('delivery-task-call'),
                icon: Icons.phone_rounded,
                onTap: () => _call(d.senderPhone),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _tile(
                    l.yourPayout.toUpperCase(),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: d.payout,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _green,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l.inEscrow}',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _tile(
                    l.deliveryRoute.toUpperCase(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.routeCodes,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          d.travelDate,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
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

  Widget _tile(String label, Widget value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
  }

  // ── Item ───────────────────────────────────────────────────────────────────
  Widget _itemCard(AppLocalizations l) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.itemToCarry.toUpperCase(),
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.44,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        d.itemDetails,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: received from the sender ───────────────────────────────────────
  Widget _receivedStep(AppLocalizations l) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            number: 1,
            numberBg: _green,
            numberFg: Colors.white,
            title: l.itemReceivedFromSender,
            chip: _chip(
              l.attached,
              color: _green,
              bg: _greenBg,
              icon: Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(height: 12),
          _note(l.itemReceivedNote),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    d.receivedPhotoUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.secondary,
                      child: const Icon(
                        Icons.image_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.receivedPhotoName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        d.receivedPhotoCaption,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const ValueKey('delivery-task-retake'),
                  onTap: () {},
                  child: Text(
                    l.retake,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.accent,
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

  // ── Step 2: delivered to the recipient ─────────────────────────────────────
  Widget _deliveredStep(AppLocalizations l) {
    final photo = _handoverPhoto;
    return _card(
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.2),
        width: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            number: 2,
            numberBg: AppColors.primary,
            numberFg: AppColors.primaryForeground,
            title: l.itemDeliveredToRecipient,
            chip: photo == null
                ? _chip(
                    l.pendingDelivery,
                    color: AppColors.accent,
                    bg: AppColors.accent.withValues(alpha: 0.1),
                  )
                : _chip(
                    l.attached,
                    color: _green,
                    bg: _greenBg,
                    icon: Icons.check_circle_rounded,
                  ),
          ),
          const SizedBox(height: 12),
          _note(l.handoverNote(d.destinationCity)),
          const SizedBox(height: 12),
          GestureDetector(
            key: const ValueKey('delivery-task-handover'),
            onTap: _attachHandoverPhoto,
            child: CustomPaint(
              painter: _DashedBorder(
                color: _error != null
                    ? AppColors.destructive
                    : AppColors.border,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: photo == null
                    ? Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 22,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.takeOrUploadHandoverPhoto,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l.handoverPhotoHint,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              photo,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.handoverPhotoAttached,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          Text(
                            l.retake,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _infoRow(
                  l.recipientNameLabel,
                  Text(d.recipientName, style: _value),
                ),
                const SizedBox(height: 4),
                _infoRow(
                  l.recipientPhoneLabel,
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(d.recipientPhone, style: _value)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const ValueKey('delivery-task-call-recipient'),
                        onTap: () => _call(d.recipientPhone),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _infoRow(
                  l.meetingSpotLabel,
                  Text(d.meetingSpot, style: _value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirm ────────────────────────────────────────────────────────────────
  Widget _confirm(AppLocalizations l) {
    return Column(
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            key: const ValueKey('delivery-task-error'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.destructive,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const ValueKey('delivery-task-confirm'),
            onPressed: _confirmDelivery,
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: Text(
              l.confirmDeliveryClaim(d.payout),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.primaryForeground,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l.escrowReleaseNote,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────────────────
  static final _value = GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.foreground,
  );

  Widget _card({required Widget child, BoxBorder? border}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: border ?? Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _circleButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
    double size = 36,
    double iconSize = 16,
    Color background = AppColors.secondary,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: iconSize, color: AppColors.primary),
      ),
    );
  }

  Widget _stepHeader({
    required int number,
    required Color numberBg,
    required Color numberFg,
    required String title,
    required Widget chip,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: numberBg, shape: BoxShape.circle),
          child: Center(
            child: Text(
              '$number',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: numberFg,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 8),
        chip,
      ],
    );
  }

  Widget _chip(
    String text, {
    required Color color,
    required Color bg,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(String text) => Text(
    text,
    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedForeground),
  );

  Widget _infoRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: value),
        ),
      ],
    );
  }
}

/// The dashed outline of the handover photo drop zone.
class _DashedBorder extends CustomPainter {
  final Color color;
  const _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
