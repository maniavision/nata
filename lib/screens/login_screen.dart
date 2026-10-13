import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/country_service.dart';
import '../services/preferences_service.dart';
import 'sign_up_screen.dart';
import 'home_screen.dart';
import 'otp_screen.dart';
import '../widgets/country_code_picker_sheet.dart';
import '../l10n/l10n_ext.dart';

class LoginScreen extends StatefulWidget {
  /// Overrides for tests; they default to the real services / Home screen.
  final AuthService? authService;
  final BiometricService? biometricService;
  final WidgetBuilder? homeBuilder;

  const LoginScreen({
    super.key,
    this.authService,
    this.biometricService,
    this.homeBuilder,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '');
  bool _rememberMe = true;
  int _selectedTab = 0;
  // Starts on the USA. If someone registered on this device the country they
  // registered with takes over (see _applyRememberedCountry).
  Country _selectedCountry = const Country(
    isoCode: 'US',
    name: 'United States',
    phoneCode: '+1',
  );
  bool _countryChosenByUser = false;
  bool _loading = false;
  bool _faceIdBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _applyRememberedCountry();
  }

  /// Uses the country the user registered with (kept on the device, also after
  /// logging out) as the default, unless they already picked one themselves.
  Future<void> _applyRememberedCountry() async {
    final iso = PreferencesService().countryIsoCode;
    if (iso == _selectedCountry.isoCode) return;
    final country = await CountryService().byIsoCode(iso);
    if (country == null || !mounted || _countryChosenByUser) return;
    setState(() => _selectedCountry = country);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }

    final normalized = phone.startsWith('0') ? phone.substring(1) : phone;
    final e164 = '${_selectedCountry.phoneCode}$normalized';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Logging in never creates an account: the number must already exist.
      await (widget.authService ?? AuthService()).sendOtp(
        e164,
        createUser: false,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phone: e164,
            isSignUp: false,
            authService: widget.authService,
            onSuccess: () {
              // Signing in with "Remember me" ticked switches Face ID on for
              // the next time; without it, Face ID stays off.
              PreferencesService().setFaceIdEnabled(_rememberMe);
              _goHome();
            },
          ),
        ),
      );
    } on AccountNotFoundException {
      if (mounted) setState(() => _error = context.l10n.errAccountNotFound);
    } on Exception catch (e) {
      setState(() {
        _error = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: widget.homeBuilder ?? (context) => const HomeScreen(),
      ),
      (route) => false,
    );
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The "Face ID" button: unlocks the session that is still kept on this
  /// device, so the user does not need another one-time code.
  ///
  /// A face cannot create an account session from nothing: the first sign-in
  /// (with "Remember me" ticked) must use the phone number. After that, Face ID
  /// takes over until the user logs out.
  Future<void> _onFaceId() async {
    if (_faceIdBusy) return;
    setState(() => _faceIdBusy = true);
    try {
      final l = context.l10n;
      final biometrics = widget.biometricService ?? BiometricService();

      // 1. Can this device do Face ID at all?
      switch (await biometrics.availability()) {
        case BiometricAvailability.unsupported:
          _say(l.faceIdUnavailable);
          return;
        case BiometricAvailability.notEnrolled:
          _say(l.faceIdNotSetUp);
          return;
        case BiometricAvailability.available:
          break;
      }

      // 2. Is there a signed-in session to unlock?
      final auth = widget.authService ?? AuthService();
      if (!auth.hasActiveSession || !PreferencesService().faceIdEnabled) {
        _say(l.faceIdSignInFirst);
        return;
      }

      // 3. Ask for the face.
      if (!mounted) return;
      switch (await biometrics.authenticate(l.faceIdReason)) {
        case BiometricResult.success:
          if (mounted) _goHome();
        case BiometricResult.cancelled:
          break; // the user closed the prompt: say nothing
        case BiometricResult.failed:
          _say(l.faceIdFailed);
        case BiometricResult.lockedOut:
          _say(l.faceIdLocked);
        case BiometricResult.notEnrolled:
          _say(l.faceIdNotSetUp);
        case BiometricResult.notAvailable:
          _say(l.faceIdUnavailable);
      }
    } finally {
      if (mounted) setState(() => _faceIdBusy = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many requests. Please wait a moment.';
    }
    if (raw.contains('invalid') || raw.contains('phone')) {
      return 'Invalid phone number. Please check and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeroSection(),
              _buildMainContent(),
              _buildFooter(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero image with overlay ────────────────────────────────────────────────
  Widget _buildHeroSection() {
    return Container(
      height: 208,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Image.network(
              'https://ggrhecslgdflloszjkwl.supabase.co/storage/v1/object/public/user-assets/zQQR13YtUCF/components/kMQg4SZXLDu.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Container(color: AppColors.primary),
            ),
          ),
          // Gradient
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withValues(alpha: 0.60),
                    AppColors.primary.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Top bar — centered brand pill only
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Center(
              child: _GlassPill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.appName,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom headline
          Positioned(
            bottom: 16,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.welcomeBack,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.welcomeBackSub,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card ───────────────────────────────────────────────────────────────────
  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 15,
                spreadRadius: -3,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                spreadRadius: -4,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabSwitcher(),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 16),
              _buildRememberMeRow(),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.destructive.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppColors.destructive,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.destructive,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _buildSignInButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab switcher ───────────────────────────────────────────────────────────
  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(children: [_tab(context.l10n.signIn, 0), _tab('Sign Up', 1)]),
    );
  }

  Widget _tab(String label, int index) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            );
          } else {
            setState(() => _selectedTab = index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: active
                ? const [
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
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
              color: active ? AppColors.foreground : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  // ── Phone field ────────────────────────────────────────────────────────────
  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context.l10n.phoneNumber.toUpperCase()),
        const SizedBox(height: 4),
        Row(
          children: [
            // Country picker
            GestureDetector(
              onTap: () => _showCountryPicker(),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.input,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      flagEmoji(_selectedCountry.isoCode),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCountry.phoneCode,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StyledTextField(
                controller: _phoneController,
                hintText: '801 234 5678',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(
                  Icons.phone_rounded,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Password field ─────────────────────────────────────────────────────────
  // ── Remember me row ────────────────────────────────────────────────────────
  Widget _buildRememberMeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  activeColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: AppColors.border),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.rememberMe,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          key: const ValueKey('login-face-id'),
          onTap: _onFaceId,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              _faceIdBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.face_retouching_natural,
                      color: AppColors.accent,
                      size: 18,
                    ),
              const SizedBox(width: 6),
              Text(
                context.l10n.faceId,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sign in button ─────────────────────────────────────────────────────────
  Widget _buildSignInButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.muted,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x33000000),
          shape: const StadiumBorder(),
        ),
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.signIn,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.newToNata + ' ',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const SignUpScreen(),
                    ),
                  );
                },
                child: Text(
                  context.l10n.createAccount,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.tagline,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.mutedForeground.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: field label ────────────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1.2,
        color: AppColors.mutedForeground,
      ),
    );
  }

  // ── Country code picker ────────────────────────────────────────────────────
  Future<void> _showCountryPicker() async {
    final country = await showCountryCodePicker(context, _selectedCountry);
    if (country == null || !mounted) return;
    setState(() {
      _selectedCountry = country;
      _countryChosenByUser = true;
    });
  }
}

// ── Glass circle button ────────────────────────────────────────────────────
class _GlassCircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassCircleButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ── Glass pill ─────────────────────────────────────────────────────────────
class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Social button ──────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  const _SocialButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Styled text field ──────────────────────────────────────────────────────
class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const _StyledTextField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        height: 16 / 12,
        color: AppColors.foreground,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.mutedForeground,
        ),
        filled: true,
        fillColor: AppColors.input,
        isDense: true,
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: prefixIcon,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.fromLTRB(14, 16, 12, 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: AppColors.ring.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
    );
  }
}

// ── Google color icon ──────────────────────────────────────────────────────
class _GoogleColorIcon extends StatelessWidget {
  const _GoogleColorIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.28
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(const Color(0xFFEA4335), -1.57, 1.57); // red: top
    arc(const Color(0xFF4285F4), -3.14, -1.57); // blue: left
    arc(const Color(0xFFFBBC05), 0.0, 1.57); // yellow: bottom-right
    arc(const Color(0xFF34A853), 1.57, 1.57); // green: bottom
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
