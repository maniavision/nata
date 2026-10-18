import 'package:flutter/material.dart';
import '../l10n/l10n_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/country_service.dart';

/// The flag emoji for a two-letter ISO country code ("CM" -> 🇨🇲).
String flagEmoji(String isoCode) {
  if (isoCode.length != 2) return '🌍';
  const base = 0x1F1E6;
  final iso = isoCode.toUpperCase();
  return String.fromCharCodes([
    base + iso.codeUnitAt(0) - 0x41,
    base + iso.codeUnitAt(1) - 0x41,
  ]);
}

/// Opens the searchable country-code sheet; returns the picked country, or
/// null if it was dismissed.
Future<Country?> showCountryCodePicker(BuildContext context, Country selected) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.foreground.withValues(alpha: 0.4),
    builder: (ctx) => CountryCodePickerSheet(
      selected: selected,
      onSelected: (country) => Navigator.of(ctx).pop(country),
    ),
  );
}

/// Bottom sheet listing every country with its dialling code, with search.
class CountryCodePickerSheet extends StatefulWidget {
  final Country selected;
  final ValueChanged<Country> onSelected;
  const CountryCodePickerSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<CountryCodePickerSheet> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Country> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _searchCtrl.addListener(_onSearch);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  Future<void> _loadCountries() async {
    final all = await CountryService().all();
    if (mounted) {
      setState(() {
        _filtered = all;
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text;
    CountryService().search(q).then((results) {
      if (mounted) setState(() => _filtered = results);
    });
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.80,
          color: AppColors.card,
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.selectCountryCode,
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
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
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
                            hintText: context.l10n.searchCountryHint,
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.mutedForeground,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchCtrl.clear()),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              // List
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      )
                    : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.noCountriesFound,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: AppColors.border,
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                        ),
                        itemBuilder: (context, i) {
                          final country = _filtered[i];
                          final isSelected =
                              country.isoCode == widget.selected.isoCode;
                          return GestureDetector(
                            onTap: () => widget.onSelected(country),
                            child: Container(
                              color: isSelected
                                  ? AppColors.accent.withValues(alpha: 0.06)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  // Flag
                                  Text(
                                    flagEmoji(country.isoCode),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  // Name
                                  Expanded(
                                    child: Text(
                                      country.name,
                                      style: GoogleFonts.dmSans(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 14,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.foreground,
                                      ),
                                    ),
                                  ),
                                  // Phone code
                                  Text(
                                    country.phoneCode,
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.mutedForeground,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
