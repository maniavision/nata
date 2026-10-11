import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/app_bottom_nav.dart';
import '../l10n/l10n_ext.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/traveler_ranking.dart';
import '../services/traveler_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/location_search_sheet.dart';
import 'add_trip_screen.dart';
import 'notifications_screen.dart';
import 'traveler_profile_screen.dart';
import 'traveler_results_screen.dart';

class HomeScreen extends StatefulWidget {
  /// Optional overrides (used by tests); default to the real services.
  final AuthService? authService;
  final TravelerService? travelerService;
  final NotificationService? notificationService;

  /// Source of randomness for the "Available Travelers" picks (tests pass a
  /// seeded one).
  final Random? random;

  const HomeScreen({
    super.key,
    this.authService,
    this.travelerService,
    this.notificationService,
    this.random,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _selectedDate;

  /// "Flexible (±3d)": also accept travelers arriving up to 3 days after
  /// [_selectedDate].
  bool _flexibleDate = false;
  String? _avatarPath;
  String _displayName = '...';

  LocationSelection? _departure = const LocationSelection(
    country: 'Nigeria',
    countryCode: 'NG',
    city: 'Lagos',
    displayLabel: 'Lagos, Nigeria',
  );
  LocationSelection? _destination;

  // Upcoming travelers for the selected route (preview list + calendar).
  /// What "Available Travelers" shows: a random 5 of the top-delivery travelers.
  List<TravelerTrip> _travelers = const [];

  /// Everything the last search returned; the picks are drawn from it.
  List<TravelerTrip> _lastResults = const [];
  Map<DateTime, int> _flightCounts = const {};
  bool _loadingTravelers = true;
  bool _travelersFailed = false;
  int _travelersRequest = 0;

  /// "Available Travelers" is re-drawn (and refreshed) this often.
  static const _travelersRefreshEvery = Duration(seconds: 15);
  Timer? _refreshTimer;
  bool _refreshingTravelers = false;
  late final Random _random = widget.random ?? Random();

  TravelerService get _travelerService =>
      widget.travelerService ?? TravelerService();

  /// The latest delivery date sent to the search (null = anytime).
  DateTime? get _searchDate => _selectedDate == null
      ? null
      : (_flexibleDate
            ? _selectedDate!.add(const Duration(days: 3))
            : _selectedDate);

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTravelers();
    // Re-read the profile when the avatar changes elsewhere (e.g. Profile).
    AvatarImage.revision.addListener(_loadProfile);
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    AvatarImage.revision.removeListener(_loadProfile);
    super.dispose();
  }

  // ── Live "Available Travelers" ─────────────────────────────────────────────
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_travelersRefreshEvery, (_) {
      if (!mounted) return;
      // Nothing to refresh while another screen is covering Home.
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _refreshTravelers();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startRefreshTimer();
        _refreshTravelers(); // catch up straight away
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _refreshTimer?.cancel(); // no network work while in the background
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// A quiet refresh: no spinner, and a failure keeps what is on screen (the
  /// previous results are simply re-drawn so the list still rotates).
  Future<void> _refreshTravelers() async {
    if (_refreshingTravelers) return;
    _refreshingTravelers = true;
    final request = ++_travelersRequest;
    try {
      final results = await _travelerService.search(
        departureCountry: _departure?.countryCode,
        departureCity: _departure?.city,
        arrivalCountry: _destination?.countryCode,
        arrivalCity: _destination?.city,
        limit: 100,
      );
      if (!mounted || request != _travelersRequest) return;
      _applyTravelerResults(results);
    } catch (_) {
      if (!mounted || request != _travelersRequest) return;
      if (_lastResults.isNotEmpty) {
        setState(() => _travelers = pickTopTravelers(_lastResults, _random));
      }
    } finally {
      _refreshingTravelers = false;
    }
  }

  void _applyTravelerResults(List<TravelerTrip> results) {
    final counts = <DateTime, int>{};
    for (final t in results) {
      final day = DateTime(
        t.arrivalDate.year,
        t.arrivalDate.month,
        t.arrivalDate.day,
      );
      counts[day] = (counts[day] ?? 0) + 1;
    }
    setState(() {
      _lastResults = results;
      _travelers = pickTopTravelers(results, _random);
      _flightCounts = counts;
      _loadingTravelers = false;
      _travelersFailed = false;
    });
  }

  Future<void> _loadProfile() async {
    final auth = widget.authService ?? AuthService();
    final profile = await auth.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _avatarPath = profile['avatar_path'];
        final first = profile['first_name'] ?? '';
        final last = profile['last_name'] ?? '';
        if (first.isNotEmpty || last.isNotEmpty) {
          _displayName = '$first $last'.trim();
        }
      });
    }
  }

  /// Loads upcoming travelers for the selected route. A random 5 of the
  /// top-delivery travelers feed the "Available Travelers" list; all of them
  /// feed the calendar's per-day counts (by arrival date, which is what the
  /// search filters on).
  Future<void> _loadTravelers() async {
    final request = ++_travelersRequest;
    try {
      final results = await _travelerService.search(
        departureCountry: _departure?.countryCode,
        departureCity: _departure?.city,
        arrivalCountry: _destination?.countryCode,
        arrivalCity: _destination?.city,
        limit: 100,
      );
      if (!mounted || request != _travelersRequest) return;
      _applyTravelerResults(results);
    } catch (_) {
      if (!mounted || request != _travelersRequest) return;
      setState(() {
        _travelers = const [];
        _lastResults = const [];
        _flightCounts = const {};
        _loadingTravelers = false;
        _travelersFailed = true;
      });
    }
  }

  void _reloadTravelers() {
    setState(() {
      _loadingTravelers = true;
      _travelersFailed = false;
    });
    _loadTravelers();
  }

  Future<void> _pickDeparture() async {
    final result = await LocationSearchSheet.show(
      context,
      title: 'Departing From',
      initial: _departure,
    );
    if (result != null) {
      setState(() => _departure = result);
      _reloadTravelers();
    }
  }

  Future<void> _pickDestination() async {
    final result = await LocationSearchSheet.show(
      context,
      title: 'Destination',
      initial: _destination,
    );
    if (result != null) {
      setState(() => _destination = result);
      _reloadTravelers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildSearchCard(),
                        const SizedBox(height: 24),
                        _buildAddTripButton(l),
                        const SizedBox(height: 24),
                        _buildTravelersSection(),
                        const SizedBox(height: 16),
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
              child: AppBottomNav(current: 0, onReturn: _loadProfile),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _avatarPath != null
                  ? AvatarImage(
                      path: _avatarPath,
                      fallback: Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    )
                  : Image.network(
                      'https://lh3.googleusercontent.com/a/ACg8ocJ97aGjnJ1qNWsqUS-lOIkKvwls8WK-SI54YY8POZz7eBd4JRE=s96-c',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 24,
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
                Text(
                  'Hello,',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  _displayName,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            key: const ValueKey('home-notifications'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    NotificationsScreen(service: widget.notificationService),
              ),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppColors.foreground,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search card ────────────────────────────────────────────────────────────
  Widget _buildSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where are you sending?',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          // Departure
          GestureDetector(
            onTap: _pickDeparture,
            child: _locationRow(
              icon: Icons.location_on_outlined,
              iconColor: AppColors.mutedForeground,
              label: 'DEPARTURE',
              value: _departure?.displayLabel ?? 'Where are you sending from?',
              hasValue: _departure != null,
            ),
          ),
          const SizedBox(height: 10),
          // Destination
          GestureDetector(
            onTap: _pickDestination,
            child: _locationRow(
              icon: Icons.location_on,
              iconColor: AppColors.accent,
              label: 'DESTINATION',
              value:
                  _destination?.displayLabel ?? 'e.g. London, United Kingdom',
              hasValue: _destination != null,
            ),
          ),
          const SizedBox(height: 10),
          // Date
          GestureDetector(
            onTap: () => _showDateSheet(context),
            child: _locationRow(
              icon: Icons.calendar_today_outlined,
              iconColor: AppColors.mutedForeground,
              label: 'DELIVERY DATE',
              value: _selectedDate != null
                  ? '${_fmtDate(_selectedDate!)}${_flexibleDate ? ' (±3d)' : ''}'
                  : 'Anytime this month',
              hasValue: _selectedDate != null,
            ),
          ),
          const SizedBox(height: 14),
          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TravelerResultsScreen(
                      departure: _departure,
                      destination: _destination,
                      date: _searchDate,
                      service: widget.travelerService,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                'Search Travelers',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _locationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool hasValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: hasValue
                        ? AppColors.foreground
                        : AppColors.mutedForeground.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add a Trip button ──────────────────────────────────────────────────────
  Widget _buildAddTripButton(l) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AddTripScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              size: 18,
              color: AppColors.foreground,
            ),
            const SizedBox(width: 8),
            Text(
              'Add a Trip',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Travelers section ──────────────────────────────────────────────────────
  Widget _buildTravelersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Travelers',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.foreground,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TravelerResultsScreen(
                      departure: _departure,
                      destination: _destination,
                      service: widget.travelerService,
                    ),
                  ),
                );
              },
              child: Text(
                'View all',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTravelersBody(),
      ],
    );
  }

  Widget _buildTravelersBody() {
    if (_loadingTravelers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
        ),
      );
    }
    if (_travelersFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Could not load travelers.',
                key: const ValueKey('home-travelers-error'),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            TextButton(onPressed: _reloadTravelers, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_travelers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No travelers on this route yet.',
          key: const ValueKey('home-travelers-empty'),
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }
    return Column(
      children: _travelers
          .map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TravelerRow(
                trip: t,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TravelerProfileScreen(
                      trip: t,
                      service: widget.travelerService,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── Bottom nav (5 tabs: Home, Requests, Trips, Messages, Profile) ──────────
  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _showDateSheet(BuildContext context) async {
    final result = await DatePickerSheet.show(
      context,
      title: 'Desired Delivery Date',
      initialDate: _selectedDate,
      initialFlexible: _flexibleDate,
      flightCounts: _flightCounts,
      showFilters: true,
      allowAnytime: true,
    );
    if (result == null || !mounted) return; // dismissed without confirming
    setState(() {
      _selectedDate = result.date;
      _flexibleDate = result.date != null && result.flexible;
    });
  }

  String _fmtDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month]} ${d.day}';
  }
}

// ── Traveler row ───────────────────────────────────────────────────────────
class _TravelerRow extends StatelessWidget {
  final TravelerTrip trip;
  final VoidCallback onTap;
  const _TravelerRow({required this.trip, required this.onTap});

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Amara Kalu" -> "Amara K."
  String get _shortName {
    final last = trip.lastName.trim();
    return last.isEmpty
        ? trip.firstName
        : '${trip.firstName} ${last[0].toUpperCase()}.';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: AvatarImage(
                  path: trip.avatarPath,
                  fallback: Container(
                    color: AppColors.secondary,
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 22,
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
                      Flexible(
                        child: Text(
                          _shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.departureCity} → ${trip.arrivalCity}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: Color(0xFFE5A83B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        trip.avgRating?.toStringAsFixed(1) ?? 'New',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        '  •  ${trip.itemsDelivered} deliveries',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
                    '${_months[trip.departureDate.month]} ${trip.departureDate.day}',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trip.maxWeightKg == null
                      ? ''
                      : 'Up to ${trip.maxWeightKg!.toStringAsFixed(1)} kg',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
