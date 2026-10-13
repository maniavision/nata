import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/app_bottom_nav.dart';
import 'checkout_escrow_screen.dart';
import 'delivery_task_screen.dart';
import 'messages_screen.dart';
import 'traveler_results_screen.dart';
import '../l10n/l10n_ext.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  int _tab = 0; // 0 = Incoming, 1 = Outgoing

  // ── Incoming request data ──────────────────────────────────────────────────
  /// Requests the traveler accepted that are still under way.
  static const _accepted = [
    AcceptedDelivery(
      orderId: 'DEL-8842',
      senderName: 'Sarah Adeleke',
      senderPhotoUrl: 'https://randomuser.me/api/portraits/women/33.jpg',
      senderSubtitle: 'Sender · Escrow Funded',
      senderPhone: '+234 803 555 0142',
      payout: '\$38.00',
      trip: 'Lagos (LOS) → London (LHR)',
      routeCodes: 'LOS → LHR',
      travelDate: 'Jun 22, 2025',
      destinationCity: 'London',
      itemSummary: 'iPad Mini (Sealed Box · 0.6 kg)',
      itemName: 'iPad Mini 64GB (Space Gray)',
      itemDetails: 'Factory Sealed Box · 0.60 kg · 20 × 14 × 4 cm',
      receivedPhotoUrl:
          'https://ggrhecslgdflloszjkwl.supabase.co/storage/v1/object/public/user-assets/zQQR13YtUCF/components/2lLrBm6d5EN.jpeg',
      receivedPhotoName: 'received_sealed_box.jpg',
      receivedPhotoCaption: 'Captured at Lagos Airport · Jun 22, 10:14 AM',
      recipientName: 'David Adeleke (London)',
      recipientPhone: '+44 7700 900456',
      meetingSpot: 'LHR Terminal 4 Arrivals Lounge',
    ),
  ];

  static const _incoming = [
    _IncomingRequest(
      name: 'Chioma Eze',
      subtitle: 'Sender · 5 deliveries',
      amount: '\$32.00',
      trip: 'Lagos (LOS) → London (LHR)',
      date: 'Jun 22, 2025',
      item: 'Apple Watch Series 9 (Sealed Box)',
      weight: '0.45 kg · 15 × 8 × 4 cm',
      photos: '1 factory-sealed photo attached',
      imageUrl: 'https://randomuser.me/api/portraits/women/65.jpg',
    ),
    _IncomingRequest(
      name: 'Tunde Adeleke',
      subtitle: 'Sender · 2 deliveries',
      amount: '\$26.50',
      trip: 'Lagos (LOS) → London (LHR)',
      date: 'Jun 22, 2025',
      item: 'Sony WH-1000XM5 (Retail Box)',
      imageUrl: 'https://randomuser.me/api/portraits/men/45.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildTabSwitcher(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    child: _tab == 0
                        ? _buildIncomingSection()
                        : _buildOutgoingSection(),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AppBottomNav(current: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
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
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.deliveryRequests,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppColors.foreground,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.filter_list_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab switcher ───────────────────────────────────────────────────────────
  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _tabButton(
              context.l10n.incoming,
              0,
              badge: '${_accepted.length + _incoming.length}',
              badgeBg: AppColors.accent,
            ),
            _tabButton(
              context.l10n.outgoing,
              1,
              badge: '3',
              badgeBg: AppColors.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(
    String label,
    int index, {
    required String badge,
    required Color badgeBg,
  }) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('requests-tab-$index'),
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  color: active
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: active ? badgeBg : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: active && index == 0
                          ? Colors.white
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Incoming section ───────────────────────────────────────────────────────
  Widget _buildIncomingSection() {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_accepted.isNotEmpty) ...[
          _acceptedHeader(),
          const SizedBox(height: 10),
          for (final r in _accepted)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _AcceptedCard(request: r),
            ),
        ],
        _sectionHeader(
          l.pendingRequestsCount(_incoming.length),
          l.awaitingYourResponse,
        ),
        const SizedBox(height: 10),
        ..._incoming.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _IncomingCard(request: r),
          ),
        ),
      ],
    );
  }

  Widget _acceptedHeader() {
    final l = context.l10n;
    return Row(
      children: [
        const Icon(Icons.inventory_rounded, size: 16, color: _green),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.acceptedInProgress.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.68,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: _greenBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l.activeCount(_accepted.length),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: _green,
            ),
          ),
        ),
      ],
    );
  }

  // ── Outgoing section ───────────────────────────────────────────────────────
  Widget _buildOutgoingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context.l10n.outgoingSection, '3 ${context.l10n.total}'),
        const SizedBox(height: 10),
        _OutgoingCard(
          name: 'Amara Kalu',
          imageUrl: 'https://randomuser.me/api/portraits/women/44.jpg',
          statusLabel: context.l10n.pending,
          statusColor: const Color(0xFFD97706),
          statusBg: const Color(0xFFFEF3C7),
          item: 'AirPods Max · Lagos → London (Jun 22)',
          amount: '\$27.50',
        ),
        const SizedBox(height: 12),
        _OutgoingCard(
          name: 'Daniel Okafor',
          imageUrl: 'https://randomuser.me/api/portraits/men/32.jpg',
          statusLabel: context.l10n.accepted,
          statusColor: const Color(0xFF168A68),
          statusBg: const Color(0xFFE4F4EE),
          item: 'Kindle Paperwhite · Accra → Paris (Jun 24)',
          amount: '\$19.00',
          payCountdown: 'Pay in 23h 48m',
          payAmount: '\$19',
        ),
        const SizedBox(height: 12),
        _OutgoingCard(
          name: 'Maya Tariq',
          imageUrl: 'https://randomuser.me/api/portraits/women/68.jpg',
          statusLabel: context.l10n.declined,
          statusColor: AppColors.destructive,
          statusBg: const Color(0xFFFDE8E8),
          item: 'Luggage capacity full · Nairobi → Dubai',
          amount: '\$22.00',
          dimmed: true,
          refundNote: context.l10n.refundCredited,
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.68,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          count,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
}

// ── Incoming request card ──────────────────────────────────────────────────
class _IncomingCard extends StatefulWidget {
  final _IncomingRequest request;
  const _IncomingCard({required this.request});

  @override
  State<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends State<_IncomingCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: ClipOval(
                  child: Image.network(
                    widget.request.imageUrl,
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
                    Text(
                      widget.request.name,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      widget.request.subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.request.amount,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          // Details
          _detailRow(context.l10n.yourTrip, widget.request.trip),
          const SizedBox(height: 8),
          _detailRow(context.l10n.travelDate, widget.request.date),
          const SizedBox(height: 8),
          _detailRow(context.l10n.item, widget.request.item),
          if (widget.request.weight != null) ...[
            const SizedBox(height: 8),
            _detailRow(context.l10n.weightAndSize, widget.request.weight!),
          ],
          const SizedBox(height: 12),
          // Photo row
          if (widget.request.photos != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.request.photos!,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      widget.request.photos!.startsWith('2')
                          ? context.l10n.viewPhotos
                          : context.l10n.viewPhoto,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.l10n.decline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _dismissed = true);
                    // Navigate to chat to arrange handoff
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MessagesScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.l10n.acceptRequest,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Outgoing card ──────────────────────────────────────────────────────────
class _OutgoingCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String statusLabel;
  final Color statusColor;
  final Color statusBg;
  final String item;
  final String amount;
  final bool dimmed;
  final String? payCountdown;
  final String? payAmount;
  final String? refundNote;

  const _OutgoingCard({
    required this.name,
    required this.imageUrl,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBg,
    required this.item,
    required this.amount,
    this.dimmed = false,
    this.payCountdown,
    this.payAmount,
    this.refundNote,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.8 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipOval(
                    child: ColorFiltered(
                      colorFilter: dimmed
                          ? const ColorFilter.matrix([
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ])
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: AppColors.secondary,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
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
                          Text(
                            name,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: dimmed
                        ? AppColors.mutedForeground
                        : AppColors.foreground,
                  ),
                ),
              ],
            ),
            // Pay row
            if (payCountdown != null) ...[
              const SizedBox(height: 10),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            payCountdown!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const CheckoutEscrowScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Pay Escrow ($payAmount)',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Chat button for accepted outgoing requests
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const MessagesScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.arrangeHandoff,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Refund / find another row
            if (refundNote != null) ...[
              const SizedBox(height: 10),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      refundNote!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TravelerResultsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      context.l10n.findAnotherTraveler,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────
class _IncomingRequest {
  final String name, subtitle, amount, trip, date, item, imageUrl;

  /// Shown only when the sender gave them.
  final String? weight, photos;
  const _IncomingRequest({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.trip,
    required this.date,
    required this.item,
    required this.imageUrl,
    this.weight,
    this.photos,
  });
}

const _green = Color(0xFF168A68);
const _greenBg = Color(0xFFE4F4EE);

// ── Accepted request card ──────────────────────────────────────────────────
class _AcceptedCard extends StatelessWidget {
  final AcceptedDelivery request;
  const _AcceptedCard({required this.request});

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => DeliveryTaskScreen(delivery: request),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      key: const ValueKey('accepted-request-card'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withValues(alpha: 0.3), width: 2),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sender row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _green.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      request.senderPhotoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            request.senderName,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.foreground,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _greenBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l.accepted,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: _green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        request.senderSubtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _greenBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        request.payout,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: _green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.yourPayout,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            _row(l.tripLabel, Text(request.trip, style: _value)),
            const SizedBox(height: 8),
            _row(l.item, Text(request.itemSummary, style: _value)),
            const SizedBox(height: 8),
            _row(
              l.nextAction,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_a_photo_rounded,
                    size: 13,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l.attachReceivedPhoto,
                      textAlign: TextAlign.right,
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
            const SizedBox(height: 16),
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const ValueKey('manage-delivery'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          l.manageDeliveryAttachProof,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.primaryForeground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        size: 15,
                        color: AppColors.primaryForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _value = GoogleFonts.dmSans(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.foreground,
  );

  Widget _row(String label, Widget value) {
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
