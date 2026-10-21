import 'dart:ui';

import '../widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/country_service.dart';
import '../services/preferences_service.dart';
import 'login_screen.dart';
import 'identity_verification_screen.dart';
import 'otp_screen.dart';
import '../l10n/l10n_ext.dart';
import '../widgets/nata_logo.dart';
import '../services/phone_number.dart';

class SignUpScreen extends StatefulWidget {
  /// Override for tests; defaults to the real [AuthService].
  final AuthService? authService;

  const SignUpScreen({super.key, this.authService});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _firstNameController = TextEditingController(text: '');
  final _lastNameController = TextEditingController(text: '');
  final _countryController = TextEditingController(text: 'United States');
  final _phoneController = TextEditingController(text: '');
  bool _loading = false;
  String? _error;

  // Country autocomplete
  // Starts on the USA. If someone registered on this device the country they
  // registered with takes over (see _applyRememberedCountry).
  Country _selectedCountry = const Country(
    isoCode: 'US',
    name: 'United States',
    phoneCode: '+1',
  );
  List<Country> _suggestions = [];
  bool _showSuggestions = false;
  final FocusNode _countryFocus = FocusNode();

  // Set while the default country is written into the field, so that does not
  // open the suggestion list; and once the user has chosen or typed a country,
  // the default must never overwrite it.
  bool _applyingDefault = false;
  bool _countryChosenByUser = false;

  @override
  void initState() {
    super.initState();
    _countryController.addListener(_onCountryChanged);
    _countryFocus.addListener(() {
      if (!_countryFocus.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
    _applyRememberedCountry();
  }

  /// Uses the country the user registered with (kept on the device, also after
  /// logging out) as the default, unless they already chose one themselves.
  Future<void> _applyRememberedCountry() async {
    final iso = PreferencesService().countryIsoCode;
    if (iso == _selectedCountry.isoCode) return;
    final country = await CountryService().byIsoCode(iso);
    if (country == null || !mounted || _countryChosenByUser) return;
    setState(() {
      _selectedCountry = country;
      _applyingDefault = true;
      _countryController.text = country.name;
      _applyingDefault = false;
      _showSuggestions = false;
    });
  }

  void _onCountryChanged() {
    if (_applyingDefault) return;
    _countryChosenByUser = true;
    final q = _countryController.text;
    CountryService().search(q).then((results) {
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty && q.isNotEmpty;
        });
      }
    });
  }

  void _selectCountry(Country country) {
    _countryChosenByUser = true;
    setState(() {
      _selectedCountry = country;
      _countryController.text = country.name;
      _showSuggestions = false;
    });
    _countryFocus.unfocus();
  }

  @override
  void dispose() {
    _countryController.removeListener(_onCountryChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _countryFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');

    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      setState(() => _error = context.l10n.errFillAllFields);
      return;
    }

    // International form, keeping the 0 where it belongs to the number
    // (Congo-Brazzaville 06... -> +242 06...) and dropping it elsewhere.
    final e164 = internationalPhoneNumber(
      dialCode: _selectedCountry.phoneCode,
      input: phone,
      isoCode: _selectedCountry.isoCode,
    )!;

    // Store selected country in PreferencesService before sending OTP
    PreferencesService().setCountry(_selectedCountry.isoCode);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await (widget.authService ?? AuthService()).sendOtp(
        e164,
        profile: {'first_name': firstName, 'last_name': lastName},
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phone: e164,
            isSignUp: true,
            authService: widget.authService,
            firstName: firstName,
            lastName: lastName,
            // The country picked for the phone number (its iso_code in
            // nata.countries) is the user's country of residence.
            countryOfResidence: _selectedCountry.isoCode,
            onSuccess: () {
              // After OTP verified → go to identity verification
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const IdentityVerificationScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );
    } on Exception catch (e) {
      setState(() {
        _error = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return context.l10n.errTooManyRequestsRetry;
    }
    if (raw.contains('invalid') || raw.contains('phone')) {
      return context.l10n.errInvalidPhone;
    }
    return context.l10n.errSomethingWrong;
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      // Same instant switch as the bottom tabs, not a page slide.
      AppBottomNav.tabRoute<void>(const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildHero(),
                  _buildCard(),
                  _buildFooter(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            // Opened while browsing: a way back.
            if (Navigator.of(context).canPop())
              Positioned(
                top: 12,
                left: 16,
                child: Semantics(
                  button: true,
                  label: context.l10n.continueBrowsing,
                  child: GestureDetector(
                    key: const ValueKey('auth-close'),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────
  Widget _buildHero() {
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
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Image.network(
              'https://ggrhecslgdflloszjkwl.supabase.co/storage/v1/object/public/user-assets/zQQR13YtUCF/components/vkAWPqCOiMQ.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Container(color: AppColors.primary),
            ),
          ),
          // Gradient overlay
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
                    const NataLogo(size: 24),
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
                  context.l10n.createYourAccount,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.createYourAccountSub,
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
  Widget _buildCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
              _buildForm(),
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
      child: Row(
        children: [
          // Sign In — inactive
          Expanded(
            child: GestureDetector(
              onTap: _goToLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  context.l10n.signIn,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
          // Sign Up — active
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
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
              child: Text(
                context.l10n.signUp,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Social buttons ─────────────────────────────────────────────────────────
  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            label: context.l10n.apple,
            icon: const Icon(
              Icons.apple,
              size: 18,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SocialButton(
            label: context.l10n.google,
            icon: const _GoogleColorIcon(),
          ),
        ),
      ],
    );
  }

  // ── Divider ────────────────────────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.border, thickness: 1, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            context.l10n.orSignUpManually.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1.4,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.border, thickness: 1, height: 1),
        ),
      ],
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // First name + Last name row
        Row(
          children: [
            Expanded(
              child: _buildField(
                label: context.l10n.firstName.toUpperCase(),
                child: _SimpleTextField(
                  controller: _firstNameController,
                  hintText: 'John',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildField(
                label: context.l10n.lastName.toUpperCase(),
                child: _SimpleTextField(
                  controller: _lastNameController,
                  hintText: 'Doe',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Country of Residence — autocomplete
        _buildField(
          label: context.l10n.countryOfResidenceLabel,
          child: _CountryField(
            controller: _countryController,
            focusNode: _countryFocus,
            selectedCountry: _selectedCountry,
            suggestions: _suggestions,
            showSuggestions: _showSuggestions,
            onSelected: _selectCountry,
          ),
        ),
        const SizedBox(height: 12),
        // Phone — prefix updates with selected country
        _buildField(
          label: context.l10n.phoneNumber.toUpperCase(),
          child: Row(
            children: [
              // Country prefix pill (updates when country selected)
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _flagEmoji(_selectedCountry.isoCode),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedCountry.phoneCode,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SimpleTextField(
                  controller: _phoneController,
                  hintText: '801 234 5678',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ID verification notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6EE),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.shield, size: 17, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.mandatoryIdTitle,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.375,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.mandatoryIdBody,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                        height: 1.375,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Error banner
        if (_error != null) ...[
          const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        // Submit button
        SizedBox(
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
                      Flexible(
                        child: Text(
                          context.l10n.createAccountButton,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
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
        ),
      ],
    );
  }

  // ── Field wrapper with label ───────────────────────────────────────────────
  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.2,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
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
                context.l10n.alreadyHaveAccount + ' ',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              GestureDetector(
                onTap: _goToLogin,
                child: Text(
                  context.l10n.signInHere,
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
}

// ── Flag emoji helper ──────────────────────────────────────────────────────
String _flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '🌍';
  final base = 0x1F1E6;
  final first = isoCode.codeUnitAt(0) - 0x41;
  final second = isoCode.codeUnitAt(1) - 0x41;
  return String.fromCharCodes([base + first, base + second]);
}

// ── Country autocomplete field ─────────────────────────────────────────────
class _CountryField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Country selectedCountry;
  final List<Country> suggestions;
  final bool showSuggestions;
  final ValueChanged<Country> onSelected;

  const _CountryField({
    required this.controller,
    required this.focusNode,
    required this.selectedCountry,
    required this.suggestions,
    required this.showSuggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input row
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.input,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: focusNode.hasFocus
                  ? AppColors.ring.withValues(alpha: 0.4)
                  : AppColors.border,
              width: focusNode.hasFocus ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(
                Icons.language_rounded,
                size: 16,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.selectCountry,
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Flag of currently selected country
              Text(
                _flagEmoji(selectedCountry.isoCode),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        // Suggestions dropdown
        if (showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: suggestions.asMap().entries.map((e) {
                  final country = e.value;
                  final isLast = e.key == suggestions.length - 1;
                  return GestureDetector(
                    onTap: () => onSelected(country),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        border: isLast
                            ? null
                            : const Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _flagEmoji(country.isoCode),
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              country.name,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                          Text(
                            country.phoneCode,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Simple text field (no prefix icon) ────────────────────────────────────
class _SimpleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  const _SimpleTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
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

// ── Icon text field (with prefix / suffix icons) ───────────────────────────
class _IconTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const _IconTextField({
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
                padding: const EdgeInsets.only(left: 14, right: 8),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.ring, width: 2),
        ),
      ),
    );
  }
}

// ── Shared glass widgets ───────────────────────────────────────────────────
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
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.28
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(const Color(0xFFEA4335), -1.57, 1.57);
    arc(const Color(0xFF4285F4), -3.14, -1.57);
    arc(const Color(0xFFFBBC05), 0.0, 1.57);
    arc(const Color(0xFF34A853), 1.57, 1.57);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
