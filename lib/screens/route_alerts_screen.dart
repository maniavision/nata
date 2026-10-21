import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/route_alert_service.dart';
import '../widgets/location_search_sheet.dart';
import '../widgets/nata_toast.dart';

/// Picks a place (country, then city). Replaced in tests.
typedef RoutePlacePicker =
    Future<LocationSelection?> Function(BuildContext context, String title);

/// Route alerts (designed in Sleek: "Route Alerts", "(Empty)" and "(Add
/// Route Sheet)"): the routes the member often sends on. When a trip on one
/// goes live they are notified (migration 20240159).
class RouteAlertsScreen extends StatefulWidget {
  final RouteAlertService? service;
  final RoutePlacePicker? pickPlace;

  const RouteAlertsScreen({super.key, this.service, this.pickPlace});

  @override
  State<RouteAlertsScreen> createState() => _RouteAlertsScreenState();
}

class _RouteAlertsScreenState extends State<RouteAlertsScreen> {
  RouteAlertService get _service => widget.service ?? RouteAlertService();

  List<RouteAlert> _routes = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final routes = await _service.list();
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('[RouteAlerts] load: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.foreground.withValues(alpha: 0.45),
      builder: (_) => _AddRouteSheet(
        service: _service,
        pickPlace:
            widget.pickPlace ??
            (context, title) => LocationSearchSheet.show(context, title: title),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        nataToast(context.l10n.routeAlertsSavedToast, tone: ToastTone.success),
      );
      _load();
    }
  }

  Future<void> _remove(RouteAlert r) async {
    setState(() => _routes = _routes.where((x) => x.id != r.id).toList());
    try {
      await _service.remove(r.id);
    } catch (e) {
      debugPrint('[RouteAlerts] remove: $e');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    key: const ValueKey('route-alerts-back'),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.routeAlerts,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.routeAlertsLoadFailed,
              key: const ValueKey('route-alerts-error'),
              style: GoogleFonts.dmSans(color: AppColors.mutedForeground),
            ),
            TextButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: Text(l.retry),
            ),
          ],
        ),
      );
    }
    final full = _routes.length >= RouteAlertService.maxRoutes;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          l.routeAlertsIntro,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            height: 1.5,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 18),
        if (_routes.isEmpty)
          _empty()
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  l.routeAlertsSaved,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Text(
                l.routeAlertsCount(_routes.length),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in _routes) _RouteCard(route: r, onRemove: _remove),
          const SizedBox(height: 8),
        ],
        ...[
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const ValueKey('route-alerts-add'),
              onPressed: full ? null : _add,
              icon: const Icon(Icons.add_circle_rounded, size: 20),
              label: Text(l.routeAlertsAdd),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryForeground,
                shape: const StadiumBorder(),
                textStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.routeAlertsMax,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  Widget _empty() {
    final l = context.l10n;
    return Container(
      key: const ValueKey('route-alerts-empty'),
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notification_add_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.routeAlertsEmptyTitle,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.routeAlertsEmptyBody,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

String _flag(String isoCode) {
  final code = isoCode.trim().toUpperCase();
  if (code.length != 2) return '🌍';
  const base = 0x1F1E6;
  return String.fromCharCodes([
    base + code.codeUnitAt(0) - 0x41,
    base + code.codeUnitAt(1) - 0x41,
  ]);
}

/// One saved route: From above, To below, joined by a short line.
class _RouteCard extends StatelessWidget {
  final RouteAlert route;
  final ValueChanged<RouteAlert> onRemove;

  const _RouteCard({required this.route, required this.onRemove});

  Widget _place(String code, String city, String country) => Row(
    children: [
      Text(_flag(code), style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Flexible(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: city,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.foreground,
                ),
              ),
              TextSpan(
                text: '  $country',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('route-${route.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _place(
                  route.fromCountryCode,
                  route.fromCity,
                  route.fromCountry,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: Container(
                    width: 1.5,
                    height: 14,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: AppColors.border,
                  ),
                ),
                _place(route.toCountryCode, route.toCity, route.toCountry),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('route-remove-${route.id}'),
            tooltip: context.l10n.routeAlertsRemove,
            onPressed: () => onRemove(route),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Add a route": From and To pickers, then Save route.
class _AddRouteSheet extends StatefulWidget {
  final RouteAlertService service;
  final RoutePlacePicker pickPlace;

  const _AddRouteSheet({required this.service, required this.pickPlace});

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  LocationSelection? _from;
  LocationSelection? _to;
  bool _saving = false;
  String? _error;

  Future<void> _pick({required bool from}) async {
    final l = context.l10n;
    final place = await widget.pickPlace(
      context,
      from ? l.routeAlertsFrom : l.routeAlertsTo,
    );
    if (place == null || !mounted) return;
    setState(() {
      if (from) {
        _from = place;
      } else {
        _to = place;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final l = context.l10n;
    final from = _from?.cityId;
    final to = _to?.cityId;
    if (from == null || to == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.add(fromCityId: from, toCityId: to);
      if (mounted) Navigator.of(context).pop(true);
    } on RouteAlertException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (e.reason) {
          RouteAlertFailure.samePlace => l.routeAlertsErrSame,
          RouteAlertFailure.limit => l.routeAlertsErrLimit,
          RouteAlertFailure.exists => l.routeAlertsErrExists,
          RouteAlertFailure.failed => l.routeAlertsErrFailed,
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.routeAlertsErrFailed;
        });
      }
    }
  }

  Widget _field(String key, String label, LocationSelection? value, bool from) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.2,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: _saving ? null : () => _pick(from: from),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  from ? Icons.trip_origin_rounded : Icons.place_rounded,
                  size: 18,
                  color: from ? AppColors.primary : AppColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value?.displayLabel ?? l.routeAlertsChooseCity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: value == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: value == null
                          ? AppColors.mutedForeground
                          : AppColors.foreground,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    final ready = _from?.cityId != null && _to?.cityId != null && !_saving;
    return Container(
      key: const ValueKey('route-add-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l.routeAlertsAdd,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 16),
            _field('route-from', l.routeAlertsFrom, _from, true),
            const SizedBox(height: 12),
            _field('route-to', l.routeAlertsTo, _to, false),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const ValueKey('route-add-error'),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey('route-save'),
                onPressed: ready ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryForeground,
                        ),
                      )
                    : Text(l.routeAlertsSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
