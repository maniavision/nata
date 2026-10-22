import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carrywise_app/l10n/app_localizations.dart';
import 'config/supabase_config.dart';
import 'services/push_service.dart';
import 'services/preferences_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_update_listener.dart';
import 'services/app_badge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // The country the user registered with, remembered on this device.
  await PreferencesService().restore();

  runApp(const NataApp());
}

// ── Locale notifier ────────────────────────────────────────────────────────
// Kept for backward-compatibility with existing screens that call
// LocaleNotifier.of(context).value = Locale('es').
// Internally it now mirrors PreferencesService.
class LocaleNotifier extends InheritedNotifier<ValueNotifier<Locale>> {
  const LocaleNotifier({
    super.key,
    required ValueNotifier<Locale> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ValueNotifier<Locale> of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LocaleNotifier>()!
        .notifier!;
  }
}

// ── Root app ───────────────────────────────────────────────────────────────
class NataApp extends StatefulWidget {
  const NataApp({super.key});

  @override
  State<NataApp> createState() => _NataAppState();
}

class _NataAppState extends State<NataApp> with WidgetsBindingObserver {
  final PreferencesService _prefs = PreferencesService();

  // Mirror the locale in a ValueNotifier so existing code using
  // LocaleNotifier.of(context).value = ... still works.
  late final ValueNotifier<Locale> _localeNotifier;

  /// Lets the update notice reach the navigator from outside of it.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _localeNotifier = ValueNotifier(_prefs.locale);
    // Keep the ValueNotifier in sync with PreferencesService changes.
    _prefs.addListener(_onPrefsChanged);
    PushService.instance.start(_navigatorKey);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the app: the icon badge shows the current unread count.
    if (state == AppLifecycleState.resumed) AppBadge.refresh();
  }

  void _onPrefsChanged() {
    _localeNotifier.value = _prefs.locale;
    // setState so MaterialApp.locale updates.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prefs.removeListener(_onPrefsChanged);
    _localeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LocaleNotifier(
      notifier: _localeNotifier,
      child: AppUpdateListener(
        navigatorKey: _navigatorKey,
        child: MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'Nata',
          debugShowCheckedModeBanner: false,
          locale: _prefs.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: const ColorScheme.light(
              surface: AppColors.card,
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              onPrimary: AppColors.primaryForeground,
              onSurface: AppColors.foreground,
            ),
            textTheme: GoogleFonts.dmSansTextTheme(),
            useMaterial3: true,
          ),
          // The splash (language and currency) is for first-time visitors;
          // a member who has used this device starts on Sign In.
          home: startScreen(),
        ),
      ),
    );
  }
}

// ── App color palette ──────────────────────────────────────────────────────
class AppColors {
  static const Color background = Color(0xFFFFF9F3);
  static const Color foreground = Color(0xFF102F35);
  static const Color primary = Color(0xFF123F46);
  static const Color primaryForeground = Color(0xFFFFF9F3);
  static const Color secondary = Color(0xFFF2E8DE);
  static const Color secondaryForeground = Color(0xFF123F46);
  static const Color muted = Color(0xFFE8E3DD);
  static const Color mutedForeground = Color(0xFF6D7D7D);
  static const Color accent = Color(0xFFF26F5B);
  static const Color accentForeground = Color(0xFFFFFFFF);
  static const Color destructive = Color(0xFFC94B45);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF102F35);
  static const Color border = Color(0xFFE8DED4);
  static const Color input = Color(0xFFFFFDF9);
  static const Color ring = Color(0xFFF26F5B);
}
