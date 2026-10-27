import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../screens/route_alerts_screen.dart';
import '../services/route_alert_service.dart';
import '../services/trip_service.dart';

/// On the "verified" screen (designed in Sleek, "Verified - Route alert
/// nudge"): a new member who is more likely to send than to carry (no trip
/// posted) and has no route alert yet is asked to create one. Hidden once
/// they have one, or after "Maybe later"; shows nothing while loading or if
/// loading fails.
class VerifiedRouteNudge extends StatefulWidget {
  /// Overrides for tests.
  final RouteAlertService? routeService;
  final TripService? tripService;
  final WidgetBuilder? routesBuilder;

  const VerifiedRouteNudge({
    super.key,
    this.routeService,
    this.tripService,
    this.routesBuilder,
  });

  @override
  State<VerifiedRouteNudge> createState() => _VerifiedRouteNudgeState();
}

class _VerifiedRouteNudgeState extends State<VerifiedRouteNudge> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        (widget.routeService ?? RouteAlertService()).list(),
        (widget.tripService ?? TripService()).myTrips(),
      ]);
      final show = results[0].isEmpty && results[1].isEmpty;
      if (mounted && show != _show) setState(() => _show = show);
    } catch (e) {
      debugPrint('[VerifiedRouteNudge] $e');
    }
  }

  Future<void> _create() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            widget.routesBuilder ??
            (_) => RouteAlertsScreen(service: widget.routeService),
      ),
    );
    // Gone once a route is saved.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        key: const ValueKey('verified-route-nudge'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notification_add_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.verifiedRoutesTitle,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.verifiedRoutesBody,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                key: const ValueKey('verified-route-nudge-create'),
                onPressed: _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  l.verifiedRoutesAction,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                key: const ValueKey('verified-route-nudge-later'),
                onPressed: () => setState(() => _show = false),
                child: Text(
                  l.maybeLater,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
