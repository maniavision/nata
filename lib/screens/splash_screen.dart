import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:carrywise_app/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/preferences_service.dart';
import '../services/region_service.dart';
import 'login_screen.dart';
import '../widgets/nata_logo.dart';

class SplashScreen extends StatefulWidget {
  /// Override for tests; defaults to the real [RegionService].
  final RegionService? regionService;

  const SplashScreen({super.key, this.regionService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Drive selections through PreferencesService (single source of truth).
  final PreferencesService _prefs = PreferencesService();

  /// The country the app is being used in. Null until it has been detected,
  /// and for good if location is off, not allowed, or the country is unknown;
  /// the "Detected region" banner only exists while this is set.
  DetectedRegion? _region;

  @override
  void initState() {
    super.initState();
    _detectRegion();
  }

  Future<void> _detectRegion() async {
    final region = await (widget.regionService ?? RegionService()).detect();
    if (!mounted || region == null) return;
    setState(() => _region = region);
  }

  // Local UI indices (0-based) kept in sync with _prefs.
  int get _selectedLanguage => _langIndex(_prefs.language);
  int get _selectedCurrency => _currIndex(_prefs.currency);

  static int _langIndex(AppLanguage l) => AppLanguage.values.indexOf(l);
  static int _currIndex(AppCurrency c) => AppCurrency.values.indexOf(c);

  List<_LangOption> _buildLanguages(AppLocalizations l) => [
    _LangOption(flag: '🇺🇸', name: l.langEnglish, sub: l.langEnglishSub),
    _LangOption(flag: '🇪🇸', name: l.langSpanish, sub: l.langSpanishSub),
    _LangOption(flag: '🇫🇷', name: l.langFrench, sub: l.langFrenchSub),
  ];

  List<_CurrencyOption> _buildCurrencies(AppLocalizations l) => [
    _CurrencyOption(code: 'USD (\$)', label: l.currUSD),
    _CurrencyOption(code: 'EUR (€)', label: l.currEUR),
    _CurrencyOption(code: 'GBP (£)', label: l.currGBP),
    _CurrencyOption(code: 'XOF (CFA)', label: l.currXOF),
  ];

  void _saveAndContinue() {
    // Locale is already applied via PreferencesService → NataApp listener.
    // Keep LocaleNotifier in sync for any screens that still use it.
    LocaleNotifier.of(context).value = _prefs.locale;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final languages = _buildLanguages(l);
    final currencies = _buildCurrencies(l);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHero(l),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Column(
                        children: [
                          // Only shown once the country has been detected.
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.topCenter,
                            child: _region == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildDetectedRegionBanner(
                                      l,
                                      _region!,
                                    ),
                                  ),
                          ),
                          _buildPreferencesCard(l, languages, currencies),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(l),
        ],
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────
  Widget _buildHero(AppLocalizations l) {
    // The design's hero is 224 px with the top bar 24 px down. On a phone the
    // status bar sits on top of the image too, so add its height instead of
    // squeezing the content (which made the brand pill overlap the title).
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      height: 224 + topInset,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            spreadRadius: -1,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            spreadRadius: -2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
            child: Image.network(
              'https://ggrhecslgdflloszjkwl.supabase.co/storage/v1/object/public/user-assets/zQQR13YtUCF/components/zOWv1gqfkCP.jpeg',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.9),
              errorBuilder: (context, error, stack) =>
                  Container(color: AppColors.primary),
            ),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.5),
                  AppColors.primary,
                ],
              ),
            ),
          ),
          // Top Bar
          Positioned(
            top: topInset + 24,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand pill
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const NataLogo(size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Nata',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: -0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Countries badge
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.countries180,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom text content
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    'WELCOME · BIENVENUE · BIENVENIDO',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.splashTitle,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: Colors.white,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    AppLocalizations.of(context)!.splashSubtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      height: 16 / 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detected Region Banner ─────────────────────────────────────────────────
  Widget _buildDetectedRegionBanner(AppLocalizations l, DetectedRegion region) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.explore_rounded,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.splashDetectedRegion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  l.splashDetectedSummary(
                    region.countryName,
                    region.language.label,
                    region.currency.code,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            key: const ValueKey('quick-apply'),
            onPressed: () {
              // Apply what was detected for this country.
              setState(() {
                _prefs.setLanguage(region.language);
                _prefs.setCurrency(region.currency);
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.accent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shadowColor: const Color(0x0D000000),
              shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
            ),
            child: Text(
              l.splashQuickApply,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Preferences Card ───────────────────────────────────────────────────────
  Widget _buildPreferencesCard(
    AppLocalizations l,
    List<_LangOption> languages,
    List<_CurrencyOption> currencies,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.splashChooseLanguage,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.44,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Text(
                AppLocalizations.of(
                  context,
                )!.splashAvailable(AppLanguage.values.length),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...languages.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildLanguageTile(e.key, e.value),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          // Currency section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context)!.splashPreferredCurrency,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.44,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Text(
                AppLocalizations.of(
                  context,
                )!.splashAvailable(AppCurrency.values.length),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 2-column grid; rows size to their content (equal height per row).
          for (int row = 0; row < (currencies.length + 1) ~/ 2; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildCurrencyTile(row * 2, currencies[row * 2]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: row * 2 + 1 < currencies.length
                        ? _buildCurrencyTile(
                            row * 2 + 1,
                            currencies[row * 2 + 1],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Language tile ──────────────────────────────────────────────────────────
  Widget _buildLanguageTile(int index, _LangOption lang) {
    final selected = _selectedLanguage == index;
    return GestureDetector(
      onTap: () => setState(() {
        _prefs.setLanguage(AppLanguage.values[index]);
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.05)
              : AppColors.input,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.name,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 16 / 12,
                      color: AppColors.foreground,
                    ),
                  ),
                  Text(
                    lang.sub,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      height: 1.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.border,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.done_all_rounded,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Currency tile ──────────────────────────────────────────────────────────
  Widget _buildCurrencyTile(int index, _CurrencyOption currency) {
    final selected = _selectedCurrency == index;
    return GestureDetector(
      onTap: () => setState(() {
        _prefs.setCurrency(AppCurrency.values[index]);
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.05)
              : AppColors.input,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
                ]
              : null,
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
                    currency.code,
                    style: GoogleFonts.dmSans(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 12,
                      height: 16 / 12,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency.label,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      height: 1.5,
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
              const Icon(Icons.check_circle, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter(AppLocalizations l) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        bottomInset + 8 > 32 ? bottomInset + 8 : 32,
      ),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saveAndContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: const Color(0x33000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.splashSaveAndContinue,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.splashSettingsNote,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────
class _LangOption {
  final String flag;
  final String name;
  final String sub;
  const _LangOption({
    required this.flag,
    required this.name,
    required this.sub,
  });
}

class _CurrencyOption {
  final String code;
  final String label;
  const _CurrencyOption({required this.code, required this.label});
}
