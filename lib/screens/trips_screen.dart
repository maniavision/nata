import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';
import '../services/screen_cache.dart';
import '../services/verify_gate.dart';
import '../services/trip_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'add_trip_screen.dart';
import 'requests_screen.dart';

/// "My Trips": the signed-in traveler's trips, split into Upcoming and Past.
class TripsScreen extends StatefulWidget {
  /// Override for tests; defaults to the real [TripService].
  final TripService? service;

  const TripsScreen({super.key, this.service});

  /// Where the trips are kept between visits (ScreenCache).
  static const cacheKey = 'trips';

  /// Loads the trips ahead of a first visit (from Home).
  static Future<void> preload([TripService? service]) async {
    if (ScreenCache.read<List<Trip>>(cacheKey) != null) return;
    final trips = await (service ?? TripService()).myTrips();
    ScreenCache.write(cacheKey, trips);
  }

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  static const _green = Color(0xFF168A68);
  static const _greenBg = Color(0xFFE4F4EE);

  List<Trip> _trips = const [];
  bool _loading = true;
  bool _failed = false;
  int _tab = 0; // 0 = upcoming, 1 = past

  @override
  void initState() {
    super.initState();
    // What this page showed last time, straight away; then the latest.
    final cached = ScreenCache.read<List<Trip>>(TripsScreen.cacheKey);
    if (cached != null) {
      _trips = cached;
      _loading = false;
    }
    _load(quiet: cached != null);
  }

  /// [quiet] refreshes keep what is on screen if they fail.
  Future<void> _load({bool quiet = false}) async {
    try {
      final trips = await (widget.service ?? TripService()).myTrips();
      ScreenCache.write(TripsScreen.cacheKey, trips);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || quiet) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<Trip> get _upcoming =>
      _trips.where((t) => t.isUpcoming(_today)).toList();

  /// Most recent first.
  List<Trip> get _past =>
      _trips.where((t) => !t.isUpcoming(_today)).toList()
        ..sort((a, b) => b.departureDate.compareTo(a.departureDate));

  Future<void> _openAddTrip({Trip? trip}) async {
    // Editing an existing trip stays open; posting a new one needs a
    // passed identity check.
    if (trip == null &&
        !await VerifyGate.check(
          context,
          message: context.l10n.verifyToAddTrip,
        )) {
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTripScreen(trip: trip, service: widget.service),
      ),
    );
    if (saved == true && mounted) _load();
  }

  void _openRequests() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RequestsScreen()));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                _buildTabs(),
                Expanded(child: _buildBody()),
              ],
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppBottomNav(current: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final mode = context.l10n.travelerMode;
    final modeText = mode.isEmpty
        ? mode
        : mode[0] + mode.substring(1).toLowerCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modeText,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                context.l10n.myTrips,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          GestureDetector(
            key: const ValueKey('trips-add'),
            onTap: _openAddTrip,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_circle_rounded,
                size: 20,
                color: AppColors.primaryForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(int index, String label, int count) {
      final active = _tab == index;
      return Expanded(
        child: GestureDetector(
          key: ValueKey('trips-tab-$index'),
          onTap: () => setState(() => _tab = index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.card : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
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
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: active
                          ? AppColors.accentForeground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            tab(0, context.l10n.tabUpcoming, _upcoming.length),
            tab(1, context.l10n.tabPast, _past.length),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2.5,
        ),
      );
    }
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.couldNotLoadTrips,
                key: const ValueKey('trips-error'),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _retry, child: Text(context.l10n.retry)),
            ],
          ),
        ),
      );
    }

    final trips = _tab == 0 ? _upcoming : _past;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          if (trips.isEmpty) _buildEmpty(),
          for (final t in trips)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildTripCard(t),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final upcoming = _tab == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 32, 0, 16),
      child: Column(
        key: ValueKey(upcoming ? 'trips-empty-upcoming' : 'trips-empty-past'),
        children: [
          const Icon(
            Icons.luggage_outlined,
            size: 40,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 10),
          Text(
            upcoming ? context.l10n.noUpcomingTrips : context.l10n.noPastTrips,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          if (upcoming) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.addTripPrompt,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              key: const ValueKey('trips-empty-add'),
              onPressed: _openAddTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: Text(context.l10n.addATrip),
            ),
          ],
        ],
      ),
    );
  }

  // ── Trip card ──────────────────────────────────────────────────────────────
  Widget _chip(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 10,
        color: fg,
      ),
    ),
  );

  Widget _statusChip(Trip t) {
    final l = context.l10n;
    switch (t.status) {
      case TripStatus.live:
        return _chip(l.tripPublished, _green, _greenBg);
      case TripStatus.completed:
        return _chip(
          l.tripCompleted,
          AppColors.mutedForeground,
          AppColors.secondary,
        );
      case TripStatus.cancelled:
        return _chip(
          l.tripCancelled,
          AppColors.destructive,
          AppColors.destructive.withValues(alpha: 0.1),
        );
      default:
        return _chip(
          l.tripInReview,
          AppColors.accent,
          AppColors.accent.withValues(alpha: 0.1),
        );
    }
  }

  Widget _statTile(String value, String label, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: valueColor ?? AppColors.foreground,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip t) {
    final l = context.l10n;
    final upcoming = t.isUpcoming(_today);
    final live = t.isLive && upcoming;
    final dateText = DateFormat('MMM dd, yyyy').format(t.departureDate);

    return Opacity(
      opacity: upcoming ? 1 : 0.8,
      child: Container(
        key: ValueKey('trip-card-${t.id}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: live ? _green.withValues(alpha: 0.3) : AppColors.border,
            width: live ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 2,
              spreadRadius: -1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _statusChip(t),
                            if (t.bookingReference != null)
                              _chip(
                                l.bookingReferenceShort(t.bookingReference!),
                                AppColors.mutedForeground,
                                AppColors.secondary,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${t.departureCity} → ${t.arrivalCity}',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${t.departureCountry} · ${t.arrivalCountry}',
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
                        color: live
                            ? AppColors.accent.withValues(alpha: 0.1)
                            : AppColors.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dateText,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: live
                              ? AppColors.accent
                              : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.departure,
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
            if (upcoming) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _statTile(
                    t.maxWeightKg == null
                        ? '—'
                        : '${t.maxWeightKg!.toStringAsFixed(1)} kg',
                    l.maxWeightLabel,
                  ),
                  const SizedBox(width: 8),
                  _statTile(l.tripSizeShort(t.maxSize), l.maxSizeLabel),
                  const SizedBox(width: 8),
                  _statTile(
                    '${t.requestsCount}',
                    l.requests,
                    valueColor: t.requestsCount > 0
                        ? _green
                        : AppColors.mutedForeground,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (t.isInReview) ...[
                Text(
                  l.tripInReviewNote,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: ValueKey('trip-edit-${t.id}'),
                      onPressed: () => _openAddTrip(trip: t),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: Text(l.editTrip),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.foreground,
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (t.isLive) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: ValueKey('trip-requests-${t.id}'),
                        onPressed: _openRequests,
                        icon: const Icon(Icons.assignment_rounded, size: 15),
                        label: Text(l.viewRequests),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryForeground,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else if (t.status == TripStatus.completed) ...[
              const SizedBox(height: 12),
              Text(
                l.itemsDeliveredCount(t.deliveredCount),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
