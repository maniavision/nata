import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/location_search_service.dart';

/// Result returned when the user selects a location.
class LocationSelection {
  final String country;
  final String countryCode;
  final String city;
  final String displayLabel; // e.g. "Lagos, Nigeria"

  /// `nata.cities.id` of the chosen city (needed to save a trip). Null only
  /// for selections built without a database lookup.
  final int? cityId;

  const LocationSelection({
    required this.country,
    required this.countryCode,
    required this.city,
    required this.displayLabel,
    this.cityId,
  });
}

/// A bottom sheet that lets users search for a location.
/// Step 1: pick a country. Step 2: pick a city within that country.
///
/// Usage:
/// ```dart
/// final result = await LocationSearchSheet.show(context, title: 'Destination');
/// if (result != null) setState(() => _destination = result);
/// ```
class LocationSearchSheet extends StatefulWidget {
  final String title;
  final LocationSelection? initial;

  const LocationSearchSheet({
    super.key,
    required this.title,
    this.initial,
  });

  static Future<LocationSelection?> show(
    BuildContext context, {
    required String title,
    LocationSelection? initial,
  }) {
    return showModalBottomSheet<LocationSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.foreground.withValues(alpha: 0.4),
      builder: (_) => LocationSearchSheet(title: title, initial: initial),
    );
  }

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // Step: 0 = country search, 1 = city search
  int _step = 0;

  CountryResult? _selectedCountry;
  List<CountryResult> _countryResults = [];
  List<CityResult> _cityResults = [];
  bool _loading = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    // Pre-fill if editing an existing selection
    if (widget.initial != null) {
      _selectedCountry = CountryResult(
        isoCode: widget.initial!.countryCode,
        name: widget.initial!.country,
        phoneCode: '',
      );
      _step = 1;
    }
    // Load initial results immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _search('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(_searchCtrl.text);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      if (_step == 0) {
        final results =
            await LocationSearchService().searchCountries(query);
        if (mounted) setState(() => _countryResults = results);
      } else {
        final results = await LocationSearchService().searchCities(
          query,
          countryCode: _selectedCountry?.isoCode,
        );
        if (mounted) setState(() => _cityResults = results);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectCountry(CountryResult country) {
    setState(() {
      _selectedCountry = country;
      _step = 1;
      _searchCtrl.clear();
      _cityResults = [];
    });
    _focusNode.requestFocus();
    _search('');
  }

  void _selectCity(CityResult city) {
    Navigator.of(context).pop(LocationSelection(
      country: _selectedCountry!.name,
      countryCode: _selectedCountry!.isoCode,
      city: city.name,
      displayLabel: city.displayName,
      cityId: city.id,
    ));
  }

  void _goBackToCountry() {
    setState(() {
      _step = 0;
      _selectedCountry = null;
      _searchCtrl.clear();
      _cityResults = [];
    });
    _focusNode.requestFocus();
    _search('');
  }

  String get _hintText =>
      _step == 0 ? 'Search country...' : 'Search city in ${_selectedCountry?.name}...';

  String _flagEmoji(String isoCode) {
    if (isoCode.length != 2) return '🌍';
    final base = 0x1F1E6;
    return String.fromCharCodes([
      base + isoCode.codeUnitAt(0) - 0x41,
      base + isoCode.codeUnitAt(1) - 0x41,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomPad),
      duration: const Duration(milliseconds: 150),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          height: sheetHeight,
          color: AppColors.card,
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(),
              _buildSearchBar(),
              if (_step == 1) _buildCountryBreadcrumb(),
              const Divider(color: AppColors.border, height: 1),
              Expanded(child: _buildResultsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Container(
          width: 48,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(
          children: [
            if (_step == 1)
              GestureDetector(
                onTap: _goBackToCountry,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppColors.foreground),
                ),
              ),
            Expanded(
              child: Text(
                _step == 0 ? widget.title : 'Select City',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.foreground,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.mutedForeground),
              ),
            ),
          ],
        ),
      );

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.input,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNode.hasFocus ? AppColors.ring : AppColors.border,
              width: _focusNode.hasFocus ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                  decoration: InputDecoration(
                    hintText: _hintText,
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.mutedForeground,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _search('');
                  },
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.mutedForeground),
                ),
            ],
          ),
        ),
      );

  Widget _buildCountryBreadcrumb() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            Text(
              _flagEmoji(_selectedCountry?.isoCode ?? ''),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              _selectedCountry?.name ?? '',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.mutedForeground),
            Text(
              'Select city',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );

  Widget _buildResultsList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    final isEmpty =
        _step == 0 ? _countryResults.isEmpty : _cityResults.isEmpty;
    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 40, color: AppColors.muted),
            const SizedBox(height: 8),
            Text(
              _step == 0
                  ? 'No countries found'
                  : 'No cities found in ${_selectedCountry?.name}',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    return _step == 0 ? _buildCountryList() : _buildCityList();
  }

  Widget _buildCountryList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _countryResults.length,
      separatorBuilder: (_, __) => const Divider(
          color: AppColors.border, height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) {
        final country = _countryResults[i];
        return GestureDetector(
          onTap: () => _selectCountry(country),
          child: Container(
            color: Colors.transparent,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Text(
                  _flagEmoji(country.isoCode),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    country.name,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.mutedForeground),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _cityResults.length,
      separatorBuilder: (_, __) => const Divider(
          color: AppColors.border, height: 1, indent: 20, endIndent: 20),
      itemBuilder: (context, i) {
        final city = _cityResults[i];
        return GestureDetector(
          onTap: () => _selectCity(city),
          child: Container(
            color: Colors.transparent,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_city_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city.name,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        city.countryName,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.mutedForeground),
              ],
            ),
          ),
        );
      },
    );
  }
}
