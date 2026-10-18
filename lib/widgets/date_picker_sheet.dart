import 'package:flutter/material.dart';
import '../l10n/l10n_ext.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

/// What the user confirmed in a [DatePickerSheet].
class DatePickerResult {
  /// The chosen date, or null for "anytime" (only possible when the sheet was
  /// opened with `allowAnytime: true`).
  final DateTime? date;

  /// Whether the "Flexible (±3d)" option is on.
  final bool flexible;

  const DatePickerResult(this.date, this.flexible);
}

/// Calendar bottom sheet used by Home (delivery date) and Add Trip
/// (departure / arrival dates).
///
/// Home turns on the quick filters, "anytime" and per-day traveler counts.
/// Add Trip uses the plain calendar: a date is required and days before
/// [firstDate] cannot be picked.
class DatePickerSheet extends StatefulWidget {
  final String title;
  final DateTime? initialDate;
  final bool initialFlexible;

  /// Number of upcoming traveler arrivals per day (keys are date-only).
  /// When null, no counts are shown.
  final Map<DateTime, int>? flightCounts;

  /// Show the Anytime / This Week / Next Week / Flexible chips.
  final bool showFilters;

  /// Allow confirming without a date ("anytime").
  final bool allowAnytime;

  /// Earliest selectable day. Defaults to today.
  final DateTime? firstDate;

  const DatePickerSheet({
    super.key,
    required this.title,
    this.initialDate,
    this.initialFlexible = false,
    this.flightCounts,
    this.showFilters = false,
    this.allowAnytime = false,
    this.firstDate,
  });

  /// Opens the sheet. Returns null if it is dismissed without confirming.
  static Future<DatePickerResult?> show(
    BuildContext context, {
    required String title,
    DateTime? initialDate,
    bool initialFlexible = false,
    Map<DateTime, int>? flightCounts,
    bool showFilters = false,
    bool allowAnytime = false,
    DateTime? firstDate,
  }) {
    return showModalBottomSheet<DatePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.foreground.withValues(alpha: 0.4),
      builder: (ctx) => DatePickerSheet(
        title: title,
        initialDate: initialDate,
        initialFlexible: initialFlexible,
        flightCounts: flightCounts,
        showFilters: showFilters,
        allowAnytime: allowAnytime,
        firstDate: firstDate,
      ),
    );
  }

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _viewMonth;
  DateTime? _selected;
  bool _flexible = false;

  String get _locale => Localizations.localeOf(context).toString();

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Column headers, Sunday first: "Su", "Mo"... in the app's language.
  List<String> get _weekDays => [
    // 2030-06-02 is a Sunday.
    for (var i = 0; i < 7; i++)
      _capitalize(
        DateFormat.E(_locale).format(DateTime(2030, 6, 2 + i)),
      ).replaceAll('.', '').substring(0, 2),
  ];

  List<String> get _filters {
    final l = context.l10n;
    return [l.dateAnytime, l.dateThisWeek, l.dateNextWeek, l.dateFlexible];
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Earliest selectable day (date only).
  DateTime get _first {
    final f = widget.firstDate;
    if (f == null) return _today;
    return DateTime(f.year, f.month, f.day);
  }

  bool get _hasCounts => widget.flightCounts != null;

  /// The Sunday that ends the week [weeksAhead] weeks from now.
  DateTime _endOfWeek(int weeksAhead) =>
      _today.add(Duration(days: (7 - _today.weekday) + 7 * weeksAhead));

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate;
    _selected = initial;
    _flexible = initial != null && widget.initialFlexible;
    final anchor = initial ?? _first;
    _viewMonth = DateTime(anchor.year, anchor.month);
  }

  bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isChipActive(int i) {
    switch (i) {
      case 0:
        return _selected == null;
      case 1:
        return _sameDay(_selected, _endOfWeek(0));
      case 2:
        return _sameDay(_selected, _endOfWeek(1));
      default:
        return _flexible;
    }
  }

  void _onChipTap(int i) {
    setState(() {
      switch (i) {
        case 0:
          _selected = null;
          _flexible = false;
        case 1:
        case 2:
          _selected = _endOfWeek(i - 1);
          _viewMonth = DateTime(_selected!.year, _selected!.month);
        default:
          // Flexibility only makes sense with a date; start from today.
          if (_selected == null && !_flexible) {
            _selected = _today;
            _viewMonth = DateTime(_today.year, _today.month);
          }
          _flexible = !_flexible;
      }
    });
  }

  int get _flightsInViewMonth => (widget.flightCounts ?? const {}).entries
      .where(
        (e) => e.key.year == _viewMonth.year && e.key.month == _viewMonth.month,
      )
      .fold(0, (sum, e) => sum + e.value);

  int _flightsOn(DateTime d) =>
      (widget.flightCounts ?? const {})[DateTime(d.year, d.month, d.day)] ?? 0;

  /// True when the visible month is the earliest one that can be shown.
  bool get _isCurrentMonth =>
      _viewMonth.year == _first.year && _viewMonth.month == _first.month;

  bool _isPast(int day) =>
      DateTime(_viewMonth.year, _viewMonth.month, day).isBefore(_first);

  int _firstWeekdayOfMonth() =>
      DateTime(_viewMonth.year, _viewMonth.month, 1).weekday % 7;
  int _daysInMonth() => DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
  bool _isSelected(int day) =>
      _selected != null &&
      _selected!.year == _viewMonth.year &&
      _selected!.month == _viewMonth.month &&
      _selected!.day == day;

  @override
  Widget build(BuildContext context) {
    final firstDay = _firstWeekdayOfMonth();
    final daysInMonth = _daysInMonth();
    final totalCells = ((firstDay + daysInMonth) / 7).ceil() * 7;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        color: AppColors.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 12),
                    if (widget.showFilters) ...[
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final active = _isChipActive(i);
                            return GestureDetector(
                              key: ValueKey('date-filter-$i'),
                              onTap: () => _onChipTap(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.accent
                                      : AppColors.secondary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _filters[i],
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: active
                                        ? Colors.white
                                        : AppColors.secondaryForeground,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          key: const ValueKey('calendar-prev-month'),
                          onTap: _isCurrentMonth
                              ? null
                              : () => setState(
                                  () => _viewMonth = DateTime(
                                    _viewMonth.year,
                                    _viewMonth.month - 1,
                                  ),
                                ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.input,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              size: 18,
                              color: AppColors.mutedForeground.withValues(
                                alpha: _isCurrentMonth ? 0.3 : 1,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              _capitalize(
                                DateFormat.yMMMM(_locale).format(_viewMonth),
                              ),
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.foreground,
                              ),
                            ),
                            if (_hasCounts)
                              Text(
                                context.l10n.travelerFlightsCount(
                                  _flightsInViewMonth,
                                ),
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  color: AppColors.accent,
                                ),
                              ),
                          ],
                        ),
                        GestureDetector(
                          key: const ValueKey('calendar-next-month'),
                          onTap: () => setState(
                            () => _viewMonth = DateTime(
                              _viewMonth.year,
                              _viewMonth.month + 1,
                            ),
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.input,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _weekDays
                          .map(
                            (d) => Expanded(
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: totalCells,
                      itemBuilder: (context, i) {
                        if (i < firstDay) {
                          final prevDays = DateTime(
                            _viewMonth.year,
                            _viewMonth.month,
                            0,
                          ).day;
                          final day = prevDays - firstDay + i + 1;
                          return Center(
                            child: Text(
                              '$day',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.mutedForeground.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          );
                        }
                        final dayNum = i - firstDay + 1;
                        if (dayNum > daysInMonth) {
                          return Center(
                            child: Text(
                              '${dayNum - daysInMonth}',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.mutedForeground.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          );
                        }
                        final past = _isPast(dayNum);
                        final sel = _isSelected(dayNum);
                        final flights = !_hasCounts
                            ? null
                            : _flightsOn(
                                    DateTime(
                                      _viewMonth.year,
                                      _viewMonth.month,
                                      dayNum,
                                    ),
                                  ) >
                                  0
                            ? _flightsOn(
                                DateTime(
                                  _viewMonth.year,
                                  _viewMonth.month,
                                  dayNum,
                                ),
                              )
                            : null;
                        if (past) {
                          return Center(
                            child: Text(
                              '$dayNum',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.mutedForeground.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                          );
                        }
                        return GestureDetector(
                          key: ValueKey('calendar-day-$dayNum'),
                          onTap: () => setState(
                            () => _selected = DateTime(
                              _viewMonth.year,
                              _viewMonth.month,
                              dayNum,
                            ),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.accent
                                  : flights != null
                                  ? AppColors.secondary
                                  : AppColors.input,
                              borderRadius: BorderRadius.circular(10),
                              border: sel
                                  ? Border.all(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: sel
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 13,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.foreground,
                                  ),
                                ),
                                if (sel)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                else if (flights != null)
                                  Text(
                                    context.l10n.flightsShort(flights),
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 8,
                                      color: AppColors.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selected == null
                                  ? (widget.allowAnytime
                                        ? context.l10n.anyDate
                                        : context.l10n.selectADate)
                                  : '${DateFormat('EEE, MMMM d', _locale).format(_selected!)}'
                                        '${_hasCounts ? '  •  ${context.l10n.flightsCount(_flightsOn(_selected!))}' : ''}'
                                        '${_flexible ? '  •  ${context.l10n.plusMinus3Days}' : ''}',
                              key: const ValueKey('date-summary'),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        key: const ValueKey('date-confirm'),
                        onPressed: (_selected == null && !widget.allowAnytime)
                            ? null
                            : () => Navigator.of(context).pop(
                                DatePickerResult(
                                  _selected,
                                  _selected != null && _flexible,
                                ),
                              ),
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          _selected != null
                              ? context.l10n.confirmDateOn(
                                  DateFormat.MMMd(_locale).format(_selected!),
                                )
                              : (widget.allowAnytime
                                    ? context.l10n.confirmDateAnytime
                                    : context.l10n.selectADate),
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          disabledBackgroundColor: AppColors.muted,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.accent.withValues(alpha: 0.4),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
