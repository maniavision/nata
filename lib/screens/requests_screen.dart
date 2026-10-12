import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/app_bottom_nav.dart';
import 'checkout_escrow_screen.dart';
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
  static const _incoming = [
    _IncomingRequest(
      name: 'Chioma Eze',
      subtitle: 'Sender · 5 successful deliveries',
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
      subtitle: 'Sender · 2 successful deliveries',
      amount: '\$26.50',
      trip: 'Lagos (LOS) → London (LHR)',
      date: 'Jun 22, 2025',
      item: 'Sony WH-1000XM5 (Retail Box)',
      weight: '0.85 kg · 22 × 18 × 7 cm',
      photos: '2 sealed box photos attached',
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
              badge: '2',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context.l10n.incomingSection,
          '2 ${context.l10n.pendingReview}',
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
              fontSize: 10,
              letterSpacing: 1.4,
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
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      widget.request.subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
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
          const SizedBox(height: 6),
          _detailRow(context.l10n.travelDate, widget.request.date),
          const SizedBox(height: 6),
          _detailRow(context.l10n.item, widget.request.item),
          const SizedBox(height: 6),
          _detailRow(context.l10n.weightAndSize, widget.request.weight),
          const SizedBox(height: 12),
          // Photo row
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
                    widget.request.photos,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    widget.request.photos.startsWith('2')
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
                          Icons.cancel_outlined,
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
  final String name,
      subtitle,
      amount,
      trip,
      date,
      item,
      weight,
      photos,
      imageUrl;
  const _IncomingRequest({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.trip,
    required this.date,
    required this.item,
    required this.weight,
    required this.photos,
    required this.imageUrl,
  });
}
