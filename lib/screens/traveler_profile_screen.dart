import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/traveler_service.dart';
import '../widgets/avatar_image.dart';
import 'delivery_request_screen.dart';
import '../l10n/l10n_ext.dart';

/// Shows a traveler's profile and the trip the user picked.
///
/// [trip] (from the search results or Home) provides immediate content; the
/// full public profile and the traveler's other upcoming trips are then loaded
/// in the background.
class TravelerProfileScreen extends StatefulWidget {
  final TravelerTrip trip;

  /// Override for tests; defaults to the real [TravelerService].
  final TravelerService? service;

  const TravelerProfileScreen({super.key, required this.trip, this.service});

  @override
  State<TravelerProfileScreen> createState() => _TravelerProfileScreenState();
}

class _TravelerProfileScreenState extends State<TravelerProfileScreen> {
  late TravelerTrip _trip = widget.trip;
  TravelerProfile? _profile;

  String get _name => _profile?.fullName.isNotEmpty == true
      ? _profile!.fullName
      : widget.trip.fullName;
  String? get _avatarPath => _profile?.avatarPath ?? widget.trip.avatarPath;
  double? get _rating => _profile?.avgRating ?? widget.trip.avgRating;
  int get _delivered => _profile?.itemsDelivered ?? widget.trip.itemsDelivered;

  static String _fmtDate(DateTime d) => DateFormat('MMM d').format(d);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant TravelerProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.tripId != widget.trip.tripId) {
      _trip = widget.trip;
      _profile = null;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final service = widget.service ?? TravelerService();
      final profile = await service.getProfile(widget.trip.travelerId);
      if (!mounted || profile == null) return;
      setState(() => _profile = profile);
    } catch (_) {
      // Non-fatal: the screen already shows the data from the search result.
    }
  }

  // Shared card look: rounded-2xl, 1px border, shadow-sm.
  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: AppColors.border),
    boxShadow: const [
      BoxShadow(color: Color(0x1A000000), blurRadius: 3, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 2,
        spreadRadius: -1,
        offset: Offset(0, 1),
      ),
    ],
  );

  // Card section title: small, uppercase, bold, wide tracking, with an icon.
  Widget _sectionTitle(IconData icon, Color iconColor, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.68,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMoreTrips = (_profile?.trips.length ?? 0) > 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  _buildHeader(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildProfileCard(context),
                        const SizedBox(height: 16),
                        _buildRouteCard(context),
                        const SizedBox(height: 16),
                        _buildCapacityCard(context),
                        const SizedBox(height: 16),
                        if (hasMoreTrips) ...[
                          _buildUpcomingTripsCard(context),
                          const SizedBox(height: 16),
                        ],
                        _buildReviewsCard(context),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildSendRequestBar(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
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
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                context.l10n.travelerProfile,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.share_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile hero card ──────────────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context) {
    final l = context.l10n;
    final subtitle = _delivered >= 10
        ? l.frequentTravelerOnRoute(_trip.departureCity, _trip.arrivalCity)
        : l.travelerOnRoute(_trip.departureCity, _trip.arrivalCity);

    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar with a 2px ring
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: ClipOval(
              child: AvatarImage(
                path: _avatarPath,
                fallback: Container(
                  color: AppColors.secondary,
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          // Stats row: centered with thin dividers. The gaps are 24px as in the
          // design, but shrink on narrow cards, and each stat may wrap its
          // label, so longer translations never overflow.
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = constraints.maxWidth >= 300 ? 24.0 : 12.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: _stat('$_delivered', l.itemsDeliveredStat)),
                  SizedBox(width: gap),
                  _divider(),
                  SizedBox(width: gap),
                  Flexible(
                    child: _ratingStat(
                      _rating?.toStringAsFixed(1) ?? l.newTravelerRating,
                      l.ratingStat,
                    ),
                  ),
                  SizedBox(width: gap),
                  _divider(),
                  SizedBox(width: gap),
                  Flexible(
                    child: _stat(
                      '${_profile?.trips.length ?? 1}',
                      l.upcomingTripsStat,
                      valueColor: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: valueColor ?? AppColors.foreground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _ratingStat(String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFE5A83B)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 24, color: AppColors.border);

  // ── Route card ─────────────────────────────────────────────────────────────
  Widget _buildRouteCard(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.route_rounded,
            AppColors.primary,
            l.travelDateAndRoute,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Departure
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.departure,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Text(
                      _trip.departureCity,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      '${_trip.departureCountry} · ${_fmtDate(_trip.departureDate)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              // Destination
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l.destination,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Text(
                      _trip.arrivalCity,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      '${_trip.arrivalCountry} · ${_fmtDate(_trip.arrivalDate)}',
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
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.local_offer_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l.pricingLabel} '),
                      TextSpan(
                        text: l.pricingValue,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_trip.currency} ${_trip.price.toStringAsFixed(2)}',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Capacity card ──────────────────────────────────────────────────────────
  Widget _buildCapacityCard(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.straighten_rounded,
            AppColors.primary,
            l.itemSizeAndWeight,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _capacityTile(
                  label: 'WEIGHT LIMIT',
                  value: _trip.maxWeightKg == null
                      ? '—'
                      : 'Up to ${_trip.maxWeightKg!.toStringAsFixed(1)} kg',
                  sub: l.checkBaggage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _capacityTile(
                  label: 'SIZE LIMIT',
                  value: _trip.maxSize ?? '—',
                  sub: '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6EE),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.itemRequirement,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.itemRequirementBody,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.foreground,
                          height: 1.625,
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

  Widget _capacityTile({
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
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
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }

  // ── Upcoming trips card ────────────────────────────────────────────────────
  Widget _buildUpcomingTripsCard(BuildContext context) {
    final trips = _profile?.trips ?? const <TravelerTrip>[];
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.luggage_rounded,
            AppColors.primary,
            context.l10n.upcomingTrips,
          ),
          const SizedBox(height: 12),
          ...trips.map((t) {
            final selected = t.tripId == _trip.tripId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                key: ValueKey('upcoming-trip-${t.tripId}'),
                onTap: () => setState(() => _trip = t),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.05)
                        : AppColors.input,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.departureCity} → ${t.arrivalCity}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmtDate(t.departureDate),
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: selected
                              ? AppColors.accent
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Reviews card ───────────────────────────────────────────────────────────
  // There is no reviews data yet, so this shows an honest empty state instead
  // of made-up reviews. Wire it to a reviews table when one exists.
  Widget _buildReviewsCard(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.star_rounded,
            const Color(0xFFE5A83B),
            l.deliveryHistoryAndReviews,
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l.noReviewsYet,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Send request bar ───────────────────────────────────────────────────────
  Widget _buildSendRequestBar(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.95),
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DeliveryRequestScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.send_outlined,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                context.l10n.sendRequest,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: const Color(0x33000000),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
