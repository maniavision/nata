import 'dart:async';
import '../services/payment_service.dart';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../widgets/avatar_image.dart';
import '../services/emergency_contact_service.dart';
import '../services/traveler_service.dart';
import 'identity_status_screen.dart';
import 'identity_verification_screen.dart';
import 'sealed_box_policy_screen.dart';
import 'support_screens.dart';
import '../services/support_service.dart';
import 'wallet_history_screen.dart';
import 'payment_settings_screen.dart';
import 'login_screen.dart';
import '../l10n/l10n_ext.dart';
import '../widgets/one_line_text.dart';
import 'route_alerts_screen.dart';

class ProfileScreen extends StatefulWidget {
  /// Override for tests; defaults to the real [AuthService].
  final AuthService? authService;

  /// Overrides for tests; they default to the real services.
  final EmergencyContactService? emergencyService;
  final TravelerService? travelerService;

  const ProfileScreen({
    super.key,
    this.authService,
    this.emergencyService,
    this.travelerService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthService get _auth => widget.authService ?? AuthService();

  String? _imagePath;
  String? _avatarPath;
  String _displayName = '...';
  String _memberSinceDate = '...';
  String _verificationStatus = 'unverified'; // unverified, pending, verified
  double _availableBalance = 0.0;
  double _escrowBalance = 0.0;
  int _tripsCount = 0;
  int _parcelsCount = 0;
  double? _avgRating;
  int? _reviewCount;
  EmergencyContact? _emergencyContact;
  bool _isUploading = false;

  /// Staff see a Support row at the top of the settings.
  bool _isAdmin = false;
  bool _isLoading = true;

  StreamSubscription? _profileSubscription;
  StreamSubscription? _walletSubscription;
  StreamSubscription? _statsSubscription;

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PreferencesService().addListener(_onPrefsChanged);
    _loadProfile();
    _setupStreams();
    _loadEmergencyContact();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    try {
      final admin = await SupportAccess.isAdmin();
      if (mounted && admin != _isAdmin) setState(() => _isAdmin = admin);
    } catch (e) {
      debugPrint('[Profile] admin check: $e');
    }
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final contact =
          await (widget.emergencyService ?? EmergencyContactService()).get();
      if (mounted) setState(() => _emergencyContact = contact);
    } catch (e) {
      debugPrint('[Profile] emergency contact error: $e');
    }
  }

  /// How many reviews the user has, next to their average rating.
  Future<void> _loadReviewCount(String userId) async {
    try {
      final reviews = await (widget.travelerService ?? TravelerService())
          .reviews(userId, limit: 1);
      if (mounted) setState(() => _reviewCount = reviews.total);
    } catch (e) {
      debugPrint('[Profile] review count error: $e');
    }
  }

  void _setupStreams() {
    final auth = _auth;

    _profileSubscription = auth.profileStream().listen((profile) {
      if (profile != null && mounted) {
        setState(() {
          _avatarPath = profile['avatar_path'];
          final first = profile['first_name'] ?? '';
          final last = profile['last_name'] ?? '';
          if (first.isNotEmpty || last.isNotEmpty) {
            _displayName = '$first $last'.trim();
          }

          final createdAt = profile['created_at'];
          if (createdAt != null) {
            final date = DateTime.parse(createdAt);
            _memberSinceDate = DateFormat('MMM yyyy').format(date);
          }
          _verificationStatus = profile['verification_status'] ?? 'unverified';
          _avgRating = (profile['avg_rating'] as num?)?.toDouble();
        });
      }
    }, onError: (Object e) => debugPrint('[Profile] profile stream error: $e'));

    _walletSubscription = auth.walletBalancesStream().listen((balances) {
      if (mounted) {
        setState(() {
          _availableBalance = balances['available'] ?? 0.0;
          _escrowBalance = balances['escrow'] ?? 0.0;
        });
      }
    }, onError: (Object e) => debugPrint('[Profile] wallet stream error: $e'));

    _statsSubscription = auth.statsStream().listen((stats) {
      if (mounted) {
        setState(() {
          _tripsCount = stats['trips'] ?? 0;
          _parcelsCount = stats['parcels'] ?? 0;
        });
      }
    }, onError: (Object e) => debugPrint('[Profile] stats stream error: $e'));
  }

  Future<void> _loadProfile() async {
    try {
      final auth = _auth;
      final profile = await auth.getProfile();
      final balances = await auth.getWalletBalances();
      final stats = await auth.getStats();

      if (profile != null && mounted) {
        setState(() {
          _avatarPath = profile['avatar_path'];
          final first = profile['first_name'] ?? '';
          final last = profile['last_name'] ?? '';
          if (first.isNotEmpty || last.isNotEmpty) {
            _displayName = '$first $last'.trim();
          }

          // Format member since date
          final createdAt = profile['created_at'];
          if (createdAt != null) {
            final date = DateTime.parse(createdAt);
            _memberSinceDate = DateFormat('MMM yyyy').format(date);
          }

          _verificationStatus = profile['verification_status'] ?? 'unverified';
          _avgRating = (profile['avg_rating'] as num?)?.toDouble();

          _availableBalance = balances['available'] ?? 0.0;
          _escrowBalance = balances['escrow'] ?? 0.0;

          _tripsCount = stats['trips'] ?? 0;
          _parcelsCount = stats['parcels'] ?? 0;

          _isLoading = false;
        });
        final id = profile['id'] as String?;
        if (id != null && _avgRating != null) _loadReviewCount(id);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    PreferencesService().removeListener(_onPrefsChanged);
    _profileSubscription?.cancel();
    _walletSubscription?.cancel();
    _statsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Optimize for web/mobile upload
      maxWidth: 512, // Avatars are shown small; keep upload + decode cheap
      maxHeight: 512,
    );

    if (image != null) {
      setState(() {
        _imagePath = image.path;
        _isUploading = true;
      });

      try {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last;

        final oldAvatarPath = _avatarPath;

        // 1. Upload to Storage (unique file name per upload)
        final avatarPath = await _auth.uploadAvatar(bytes, extension);

        // 2. Update Profile in DB
        await _auth.updateProfile(avatarPath: avatarPath);

        // Seed the cache with the bytes we just uploaded so the new picture
        // appears instantly on every screen, drop the previous picture from
        // the caches, and refresh every mounted avatar. Done after the DB
        // update so screens that reload the profile pick up the new path.
        await AvatarImage.replace(
          avatarPath,
          bytes,
          extension: extension,
          oldPath: oldAvatarPath,
        );

        // Clean up the previous file in storage (best effort).
        unawaited(_auth.deleteAvatar(oldAvatarPath));

        // 3. Refresh profile state
        await _loadProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.profilePictureUpdated)),
          );
        }
      } catch (e) {
        debugPrint('Upload error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.errUploadImage('$e'))),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LanguagePickerSheet(),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CurrencyPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        _buildWalletCard(),
                        const SizedBox(height: 16),
                        _buildSettingsList(),
                        const SizedBox(height: 16),
                        _buildLogoutButton(),
                        const SizedBox(height: 8),
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
              child: const AppBottomNav(current: 4),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Text(
            context.l10n.accountAndProfile,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: -0.4,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile card ───────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final bool isVerified = _verificationStatus == 'verified';
    final bool isPending = _verificationStatus == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with verified badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isVerified
                            ? AppColors.accent
                            : (isPending ? Colors.orange : AppColors.border),
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipOval(
                          child: _imagePath != null
                              ? Image.file(
                                  File(_imagePath!),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                )
                              : _avatarPath != null
                              ? SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: AvatarImage(
                                    path: _avatarPath,
                                    fallback: Container(
                                      color: AppColors.secondary,
                                      child: const Icon(
                                        Icons.person,
                                        size: 36,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.secondary,
                                  child: const Icon(
                                    Icons.person,
                                    size: 36,
                                    color: AppColors.primary,
                                  ),
                                ),
                        ),
                        if (_isUploading)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (isVerified || isPending)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFF168A68)
                              : Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.card, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isVerified
                              ? Icons.verified_rounded
                              : Icons.pending_actions_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.memberSince(_memberSinceDate),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? const Color(0xFFE4F4EE)
                                  : (isPending
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : AppColors.input),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVerified
                                      ? Icons.shield_rounded
                                      : (isPending
                                            ? Icons.pending_rounded
                                            : Icons.shield_outlined),
                                  size: 12,
                                  color: isVerified
                                      ? const Color(0xFF168A68)
                                      : (isPending
                                            ? Colors.orange
                                            : AppColors.mutedForeground),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isVerified
                                        ? context.l10n.tier1Verified
                                              .split('·')
                                              .first
                                              .trim()
                                        : (isPending
                                              ? context.l10n.verificationPending
                                              : context
                                                    .l10n
                                                    .verificationUnverified),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      color: isVerified
                                          ? const Color(0xFF168A68)
                                          : (isPending
                                                ? Colors.orange
                                                : AppColors.mutedForeground),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFE5A83B),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _avgRating == null
                                      ? context.l10n.noReviewsYet
                                      : '${_avgRating!.toStringAsFixed(1)} ',
                                  key: const ValueKey('profile-rating'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontWeight: _avgRating == null
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    fontSize: 12,
                                    color: _avgRating == null
                                        ? AppColors.mutedForeground
                                        : AppColors.foreground,
                                  ),
                                ),
                              ),
                              if (_avgRating != null && _reviewCount != null)
                                Text(
                                  '($_reviewCount)',
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
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          // Stats grid: both tiles the same height in every language.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _statTile(
                    context.l10n.tripsCarried,
                    context.l10n.tripsCount(_tripsCount),
                    AppColors.foreground,
                    key: 'profile-stat-trips',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statTile(
                    context.l10n.parcelsSent,
                    context.l10n.parcelsCount(_parcelsCount),
                    AppColors.accent,
                    key: 'profile-stat-parcels',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    String label,
    String value,
    Color valueColor, {
    String? key,
  }) {
    return Container(
      key: key == null ? null : ValueKey(key),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          OneLineText(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 9,
              letterSpacing: 1.2,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Sends the payouts waiting for this traveler (they also go out by
  /// themselves after each delivery).
  Future<void> _withdraw() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sent = await PaymentService().sendPayouts();
      messenger.showSnackBar(
        SnackBar(
          content: Text(sent > 0 ? l.withdrawSent(sent) : l.withdrawNothing),
        ),
      );
    } catch (e) {
      debugPrint('[Profile] withdraw: $e');
      messenger.showSnackBar(SnackBar(content: Text(l.errRequestFailed)));
    }
  }

  // ── Wallet card ────────────────────────────────────────────────────────────
  Widget _buildWalletCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      // The blob is cut by the card's rounded edge, not by its padding.
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative blob
          Positioned(
            right: -40,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Column(
            children: [
              // Top row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.natawallet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n.escrowProtected,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Balance + withdraw
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.availableForPayout,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              NumberFormat.currency(
                                symbol: '\$',
                                decimalDigits: 2,
                              ).format(_availableBalance),
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                                color: Colors.white,
                                letterSpacing: -1.0,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'USD',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: const ValueKey('wallet-withdraw'),
                    onTap: _withdraw,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        context.l10n.withdraw,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 12),
              // Escrow row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_escrowBalance)} ${context.l10n.heldInEscrow}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    key: const ValueKey('wallet-view-history'),
                    onTap: _openHistory,
                    child: Text(
                      context.l10n.viewHistory,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    final money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WalletHistoryScreen(
          available: money.format(_availableBalance),
          inEscrow: money.format(_escrowBalance),
        ),
      ),
    );
  }

  Future<void> _openEmergencyContact() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmergencyContactScreen(
          initial: _emergencyContact,
          service: widget.emergencyService,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.ecSavedToast)));
    _loadEmergencyContact();
  }

  // ── Settings list ──────────────────────────────────────────────────────────
  Widget _buildSettingsList() {
    final prefs = PreferencesService();
    final items = [
      if (_isAdmin)
        _SettingsItem(
          key: const ValueKey('profile-support'),
          icon: Icons.shield_outlined,
          iconBg: AppColors.secondary,
          iconColor: AppColors.primary,
          title: context.l10n.supportTitle,
          subtitle: context.l10n.supportRowSub,
          trailing: context.l10n.supportAdmin,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
        ),
      _SettingsItem(
        icon: Icons.language_rounded,
        iconBg: AppColors.secondary,
        iconColor: AppColors.primary,
        title: context.l10n.language,
        subtitle: 'English · Español · Français',
        trailing: prefs.language.label,
        onTap: _showLanguagePicker,
      ),
      _SettingsItem(
        icon: Icons.credit_card_rounded,
        iconBg: AppColors.secondary,
        iconColor: AppColors.primary,
        title: context.l10n.currency,
        subtitle: 'USD, EUR, GBP, XOF',
        trailing: '${prefs.currency.code} (${prefs.currency.symbol})',
        onTap: _showCurrencyPicker,
      ),
      _SettingsItem(
        key: const ValueKey('profile-route-alerts'),
        icon: Icons.notification_add_rounded,
        iconBg: AppColors.secondary,
        iconColor: AppColors.primary,
        title: context.l10n.routeAlerts,
        subtitle: context.l10n.routeAlertsSub,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RouteAlertsScreen())),
      ),
      _SettingsItem(
        icon: Icons.shield_rounded,
        iconBg: _verificationStatus == 'verified'
            ? const Color(0xFFE4F4EE)
            : (_verificationStatus == 'pending'
                  ? Colors.orange.withValues(alpha: 0.1)
                  : const Color(0xFFFEE2E2)),
        iconColor: _verificationStatus == 'verified'
            ? const Color(0xFF168A68)
            : (_verificationStatus == 'pending'
                  ? Colors.orange
                  : AppColors.destructive),
        title: context.l10n.identityVerification,
        subtitle: _verificationStatus == 'verified'
            ? context.l10n.tier1Verified
            : (_verificationStatus == 'pending'
                  ? context.l10n.identityUnderReview
                  : context.l10n.identityActionRequiredSub),
        subtitleColor: _verificationStatus == 'verified'
            ? const Color(0xFF168A68)
            : (_verificationStatus == 'pending'
                  ? Colors.orange
                  : AppColors.destructive),
        verified: _verificationStatus == 'verified',
        trailing: _verificationStatus == 'pending'
            ? context.l10n.verificationReviewing
            : null,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => _verificationStatus == 'unverified'
                  ? const IdentityVerificationScreen()
                  : IdentityStatusScreen(
                      verified: _verificationStatus == 'verified',
                    ),
            ),
          );
          // Show the new verification status right away instead of waiting
          // for the next profile poll.
          if (mounted) _loadProfile();
        },
      ),
      _SettingsItem(
        key: const ValueKey('profile-payment-settings'),
        icon: Icons.account_balance_wallet_rounded,
        iconBg: AppColors.secondary,
        iconColor: AppColors.primary,
        title: context.l10n.paymentSettings,
        subtitle: context.l10n.paymentSettingsSub,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentSettingsScreen(
              availableBalance: _availableBalance,
              escrowBalance: _escrowBalance,
              holderName: _displayName,
            ),
          ),
        ),
      ),
      _SettingsItem(
        icon: Icons.inventory_2_outlined,
        iconBg: AppColors.secondary,
        iconColor: AppColors.primary,
        title: context.l10n.sealedBoxPolicySetting,
        subtitle: context.l10n.originalBoxCompliance,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SealedBoxPolicyScreen()),
        ),
      ),
      _SettingsItem(
        key: const ValueKey('profile-emergency-contact'),
        icon: Icons.contact_emergency_rounded,
        iconBg: AppColors.secondary,
        iconColor: AppColors.primary,
        title: context.l10n.emergencyContactLabel,
        subtitle: _emergencyContact?.fullName ?? context.l10n.ecProfileAdd,
        onTap: _openEmergencyContact,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              GestureDetector(
                key: item.key,
                onTap: item.onTap,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.iconBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 18, color: item.iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              item.subtitle,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color:
                                    item.subtitleColor ??
                                    AppColors.mutedForeground,
                                fontWeight: item.subtitleColor != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.verified)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Color(0xFF168A68),
                        )
                      else if (item.trailing != null)
                        Row(
                          children: [
                            Text(
                              item.trailing!,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppColors.mutedForeground,
                            ),
                          ],
                        )
                      else
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.mutedForeground,
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(color: AppColors.border, height: 1, indent: 62),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Log out ────────────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        // Sign out from Supabase and reset in-memory preferences
        await _auth.signOut();
        PreferencesService().reset();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.destructive.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.destructive.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              size: 16,
              color: AppColors.destructive,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.logOut,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
}

// ── Data models ────────────────────────────────────────────────────────────
class _SettingsItem {
  final Key? key;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final String? trailing;
  final bool verified;
  final VoidCallback? onTap;

  const _SettingsItem({
    this.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.verified = false,
    this.onTap,
  });
}

// ── Language Picker ────────────────────────────────────────────────────────
class _LanguagePickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesService();
    final l = context.l10n;

    final options = [
      (AppLanguage.english, '🇺🇸', l.langEnglish, l.langEnglishSub),
      (AppLanguage.spanish, '🇪🇸', l.langSpanish, l.langSpanishSub),
      (AppLanguage.french, '🇫🇷', l.langFrench, l.langFrenchSub),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.splashChooseLanguage,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: AppColors.mutedForeground,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final selected = prefs.language == opt.$1;
            return GestureDetector(
              onTap: () async {
                prefs.setLanguage(opt.$1);
                await prefs.saveToProfile();
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.05)
                      : AppColors.input,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt.$2, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.$3,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.foreground,
                            ),
                          ),
                          Text(
                            opt.$4,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.accent,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ── Currency Picker ────────────────────────────────────────────────────────
class _CurrencyPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prefs = PreferencesService();
    final l = context.l10n;

    final options = [
      (AppCurrency.usd, l.currUSD),
      (AppCurrency.eur, l.currEUR),
      (AppCurrency.gbp, l.currGBP),
      (AppCurrency.xof, l.currXOF),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.splashPreferredCurrency,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: AppColors.mutedForeground,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: options.length,
            itemBuilder: (context, i) {
              final opt = options[i];
              final selected = prefs.currency == opt.$1;
              return GestureDetector(
                onTap: () async {
                  prefs.setCurrency(opt.$1);
                  await prefs.saveToProfile();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.05)
                        : AppColors.input,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${opt.$1.code} (${opt.$1.symbol})',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              opt.$2,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.accent,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
