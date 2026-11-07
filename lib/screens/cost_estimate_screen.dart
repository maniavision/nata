import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/city_service.dart';
import '../services/delivery_pricing.dart';
import '../services/exchange_rate_service.dart';
import '../services/preferences_service.dart';
import '../services/region_service.dart';
import '../services/screen_cache.dart';
import '../services/request_service.dart' show PriceFormatter;
import '../widgets/location_search_sheet.dart';
import 'route_alerts_screen.dart' show RoutePlacePicker, formatKg;

/// The weight's unit on the estimate page.
enum WeightUnit { kg, lb }

/// "Estimate a delivery", from Profile: a fair price for a route and a
/// weight, to help the sender and the traveler agree on one. Nata's fee is
/// left out, and nobody has to use it: they agree the price in the chat.
///
/// Not designed in Sleek yet (signed out); it follows the Route Alerts sheet.
class CostEstimateScreen extends StatefulWidget {
  final RoutePlacePicker? pickPlace;
  final CityService? cityService;
  final ExchangeRateService? exchangeRates;

  /// The currency to show; the member's chosen one by default.
  final String? currency;

  const CostEstimateScreen({
    super.key,
    this.pickPlace,
    this.cityService,
    this.exchangeRates,
    this.currency,
  });

  /// A trip is taken to be a week away: the page asks for no date, and the
  /// formula's urgency part needs one.
  static const assumedHours = 7 * 24;

  static const kgPerLb = 0.45359237;

  /// The heaviest weight the page prices, in kg (as the request form).
  static const maxWeightKg = 999.0;

  /// How much less a trip within the country [isoCode] costs, in percent:
  /// 65 in Africa, 45 anywhere else.
  static int localDiscountPercent(String isoCode) =>
      RegionService.isAfrican(isoCode) ? 65 : 45;

  /// The suggested price in US dollars, rounded up to whole dollars, less
  /// [discountPercent] percent.
  static double priceUsd({
    required double distanceKm,
    required double kg,
    int discountPercent = 0,
  }) {
    final cost = CostCalculator.calculateCost(
      distanceKm: distanceKm,
      deliveryTimeInHours: assumedHours,
      weightKg: kg,
    );
    return ceilWhole(cost * (100 - discountPercent) / 100).toDouble();
  }

  /// [input] in kg, or null unless it is a weight above 0 and up to
  /// [maxWeightKg].
  static double? parseKg(String input, WeightUnit unit) {
    final value = double.tryParse(input.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return null;
    final kg = unit == WeightUnit.lb ? value * kgPerLb : value;
    return kg <= maxWeightKg ? kg : null;
  }

  @override
  State<CostEstimateScreen> createState() => _CostEstimateScreenState();
}

class _CostEstimateScreenState extends State<CostEstimateScreen> {
  LocationSelection? _from;
  LocationSelection? _to;
  final _weight = TextEditingController();
  WeightUnit _unit = WeightUnit.kg;

  double? _distanceKm;
  bool _distanceFailed = false;
  bool _loadingDistance = false;

  late final String _currency =
      (widget.currency ?? PreferencesService().currency.code).toUpperCase();
  double? _rate;

  @override
  void initState() {
    super.initState();
    _restoreEntries();
    _loadRate();
  }

  @override
  void dispose() {
    _saveEntries();
    _weight.dispose();
    super.dispose();
  }

  // ── Entries kept ───────────────────────────────────────────────────────────
  // Leaving the page keeps the cities, weight and unit for this app session
  // and this member (ScreenCache, cleared on sign-out), so coming back shows
  // them again.

  static const _entriesKey = 'cost-estimate-entries';

  void _restoreEntries() {
    final e = ScreenCache.read<_Entries>(_entriesKey);
    if (e == null) return;
    _from = e.from;
    _to = e.to;
    _weight.text = e.weight;
    _unit = e.unit;
    if (_from != null && _to != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDistance();
      });
    }
  }

  void _saveEntries() {
    final e = _Entries(from: _from, to: _to, weight: _weight.text, unit: _unit);
    ScreenCache.write(_entriesKey, e.isEmpty ? null : e);
  }

  Future<void> _loadRate() async {
    if (_currency == 'USD') return;
    ExchangeRates? rates;
    try {
      rates = await (widget.exchangeRates ?? ExchangeRateService.shared)
          .rates();
    } catch (_) {
      rates = null;
    }
    if (mounted) setState(() => _rate = rates?.rateFor(_currency));
  }

  Future<void> _pick({required bool from}) async {
    final l = context.l10n;
    final pick =
        widget.pickPlace ??
        (context, title) => LocationSearchSheet.show(context, title: title);
    final place = await pick(
      context,
      from ? l.costEstimateFrom : l.costEstimateTo,
    );
    if (place == null || !mounted) return;
    setState(() {
      if (from) {
        _from = place;
      } else {
        _to = place;
      }
    });
    _loadDistance();
  }

  bool get _samePlace =>
      _from != null &&
      _to != null &&
      _from!.countryCode == _to!.countryCode &&
      _from!.city.toLowerCase() == _to!.city.toLowerCase();

  Future<void> _loadDistance() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null || _samePlace) {
      setState(() {
        _distanceKm = null;
        _distanceFailed = false;
      });
      return;
    }
    setState(() {
      _loadingDistance = true;
      _distanceFailed = false;
      _distanceKm = null;
    });
    try {
      final cities = widget.cityService ?? CityService();
      final a = await cities.coordinates(from.countryCode, from.city);
      final b = await cities.coordinates(to.countryCode, to.city);
      if (!mounted || from != _from || to != _to) return;
      setState(() {
        _loadingDistance = false;
        if (a == null || b == null) {
          _distanceFailed = true;
        } else {
          _distanceKm = DistanceCalculator.haversine(
            a.latitude,
            a.longitude,
            b.latitude,
            b.longitude,
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDistance = false;
          _distanceFailed = true;
        });
      }
    }
  }

  double? get _kg => CostEstimateScreen.parseKg(_weight.text, _unit);

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
                    key: const ValueKey('estimate-back'),
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
                      l.costEstimate,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text(
                    l.costEstimateIntro,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _field('estimate-from', l.costEstimateFrom, _from, true),
                  const SizedBox(height: 14),
                  _field('estimate-to', l.costEstimateTo, _to, false),
                  const SizedBox(height: 14),
                  _weightField(),
                  const SizedBox(height: 20),
                  _result(),
                  const SizedBox(height: 16),
                  _guideNote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 10,
      letterSpacing: 1.2,
      color: AppColors.mutedForeground,
    ),
  );

  Widget _field(String key, String label, LocationSelection? value, bool from) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => _pick(from: from),
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
                    value?.displayLabel ?? l.costEstimateChooseCity,
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

  Widget _weightField() {
    final l = context.l10n;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l.costEstimateWeight),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('estimate-weight'),
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
                decoration: InputDecoration(
                  hintText: l.costEstimateWeightHint,
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                  prefixIcon: const Icon(
                    Icons.scale_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  filled: true,
                  fillColor: AppColors.input,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _unitSwitch(),
          ],
        ),
        if (_weight.text.trim().isNotEmpty && _kg == null) ...[
          const SizedBox(height: 6),
          Text(
            l.costEstimateErrWeight,
            key: const ValueKey('estimate-weight-error'),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.destructive,
            ),
          ),
        ],
      ],
    );
  }

  /// kg | lb, side by side.
  Widget _unitSwitch() {
    Widget option(WeightUnit unit, String text) {
      final on = _unit == unit;
      return GestureDetector(
        key: ValueKey('estimate-unit-${unit.name}'),
        onTap: () => setState(() => _unit = unit),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: on ? Colors.white : AppColors.mutedForeground,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option(WeightUnit.kg, 'kg'), option(WeightUnit.lb, 'lb')],
      ),
    );
  }

  Widget _result() {
    final l = context.l10n;
    final km = _distanceKm;
    final kg = _kg;
    String? message;
    if (_samePlace) {
      message = l.costEstimateErrSame;
    } else if (_distanceFailed) {
      message = l.costEstimateErrDistance;
    } else if (_from == null || _to == null || kg == null) {
      message = l.costEstimateEmpty;
    }

    Widget body;
    if (_loadingDistance) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    } else if (message != null || km == null || kg == null) {
      body = Text(
        message ?? l.costEstimateEmpty,
        key: const ValueKey('estimate-message'),
        style: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.5,
          color: _samePlace || _distanceFailed
              ? AppColors.destructive
              : AppColors.mutedForeground,
        ),
      );
    } else {
      final discount = _from!.countryCode == _to!.countryCode
          ? CostEstimateScreen.localDiscountPercent(_from!.countryCode)
          : 0;
      final usd = CostEstimateScreen.priceUsd(
        distanceKm: km,
        kg: kg,
        discountPercent: discount,
      );
      final money = PriceFormatter.forCurrency(_currency, _rate);
      final locale = Localizations.localeOf(context).toString();
      final typed = double.parse(_weight.text.trim().replaceAll(',', '.'));
      final weight =
          '${formatKg(typed)} ${_unit == WeightUnit.kg ? 'kg' : 'lb'}';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(l.costEstimateResult),
          const SizedBox(height: 6),
          Text(
            money.currency == 'USD'
                ? money.format(usd)
                : '≈ ${money.format(usd)}',
            key: const ValueKey('estimate-price'),
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.costEstimateDetails(
              NumberFormat.decimalPattern(locale).format(km.round()),
              weight,
            ),
            key: const ValueKey('estimate-details'),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      );
    }

    return Container(
      key: const ValueKey('estimate-result'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: body,
    );
  }

  /// Only a guide: nobody has to use it.
  Widget _guideNote() {
    final l = context.l10n;
    return Container(
      key: const ValueKey('estimate-guide'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.costEstimateGuide,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.5,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What was entered on the estimate page, kept while away from it.
class _Entries {
  final LocationSelection? from;
  final LocationSelection? to;
  final String weight;
  final WeightUnit unit;

  const _Entries({
    required this.from,
    required this.to,
    required this.weight,
    required this.unit,
  });

  bool get isEmpty => from == null && to == null && weight.trim().isEmpty;
}
