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
import 'route_alerts_screen.dart' show formatKg;
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

  /// The weights to pick from, after Any.
  static const _weightChoices = <double>[2, 5, 10, 20];

  /// Only travelers who can carry at least this much (kg), or everyone.
  double? _minKg;

  /// [_results] the traveler can carry [_minKg] for. A trip with no capacity
  /// set is kept, as for route alerts: the traveler may still take it.
  List<TravelerTrip> get _matching {
    final min = _minKg;
    if (min == null) return _results;
    return [
      for (final r in _results)
        if (r.maxWeightKg == null || r.maxWeightKg! >= min) r,
    ];
  }

  /// [_matching] by departure date; trips on the same day keep the order the
  /// search returned them in.
  List<TravelerTrip> get _sorted {
    final indexed = _matching.indexed.toList()
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

  void _pickWeight(double? kg) => setState(() => _minKg = kg);

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
          if (_results.isNotEmpty) ...[
            _buildWeightFilter(),
            if (_matching.isEmpty) _buildNoneCanCarry() else _buildSortBar(),
          ],
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

  // ── Weight filter ──────────────────────────────────────────────────────────
  /// A card: what is filtered, then a pill for Any and for each weight.
  Widget _buildWeightFilter() {
    final l = context.l10n;
    final min = _minKg;
    Widget pill(String label, double? kg, Key key) {
      final selected = _minKg == kg;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          key: key,
          onTap: () => _pickWeight(kg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.secondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected
                    ? AppColors.primaryForeground
                    : AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.scale_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                l.resultsWeight,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            min == null
                ? l.resultsWeightAnyNote
                : l.resultsWeightAtLeast(formatKg(min)),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              pill(l.resultsWeightAny, null, const ValueKey('weight-any')),
              for (final kg in _weightChoices)
                pill(
                  l.routeAlertsWeightChip(formatKg(kg)),
                  kg,
                  ValueKey('weight-${formatKg(kg)}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Travelers go this way, but none can carry [_minKg].
  Widget _buildNoneCanCarry() {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.scale_outlined,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.resultsWeightNone(formatKg(_minKg!)),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.resultsWeightNoneHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('weight-clear'),
              onPressed: () => _pickWeight(null),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l.resultsWeightClear,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
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
              _loading ? '…' : context.l10n.availableCount(_matching.length),
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

/// The search a "traveler going your way" alert opens (event trip_match):
/// the saved route, any date. Null if the alert lacks its places.
Widget? resultsForRouteAlert(Map<String, dynamic> payload) {
  LocationSelection? place(String side) {
    // A number in the in-app notification, text in a push.
    final raw = payload['${side}_city_id'];
    final id = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    final city = (payload['${side}_city'] as String?) ?? '';
    final country = (payload['${side}_country'] as String?) ?? '';
    final code = ((payload['${side}_country_code'] as String?) ?? '').trim();
    if (id == null || city.isEmpty) return null;
    return LocationSelection(
      country: country,
      countryCode: code,
      city: city,
      displayLabel: country.isEmpty ? city : '$city, $country',
      cityId: id,
    );
  }

  final from = place('from');
  final to = place('to');
  if (from == null || to == null) return null;
  return TravelerResultsScreen(departure: from, destination: to);
}
