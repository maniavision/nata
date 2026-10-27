import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import 'package:intl/intl.dart';
import '../services/payment_service.dart';
import '../services/request_service.dart';
import '../widgets/avatar_image.dart';
import 'delivery_confirm_screen.dart';
import 'review_screen.dart';
import 'messages_screen.dart';
import '../widgets/camera_denied_sheet.dart';
import 'recipient_chat_screen.dart';

/// A request the traveler accepted and is now carrying, as Requests >
/// Incoming shows it.
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

  final String recipientName;

  /// Where to meet the recipient, when agreed.
  final String? meetingSpot;

  /// The request (nata.delivery_requests id) the actions apply to.
  final String requestId;

  /// The sender's photo (avatars bucket), when they have one.
  final String? senderAvatarPath;

  /// When the traveler marked the item picked up; null until then.
  final DateTime? pickedUpAt;

  /// The request this was made from, for rating its sender once delivered.
  final IncomingRequest? source;

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
    required this.recipientName,
    this.meetingSpot,
    required this.requestId,
    this.senderAvatarPath,
    this.pickedUpAt,
    this.source,
  });

  /// The traveler's paid (or picked up) request, ready to show. [payout] is
  /// the formatted amount they earn.
  factory AcceptedDelivery.fromIncoming(
    IncomingRequest r, {
    required String payout,
    required String locale,
  }) {
    final weight = NumberFormat('0.##', locale).format(r.weightKg);
    return AcceptedDelivery(
      source: r,
      requestId: r.id,
      // The start of the id is enough to tell deliveries apart.
      orderId: r.id
          .substring(0, r.id.length < 8 ? r.id.length : 8)
          .toUpperCase(),
      senderName: r.senderName,
      senderPhotoUrl: '',
      senderAvatarPath: r.senderAvatarPath,
      senderSubtitle: '',
      // Senders and travelers talk in Messages; phone numbers stay private.
      senderPhone: '',
      payout: payout,
      trip: r.routeLabel,
      routeCodes: r.routeLabel,
      travelDate: DateFormat.yMMMd(locale).format(r.departureDate),
      destinationCity: r.arrivalCity,
      itemSummary: r.itemsSummary,
      itemName: r.itemsSummary,
      itemDetails: [
        '$weight kg',
        if ((r.dimensions ?? '').trim().isNotEmpty) '${r.dimensions} cm',
      ].join(' · '),
      recipientName: r.recipientName ?? '',
      pickedUpAt: r.isPickedUp ? (r.pickedUpAt ?? DateTime.now()) : null,
    );
  }
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

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? requestService;

  const DeliveryTaskScreen({
    super.key,
    required this.delivery,
    this.photoPicker,
    this.paymentService,
    this.requestService,
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
      if (context.mounted && isCameraDenied(e)) {
        await showCameraDeniedSheet(context);
      }
      return null;
    }
  }

  @override
  State<DeliveryTaskScreen> createState() => _DeliveryTaskScreenState();
}

class _DeliveryTaskScreenState extends State<DeliveryTaskScreen> {
  String? _error;
  late DateTime? _pickedUpAt = widget.delivery.pickedUpAt;
  bool _markingPickedUp = false;

  /// The photos taken on this visit (up to 3 each): the sealed box at
  /// pickup, and the handover (uploaded when the traveler goes on to the
  /// code).
  final List<Uint8List> _pickupPhotos = [];
  final List<Uint8List> _handoverPhotos = [];
  bool _handoverUploaded = false;
  bool _uploadingHandover = false;

  Future<Uint8List?> _takePhoto() =>
      (widget.photoPicker ?? DeliveryTaskScreen.pickPhoto)(context);

  /// Something changed (picked up, delivered): Requests reloads on return.
  bool _changed = false;

  AcceptedDelivery get d => widget.delivery;
  RequestService get _service => widget.requestService ?? RequestService();

  /// Adds a photo of the sealed box (up to 3) before the pickup.
  Future<void> _addPickupPhoto() async {
    if (_pickupPhotos.length >= RequestService.maxDeliveryPhotos) return;
    final photo = await _takePhoto();
    if (photo == null || !mounted) return;
    setState(() {
      _pickupPhotos.add(photo);
      _error = null;
    });
  }

  /// At least one photo of the sealed box (taken now if there's none yet),
  /// then the pickup is recorded.
  Future<void> _markPickedUp() async {
    if (_markingPickedUp || _pickedUpAt != null) return;
    if (_pickupPhotos.isEmpty) {
      final photo = await _takePhoto();
      if (photo == null || !mounted) return;
      _pickupPhotos.add(photo);
    }
    setState(() {
      _markingPickedUp = true;
      _error = null;
    });
    try {
      await _service.uploadDeliveryPhotos(
        d.requestId,
        DeliveryPhotoKind.pickup,
        List.of(_pickupPhotos),
      );
      await _service.markPickedUp(d.requestId);
      if (!mounted) return;
      setState(() {
        _pickedUpAt = DateTime.now();
        _changed = true;
      });
    } catch (e) {
      debugPrint('[DeliveryTask] picked up: $e');
      if (mounted) setState(() => _error = context.l10n.errPickUpFailed);
    } finally {
      if (mounted) setState(() => _markingPickedUp = false);
    }
  }

  void _call(String phone) {
    launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
  }

  /// Opens Delivery & Payout Release, where the recipient's code is
  /// entered. Back here once delivered, then back to Requests.
  Future<void> _attachHandover() async {
    if (_handoverPhotos.length >= RequestService.maxDeliveryPhotos) return;
    final photo = await _takePhoto();
    if (photo == null || !mounted) return;
    setState(() {
      _handoverPhotos.add(photo);
      _handoverUploaded = false;
      _error = null;
    });
  }

  Future<void> _confirmDelivery() async {
    final l = context.l10n;
    if (_pickedUpAt == null) {
      setState(() => _error = l.pickUpFirst);
      return;
    }
    if (_handoverPhotos.isEmpty) {
      setState(() => _error = l.attachHandoverFirst);
      return;
    }
    if (!_handoverUploaded) {
      setState(() {
        _uploadingHandover = true;
        _error = null;
      });
      try {
        await _service.uploadDeliveryPhotos(
          d.requestId,
          DeliveryPhotoKind.handover,
          List.of(_handoverPhotos),
        );
        _handoverUploaded = true;
      } catch (e) {
        debugPrint('[DeliveryTask] handover photo: $e');
        if (mounted) setState(() => _error = l.errPhotoUpload);
        return;
      } finally {
        if (mounted) setState(() => _uploadingHandover = false);
      }
      if (!mounted) return;
    }
    setState(() => _error = null);
    final delivered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DeliveryConfirmScreen(
          delivery: d,
          paymentService: widget.paymentService,
          requestService: widget.requestService,
        ),
      ),
    );
    if (delivered != true || !mounted) return;
    // Delivered: on to rating the sender, then back to Requests, which
    // reloads only now, so the card shows the review as done (not "Rate
    // the sender" again).
    final source = d.source;
    if (source != null) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ReviewScreen.sender(
            request: source,
            service: widget.requestService,
          ),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
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
            onTap: () => Navigator.of(context).pop(_changed),
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
                  child: d.senderPhotoUrl.isNotEmpty
                      ? Image.network(
                          d.senderPhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _personIcon(),
                        )
                      : AvatarImage(
                          path: d.senderAvatarPath,
                          fallback: _personIcon(),
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
              if (d.senderPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                _circleButton(
                  key: const ValueKey('delivery-task-call'),
                  icon: Icons.phone_rounded,
                  onTap: () => _call(d.senderPhone),
                ),
              ],
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
  Widget _personIcon() => Container(
    color: AppColors.secondary,
    child: const Icon(Icons.person, color: AppColors.primary),
  );

  Widget _receivedStep(AppLocalizations l) {
    final pickedUpAt = _pickedUpAt;
    final locale = Localizations.localeOf(context).toString();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            number: 1,
            numberBg: pickedUpAt != null ? _green : AppColors.primary,
            numberFg: Colors.white,
            title: l.itemReceivedFromSender,
            chip: pickedUpAt != null
                ? _chip(
                    l.pickedUp,
                    color: _green,
                    bg: _greenBg,
                    icon: Icons.check_circle_rounded,
                  )
                : _chip(
                    l.notYet,
                    color: AppColors.accent,
                    bg: AppColors.accent.withValues(alpha: 0.1),
                  ),
          ),
          const SizedBox(height: 12),
          _note(l.itemReceivedNote),
          if (pickedUpAt == null) ...[
            const SizedBox(height: 4),
            _note(l.pickupPhotoHint),
          ],
          const SizedBox(height: 12),
          if (pickedUpAt == null || _pickupPhotos.isNotEmpty) ...[
            _photoRow(
              l,
              photos: _pickupPhotos,
              kind: 'pickup',
              locked: pickedUpAt != null || _markingPickedUp,
              onAdd: _addPickupPhoto,
            ),
            const SizedBox(height: 12),
          ],
          if (pickedUpAt != null)
            Text(
              l.pickedUpOn(
                DateFormat.yMMMd(locale).add_jm().format(pickedUpAt),
              ),
              key: const ValueKey('delivery-task-picked-up-at'),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: _green,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('delivery-task-picked-up'),
                onPressed: _markingPickedUp ? null : _markPickedUp,
                icon: _markingPickedUp
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_rounded, size: 16),
                label: Text(
                  l.pickedUpItem,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _deliveredStep(AppLocalizations l) {
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
            chip: _chip(
              l.pendingDelivery,
              color: AppColors.accent,
              bg: AppColors.accent.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 12),
          _note(l.handoverCodeNote(d.destinationCity)),
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
                if ((d.meetingSpot ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _infoRow(
                    l.meetingSpotLabel,
                    Text(d.meetingSpot!, style: _value),
                  ),
                ],
              ],
            ),
          ),
          // The recipient isn't on Nata: they answer from the link texted
          // to them.
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('delivery-task-message-recipient'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipientChatScreen(
                    requestId: d.requestId,
                    recipientName: d.recipientName,
                    service: widget.requestService,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: Text(
                l.recipientMessageButton(
                  d.recipientName.trim().isEmpty
                      ? l.recipientNameLabel
                      : d.recipientName.trim().split(RegExp(r'\s+')).first,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (_pickedUpAt != null) ...[
            const SizedBox(height: 12),
            _photoRow(
              l,
              photos: _handoverPhotos,
              kind: 'handover',
              locked: _uploadingHandover,
              onAdd: _attachHandover,
              addLabel: l.takeOrUploadHandoverPhoto,
            ),
            if (_handoverPhotos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: _green,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.handoverPhotoAttached,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: _green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// A step's photos (up to 3) as square tiles, each with ✕ to remove it
  /// until it's sent, then an "Add photo" tile while there's room.
  Widget _photoRow(
    AppLocalizations l, {
    required List<Uint8List> photos,
    required String kind,
    required bool locked,
    required VoidCallback onAdd,
    String? addLabel,
  }) {
    const max = RequestService.maxDeliveryPhotos;
    final canAdd = !locked && photos.length < max;
    if (photos.isEmpty && canAdd && addLabel != null) {
      // No photo yet: one clear button, as before.
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: ValueKey(
            kind == 'handover'
                ? 'delivery-task-attach-handover'
                : 'delivery-task-add-$kind-photo',
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.photo_camera_rounded, size: 16),
          label: Text(
            addLabel,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
    Widget tile(Widget child) =>
        Expanded(child: AspectRatio(aspectRatio: 1, child: child));
    return Column(
      key: ValueKey('delivery-task-$kind-photos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.photosUpToThree,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
            Text(
              '${photos.length}/$max',
              key: ValueKey('delivery-task-$kind-photo-count'),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < max; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              if (i < photos.length)
                tile(
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        key: ValueKey('delivery-task-$kind-photo-$i'),
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.secondary,
                            child: const Icon(
                              Icons.image_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      if (!locked)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            key: ValueKey('delivery-task-remove-$kind-$i'),
                            onTap: () => setState(() {
                              photos.removeAt(i);
                              if (kind == 'handover') {
                                _handoverUploaded = false;
                              }
                            }),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else if (i == photos.length && canAdd)
                tile(
                  GestureDetector(
                    key: ValueKey('delivery-task-add-$kind-photo'),
                    onTap: onAdd,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.addPhoto,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ],
        ),
      ],
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
            onPressed:
                _pickedUpAt == null ||
                    _handoverPhotos.isEmpty ||
                    _uploadingHandover
                ? null
                : _confirmDelivery,
            icon: _uploadingHandover
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_rounded, size: 18),
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
