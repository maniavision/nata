import 'dart:async';
import '../widgets/nata_logo.dart';
import 'sign_up_screen.dart';
import 'login_screen.dart';
import '../services/verify_gate.dart';
import '../services/app_badge.dart';
import '../services/auth_gate.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../widgets/app_bottom_nav.dart';
import '../l10n/l10n_ext.dart';
import '../services/home_search_memory.dart';
import '../services/screen_cache.dart';
import '../services/auth_service.dart';
import '../services/city_service.dart';
import '../services/country_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../services/traveler_ranking.dart';
import '../services/traveler_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/coach_tips.dart';
import '../widgets/home_reminders.dart';
import '../services/route_alert_service.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/location_search_sheet.dart';
import 'add_trip_screen.dart';
import 'notifications_screen.dart';
import 'traveler_profile_screen.dart';
import 'traveler_results_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'trips_screen.dart';

/// The capital of a country (by ISO code) as a departure, or null.
typedef CapitalLookup = Future<LocationSelection?> Function(String countryCode);

class HomeScreen extends StatefulWidget {
  /// Optional overrides (used by tests); default to the real services.
  final AuthService? authService;
  final TravelerService? travelerService;
  final NotificationService? notificationService;
  final RouteAlertService? routeAlertService;

  /// Source of randomness for the "Available Travelers" picks (tests pass a
  /// seeded one).
  final Random? random;

  /// Finds the default departure (the capital of the user's country); tests
  /// replace it.
  final CapitalLookup? capitalLookup;

  const HomeScreen({
    super.key,
    this.authService,
    this.travelerService,
    this.notificationService,
    this.routeAlertService,
    this.random,
    this.capitalLookup,
  });

  /// The capital in nata.cities (is_capital), named like the location sheet
  /// names its picks ("Abuja, Nigeria").
  /// What Home loads in the background for the other tabs (each fills
  /// [ScreenCache]). Replaced in tests.
  static List<Future<void> Function()> tabPreloads = [
    RequestsScreen.preload,
    TripsScreen.preload,
    MessagesScreen.preload,
    ProfileScreen.preload,
  ];

  static Future<LocationSelection?> defaultCapitalLookup(
    String countryCode,
  ) async {
    final iso = countryCode.trim().toUpperCase();
    final capital = await CityService().capitalOf(iso);
    if (capital == null) return null;
    final country = (await CountryService().byIsoCode(iso))?.name ?? iso;
    return LocationSelection(
      country: country,
      countryCode: iso,
      city: capital.name,
      displayLabel: '${capital.name}, $country',
      cityId: capital.id,
    );
  }

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

  /// Starts on the capital of the user's country of residence (see
  /// [_loadDefaultDeparture]); null until then, or if it isn't known.
  LocationSelection? _departure;
  LocationSelection? _destination;

  // Upcoming travelers for the selected route (preview list + calendar).
  /// What "Available Travelers" shows: a random 5 of the top-delivery travelers.
  List<TravelerTrip> _travelers = const [];

  /// Everything the last search returned; the picks are drawn from it.
  List<TravelerTrip> _lastResults = const [];
  Map<DateTime, int> _flightCounts = const {};

  /// For the "Get started" reminders (null until the profile loads).
  String? _verificationStatus;
  String? _userId;

  /// What the first-visit tips point at.
  final _addTripKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _bellKey = GlobalKey();
  final _navKey = GlobalKey();

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

  /// Where Home keeps its header and last travelers between visits.
  static const _kHeader = 'home.header';
  static const _kTravelers = 'home.travelers';

  /// The route the travelers were searched for.
  String get _routeKey => [
    _departure?.countryCode,
    _departure?.city,
    _destination?.countryCode,
    _destination?.city,
  ].join('|');

  /// The other tabs load in the background once Home is up, so opening
  /// them shows their content straight away (see [ScreenCache]).
  void _preloadTabs() {
    if (!AuthGate.isSignedIn()) return;
    for (final preload in HomeScreen.tabPreloads) {
      Future(preload).catchError((Object e) {
        debugPrint('[Home] preload: $e');
      });
    }
  }

  /// Puts the search back as the user left it (see [HomeSearchMemory]).
  void _restoreSearch() {
    _departure = HomeSearchMemory.departure;
    _destination = HomeSearchMemory.destination;
    _selectedDate = HomeSearchMemory.dateFrom(DateTime.now());
    _flexibleDate = _selectedDate != null && HomeSearchMemory.flexible;
  }

  void _rememberSearch() {
    HomeSearchMemory.departure = _departure;
    HomeSearchMemory.destination = _destination;
    HomeSearchMemory.date = _selectedDate;
    HomeSearchMemory.flexible = _flexibleDate;
  }

  @override
  void initState() {
    super.initState();
    _restoreSearch();
    // What Home showed last time, straight away; then the latest.
    final header = ScreenCache.read<Map<String, Object?>>(_kHeader);
    if (header != null) {
      _avatarPath = header['avatarPath'] as String?;
      _displayName = header['displayName'] as String? ?? _displayName;
      _verificationStatus = header['verificationStatus'] as String?;
      _userId = header['userId'] as String?;
    }
    final travelers = ScreenCache.read<(String, List<TravelerTrip>)>(
      _kTravelers,
    );
    if (travelers != null && travelers.$1 == _routeKey) {
      _lastResults = travelers.$2;
      _travelers = pickTopTravelers(travelers.$2, _random);
      _flightCounts = _countByDay(travelers.$2);
      _loadingTravelers = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadTabs());
    _loadProfile();
    // Travelers are searched from the default departure, so find it first.
    _loadDefaultDeparture().whenComplete(() {
      if (mounted) _loadTravelers();
    });
    // Re-read the profile when the avatar changes elsewhere (e.g. Profile).
    AvatarImage.revision.addListener(_loadProfile);
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
    // The bell's unread count (also the app icon's).
    unawaited(AppBadge.refresh());
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

  /// Upcoming travelers on the chosen route. A visitor who hasn't picked a
  /// destination and has nobody leaving from their city sees the next
  /// travelers from anywhere instead of an empty preview.
  Future<List<TravelerTrip>> _searchTravelers() async {
    final results = await _travelerService.search(
      departureCountry: _departure?.countryCode,
      departureCity: _departure?.city,
      arrivalCountry: _destination?.countryCode,
      arrivalCity: _destination?.city,
      limit: 100,
    );
    if (results.isNotEmpty || _destination != null || AuthGate.isSignedIn()) {
      return results;
    }
    return _travelerService.search(limit: 100);
  }

  /// A quiet refresh: no spinner, and a failure keeps what is on screen (the
  /// previous results are simply re-drawn so the list still rotates).
  Future<void> _refreshTravelers() async {
    if (_refreshingTravelers) return;
    _refreshingTravelers = true;
    final request = ++_travelersRequest;
    try {
      final results = await _searchTravelers();
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

  /// Travelers per arrival day, for the calendar.
  static Map<DateTime, int> _countByDay(List<TravelerTrip> results) {
    final counts = <DateTime, int>{};
    for (final t in results) {
      final day = DateTime(
        t.arrivalDate.year,
        t.arrivalDate.month,
        t.arrivalDate.day,
      );
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  void _applyTravelerResults(List<TravelerTrip> results) {
    final counts = _countByDay(results);
    ScreenCache.write(_kTravelers, (_routeKey, results));
    setState(() {
      _lastResults = results;
      _travelers = pickTopTravelers(results, _random);
      _flightCounts = counts;
      _loadingTravelers = false;
      _travelersFailed = false;
    });
  }

  /// The departure the search starts from: the capital of the country of
  /// residence saved at sign-up, or, for accounts made before that was saved,
  /// of the country remembered on this device.
  Future<void> _loadDefaultDeparture() async {
    try {
      final profile = await (widget.authService ?? AuthService()).getProfile();
      final saved = (profile?['country_of_residence'] as String?)?.trim();
      final country = saved != null && saved.isNotEmpty
          ? saved
          : PreferencesService().countryIsoCode;
      final capital =
          await (widget.capitalLookup ?? HomeScreen.defaultCapitalLookup)(
            country,
          );
      // Keep a departure the user picked while this was loading.
      if (capital != null && mounted && _departure == null) {
        setState(() => _departure = capital);
        _rememberSearch();
      }
    } catch (e) {
      debugPrint('[Home] default departure: $e');
    }
  }

  Future<void> _loadProfile() async {
    final auth = widget.authService ?? AuthService();
    final profile = await auth.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _avatarPath = profile['avatar_path'];
        _verificationStatus = profile['verification_status'] as String?;
        _userId = profile['id'] as String?;
        final first = profile['first_name'] ?? '';
        final last = profile['last_name'] ?? '';
        if (first.isNotEmpty || last.isNotEmpty) {
          _displayName = '$first $last'.trim();
        }
      });
      ScreenCache.write(_kHeader, {
        'avatarPath': _avatarPath,
        'displayName': _displayName,
        'verificationStatus': _verificationStatus,
        'userId': _userId,
      });
      _showTips();
    }
  }

  /// The first time a member opens Home: what the main parts are for (once
  /// they've ended them, this does nothing).
  void _showTips() {
    if (!AuthGate.isSignedIn()) return;
    final l = context.l10n;
    CoachTips.showWhenSettled(
      context,
      name: 'home',
      tips: () => [
        CoachTip(
          target: _addTripKey,
          icon: Icons.flight_takeoff_rounded,
          title: l.tipAddTripTitle,
          body: l.tipAddTripBody,
        ),
        CoachTip(
          target: _searchKey,
          icon: Icons.search_rounded,
          title: l.tipSearchTitle,
          body: l.tipSearchBody,
        ),
        CoachTip(
          target: _bellKey,
          icon: Icons.notifications_outlined,
          title: l.tipBellTitle,
          body: l.tipBellBody,
        ),
        CoachTip(
          target: _navKey,
          icon: Icons.grid_view_rounded,
          title: l.tipNavTitle,
          body: l.tipNavBody,
        ),
      ],
    );
  }

  /// Loads upcoming travelers for the selected route. A random 5 of the
  /// top-delivery travelers feed the "Available Travelers" list; all of them
  /// feed the calendar's per-day counts (by arrival date, which is what the
  /// search filters on).
  Future<void> _loadTravelers() async {
    final request = ++_travelersRequest;
    try {
      final results = await _searchTravelers();
      if (!mounted || request != _travelersRequest) return;
      _applyTravelerResults(results);
    } catch (_) {
      if (!mounted || request != _travelersRequest) return;
      // Travelers already on screen (from last time) stay.
      if (_lastResults.isNotEmpty && !_loadingTravelers) return;
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
      title: context.l10n.departingFrom,
      initial: _departure,
    );
    if (result != null) {
      setState(() => _departure = result);
      _rememberSearch();
      _reloadTravelers();
    }
  }

  Future<void> _pickDestination() async {
    final result = await LocationSearchSheet.show(
      context,
      title: context.l10n.destination,
      initial: _destination,
    );
    if (result != null) {
      setState(() => _destination = result);
      _rememberSearch();
      _reloadTravelers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Visitors who aren't signed in get their own Home: what Nata is, the
    // search, a preview of travelers and how it works.
    final guest = !AuthGate.isSignedIn();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          // Fill the screen so the bottom nav sits at the bottom even when
          // the content is shorter than the screen.
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  guest ? _buildGuestHeader() : _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: guest
                          ? [
                              const SizedBox(height: 8),
                              _buildGuestHero(),
                              const SizedBox(height: 24),
                              _buildSearchCard(),
                              const SizedBox(height: 24),
                              _buildTravelersSection(),
                              const SizedBox(height: 24),
                              _buildHowItWorks(),
                              const SizedBox(height: 16),
                            ]
                          : [
                              const SizedBox(height: 8),
                              HomeReminders(
                                verificationStatus: _verificationStatus,
                                userId: _userId,
                                onChanged: _loadProfile,
                                routeService: widget.routeAlertService,
                              ),
                              KeyedSubtree(
                                key: _searchKey,
                                child: _buildSearchCard(),
                              ),
                              const SizedBox(height: 24),
                              KeyedSubtree(
                                key: _addTripKey,
                                child: _buildAddTripButton(l),
                              ),
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
              child: KeyedSubtree(
                key: _navKey,
                child: AppBottomNav(current: 0, onReturn: _loadProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  /// The photo, "Hello," and the name open Profile, as the Profile tab does.
  Future<void> _openProfile() async {
    if (!AuthGate.check(context)) return;
    await Navigator.of(context).push(
      AppBottomNav.tabRoute<void>(
        ProfileScreen(
          authService: widget.authService,
          travelerService: widget.travelerService,
        ),
      ),
    );
    _loadProfile();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              key: const ValueKey('home-open-profile'),
              behavior: HitTestBehavior.opaque,
              onTap: _openProfile,
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
                    // No photo yet (or a visitor): a plain person icon.
                    child: ClipOval(
                      child: AvatarImage(
                        key: const ValueKey('home-avatar'),
                        path: _avatarPath,
                        fallback: Container(
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
                          context.l10n.hello,
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
                ],
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('home-notifications'),
            onTap: () {
              if (!AuthGate.check(context)) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationsScreen(service: widget.notificationService),
                ),
              );
            },
            child: ValueListenableBuilder<int>(
              key: _bellKey,
              valueListenable: AppBadge.unread,
              builder: (context, unread, bell) => Stack(
                clipBehavior: Clip.none,
                children: [
                  bell!,
                  if (unread > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: _UnreadBadge(count: unread),
                    ),
                ],
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
          ),
        ],
      ),
    );
  }

  // ── Visitors ───────────────────────────────────────────────────────────────
  Widget _buildGuestHeader() {
    final l = context.l10n;
    Widget pill(
      String label, {
      required bool filled,
      required Key key,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        key: key,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: filled
                ? AppColors.primary
                : AppColors.secondary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: filled
                  ? AppColors.primaryForeground
                  : AppColors.foreground,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          const NataLogo(size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.sendWithTrustedTravelers,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Long translations shrink the buttons a little rather than
          // overflow on narrow phones.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pill(
                    l.signIn,
                    filled: false,
                    key: const ValueKey('home-sign-in'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  pill(
                    l.signUp,
                    filled: true,
                    key: const ValueKey('home-sign-up'),
                    onTap: _openSignUp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSignUp() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));

  Widget _buildGuestHero() {
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        key: const ValueKey('home-guest-hero'),
        color: AppColors.primary,
        child: Stack(
          children: [
            // Soft coral glow in the corner.
            Positioned(
              right: -32,
              top: -32,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 48,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 12,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.guestHeroBadge.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.8,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.guestHeroTitle,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.guestHeroBody,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.primaryForeground.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const ValueKey('home-create-account'),
                      onPressed: _openSignUp,
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(
                        l.createFreeAccount,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.accentForeground,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildHowItWorks() {
    final l = context.l10n;
    Widget step(int n, String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.primaryForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$title ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    TextSpan(text: body),
                  ],
                ),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      key: const ValueKey('home-how-it-works'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.howItWorks,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          step(1, l.howStep1Title, l.howStep1Body),
          step(2, l.howStep2Title, l.howStep2Body),
          step(3, l.howStep3Title, l.howStep3Body),
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
            context.l10n.whereAreYouSending,
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
              label: context.l10n.departure.toUpperCase(),
              value: _departure?.displayLabel ?? context.l10n.whereSendingFrom,
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
              label: context.l10n.destination.toUpperCase(),
              value:
                  _destination?.displayLabel ?? context.l10n.destinationExample,
              hasValue: _destination != null,
            ),
          ),
          const SizedBox(height: 10),
          // Date
          GestureDetector(
            key: const ValueKey('home-date-field'),
            onTap: () => _showDateSheet(context),
            child: _locationRow(
              icon: Icons.calendar_today_outlined,
              iconColor: AppColors.mutedForeground,
              label: context.l10n.deliveryDate,
              value: _selectedDate != null
                  ? '${_fmtDate(_selectedDate!)}${_flexibleDate ? ' ${context.l10n.flexibleShort}' : ''}'
                  : context.l10n.anytimeThisMonth,
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
                context.l10n.searchTravelersButton,
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
      onTap: () async {
        if (!AuthGate.check(
          context,
          message: context.l10n.signInPromptAddTrip,
          next: (_) => const AddTripScreen(),
        )) {
          return;
        }
        final navigator = Navigator.of(context);
        if (!await VerifyGate.check(
          context,
          message: context.l10n.verifyToAddTrip,
        )) {
          return;
        }
        navigator.push(
          MaterialPageRoute(builder: (context) => const AddTripScreen()),
        );
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
              context.l10n.addATripTitle,
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
    final guest = !AuthGate.isSignedIn();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Long translations wrap instead of pushing the right side out.
            Flexible(
              child: Text(
                guest
                    ? context.l10n.travelersGoingSoon
                    : context.l10n.availableTravelers,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (guest)
              Row(
                key: const ValueKey('home-preview-label'),
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 12,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.preview,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              )
            else
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
                  context.l10n.viewAll,
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
                context.l10n.errLoadTravelers,
                key: const ValueKey('home-travelers-error'),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            TextButton(
              onPressed: _reloadTravelers,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_travelers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.l10n.noTravelersOnRoute,
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
                onTap: () {
                  Widget profile(BuildContext context) => TravelerProfileScreen(
                    trip: t,
                    service: widget.travelerService,
                  );
                  if (!AuthGate.check(
                    context,
                    message: context.l10n.signInPromptTraveler(t.firstName),
                    next: profile,
                  )) {
                    return;
                  }
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: profile));
                },
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
      title: context.l10n.desiredDeliveryDateTitle,
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
    _rememberSearch();
  }

  /// "Mon, Jun 22", in the app's language.
  String _fmtDate(DateTime d) => DateFormat(
    'EEE, MMM d',
    Localizations.localeOf(context).toString(),
  ).format(d);
}

// ── Traveler row ───────────────────────────────────────────────────────────
class _TravelerRow extends StatelessWidget {
  final TravelerTrip trip;
  final VoidCallback onTap;
  const _TravelerRow({required this.trip, required this.onTap});

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
                        trip.avgRating?.toStringAsFixed(1) ??
                            context.l10n.newTravelerRating,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: AppColors.foreground,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '  •  ${context.l10n.deliveriesCount(trip.itemsDelivered)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
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
                    DateFormat.MMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(trip.departureDate),
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
                      : context.l10n.upToKg(
                          trip.maxWeightKg!.toStringAsFixed(1),
                        ),
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

/// The unread count on Home's bell: a coral badge, "9+" above 9.
class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home-notifications-unread'),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: GoogleFonts.dmSans(
          fontSize: 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: AppColors.accentForeground,
        ),
      ),
    );
  }
}
