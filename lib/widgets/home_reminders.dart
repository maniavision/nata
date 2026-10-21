import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../screens/identity_verification_screen.dart';
import '../screens/route_alerts_screen.dart';
import '../services/route_alert_service.dart';

/// "Get started" on Home for a new member (designed in Sleek, "Home (New
/// Member Reminders)"): verify your identity, and save the routes you send
/// on. Each card stays until it is done: the verify card until the identity
/// check is sent, the routes card until a route is saved or the member
/// closes it with ✕ (remembered on this device, per member).
class HomeReminders extends StatefulWidget {
  /// nata.profiles.verification_status, or null while it is loading.
  final String? verificationStatus;

  /// The signed-in member (the routes card's ✕ is remembered per member).
  final String? userId;

  /// Called when the member comes back from verifying or adding a route.
  final VoidCallback? onChanged;

  /// Overrides for tests.
  final RouteAlertService? routeService;
  final WidgetBuilder? verifyBuilder;
  final WidgetBuilder? routesBuilder;

  const HomeReminders({
    super.key,
    required this.verificationStatus,
    required this.userId,
    this.onChanged,
    this.routeService,
    this.verifyBuilder,
    this.routesBuilder,
  });

  static String dismissKey(String userId) => 'route_reminder_dismissed_$userId';

  @override
  State<HomeReminders> createState() => _HomeRemindersState();
}

class _HomeRemindersState extends State<HomeReminders> {
  /// Null until known: the routes card waits rather than flashing.
  bool? _hasRoutes;
  bool _routesDismissed = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void didUpdateWidget(HomeReminders old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId) _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final id = widget.userId;
    if (id == null) return;
    var dismissed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed = prefs.getBool(HomeReminders.dismissKey(id)) ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _routesDismissed = dismissed);
    if (dismissed) return;
    try {
      final routes = await (widget.routeService ?? RouteAlertService()).list();
      if (mounted) setState(() => _hasRoutes = routes.isNotEmpty);
    } catch (e) {
      debugPrint('[HomeReminders] routes: $e');
    }
  }

  Future<void> _dismissRoutes() async {
    setState(() => _routesDismissed = true);
    final id = widget.userId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(HomeReminders.dismissKey(id), true);
    } catch (_) {}
  }

  Future<void> _open(WidgetBuilder builder) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    if (!mounted) return;
    widget.onChanged?.call();
    _loadRoutes();
  }

  bool get _showVerify => widget.verificationStatus == 'unverified';
  bool get _showRoutes => !_routesDismissed && _hasRoutes == false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!_showVerify && !_showRoutes) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('home-reminders'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.homeGetStarted.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          if (_showVerify)
            _ReminderCard(
              key: const ValueKey('reminder-verify'),
              actionKey: 'reminder-verify-action',
              icon: Icons.shield_rounded,
              tint: AppColors.accent,
              title: l.homeVerifyTitle,
              body: l.homeVerifyBody,
              action: l.homeVerifyAction,
              filled: true,
              onAction: () => _open(
                widget.verifyBuilder ??
                    (_) => const IdentityVerificationScreen(),
              ),
            ),
          if (_showVerify && _showRoutes) const SizedBox(height: 10),
          if (_showRoutes)
            _ReminderCard(
              key: const ValueKey('reminder-routes'),
              actionKey: 'reminder-routes-action',
              icon: Icons.notification_add_rounded,
              tint: AppColors.primary,
              title: l.homeRoutesTitle,
              body: l.homeRoutesBody,
              action: l.homeRoutesAction,
              filled: false,
              onAction: () => _open(
                widget.routesBuilder ?? (_) => const RouteAlertsScreen(),
              ),
              onDismiss: _dismissRoutes,
            ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String body;
  final String action;
  final bool filled;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;
  final String actionKey;

  const _ReminderCard({
    super.key,
    required this.actionKey,
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
    required this.action,
    required this.filled,
    required this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final buttonText = GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 12,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: filled
                      ? FilledButton(
                          key: ValueKey('$actionKey'),
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.primaryForeground,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: buttonText,
                          ),
                          child: Text(action),
                        )
                      : OutlinedButton(
                          key: ValueKey('$actionKey'),
                          onPressed: onAction,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: buttonText,
                          ),
                          child: Text(action),
                        ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              key: const ValueKey('reminder-routes-dismiss'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
