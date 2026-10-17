import 'package:flutter/material.dart';
import '../services/auth_gate.dart';
import '../l10n/l10n_ext.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/traveler_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/avatar_image.dart';
import '../widgets/location_search_sheet.dart';
import 'traveler_profile_screen.dart';

class TravelerResultsScreen extends StatefulWidget {
  /// Search criteria from Home. All optional: with none, every upcoming
  /// traveler is listed.
  final LocationSelection? departure;
  final LocationSelection? destination;
  final DateTime? date;

  /// Override for tests; defaults to the real [TravelerService].
  final TravelerService? service;

  const TravelerResultsScreen({
    super.key,
    this.departure,
    this.destination,
    this.date,
    this.service,
  });

  @override
  State<TravelerResultsScreen> createState() => _TravelerResultsScreenState();
}

class _TravelerResultsScreenState extends State<TravelerResultsScreen> {
  bool _notifyMe = true;
  bool _loading = true;
  String? _error;
  List<TravelerTrip> _results = const [];

  /// Earliest departure first (the default), or latest first.
  bool _latestFirst = false;

  /// [_results] by departure date; trips on the same day keep the order the
  /// search returned them in.
  List<TravelerTrip> get _sorted {
    final indexed = _results.indexed.toList()
      ..sort((a, b) {
        final byDate = a.$2.departureDate.compareTo(b.$2.departureDate);
        if (byDate != 0) return _latestFirst ? -byDate : byDate;
        return a.$1.compareTo(b.$1);
      });
    return [for (final (_, trip) in indexed) trip];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await (widget.service ?? TravelerService()).search(
        departureCountry: widget.departure?.countryCode,
        departureCity: widget.departure?.city,
        arrivalCountry: widget.destination?.countryCode,
        arrivalCity: widget.destination?.city,
        date: widget.date,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.errLoadTravelersRetry;
        _loading = false;
      });
    }
  }

  String _fmtShort(DateTime d) =>
      DateFormat.MMMd(Localizations.localeOf(context).toString()).format(d);

  /// e.g. "Lagos → London · before Jun 26"
  String get _searchSummary {
    final l = context.l10n;
    final from = widget.departure?.city ?? l.anywhere;
    final to = widget.destination?.city ?? l.anywhere;
    final date = widget.date == null
        ? ''
        : ' · ${l.byDate(_fmtShort(widget.date!))}';
    return '$from → $to$date';
  }

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
                Expanded(child: _buildBody()),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const AppBottomNav(current: 0, isTabRoot: false),
            ),
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
    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: Text(context.l10n.retry)),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 24),
              child: Column(
                children: [
                  const Icon(
                    Icons.luggage_outlined,
                    size: 40,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.noTravelersOnRouteTitle,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.tryAnotherDateOrRoute,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          if (_results.isNotEmpty) _buildSortBar(),
          ..._sorted.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TravelerCard(trip: r, service: widget.service),
            ),
          ),
          _buildNotifyBanner(),
        ],
      ),
    );
  }

  // ── Sort ───────────────────────────────────────────────────────────────────
  Widget _buildSortBar() {
    final l = context.l10n;
    Widget option(String label, bool latest) {
      final selected = _latestFirst == latest;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: ValueKey(latest ? 'sort-latest' : 'sort-earliest'),
          onTap: () => setState(() => _latestFirst = latest),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: selected
                    ? AppColors.primaryForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.sortByDate,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(l.sortEarliest, false),
                option(l.sortLatest, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.foreground,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.travelersFound,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  _searchSummary,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _loading ? '…' : context.l10n.availableCount(_results.length),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notify banner ──────────────────────────────────────────────────────────
  Widget _buildNotifyBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.needDifferentDate,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _notifyMe = !_notifyMe),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 36,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _notifyMe ? AppColors.accent : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment: _notifyMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.notifyNewTravelers,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom nav (5 tabs, Search active) ────────────────────────────────────
}

// ── Traveler card ──────────────────────────────────────────────────────────
class _TravelerCard extends StatefulWidget {
  final TravelerTrip trip;
  final TravelerService? service;
  const _TravelerCard({required this.trip, this.service});

  @override
  State<_TravelerCard> createState() => _TravelerCardState();
}

class _TravelerCardState extends State<_TravelerCard> {
  bool _pressed = false;

  String _fmt(DateTime d) =>
      DateFormat.MMMd(Localizations.localeOf(context).toString()).format(d);

  String get _dateBadge => _fmt(widget.trip.departureDate);

  String get _capacity {
    final w = widget.trip.maxWeightKg;
    if (w == null) return context.l10n.capacityNotSpecified;
    return context.l10n.acceptsUpToKg(w.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Widget profile(BuildContext context) =>
            TravelerProfileScreen(trip: widget.trip, service: widget.service);
        if (!AuthGate.check(
          context,
          message: context.l10n.signInPromptTraveler(widget.trip.firstName),
          next: profile,
        )) {
          return;
        }
        Navigator.of(context).push(MaterialPageRoute(builder: profile));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar + verified badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: ClipOval(
                    child: AvatarImage(
                      path: widget.trip.avatarPath,
                      fallback: Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF168A68),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          widget.trip.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _dateBadge,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.deliveredCount(widget.trip.itemsDelivered),
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        '  •  ',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Color(0xFFE5A83B),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.trip.avgRating?.toStringAsFixed(1) ??
                            context.l10n.newTravelerRating,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.trip.departureCity} → ${widget.trip.arrivalCity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _capacity,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
