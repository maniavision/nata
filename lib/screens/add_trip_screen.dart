import 'dart:async';
import '../services/ticket_check_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';
import '../services/preferences_service.dart';
import '../services/trip_service.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/location_search_sheet.dart';

/// Opens a location picker; replaceable in tests.
typedef LocationPicker =
    Future<LocationSelection?> Function(
      BuildContext context, {
      required String title,
      LocationSelection? initial,
    });

/// Lets the user choose a receipt file; replaceable in tests.
typedef ReceiptPicker = Future<PickedReceipt?> Function();

/// Takes a photo of the receipt with the camera; replaceable in tests.
typedef ReceiptCamera = Future<PickedReceipt?> Function();

/// Add a trip (or edit one when [trip] is given).
///
/// Pops with `true` after a successful save so the caller can refresh.
class AddTripScreen extends StatefulWidget {
  /// The trip to edit; null to create a new one.
  final Trip? trip;

  /// Overrides for tests. They default to the real services / pickers.
  final TripService? service;
  final LocationPicker? locationPicker;
  final ReceiptPicker? receiptPicker;
  final ReceiptCamera? receiptCamera;
  final TicketCheckService? ticketCheck;

  const AddTripScreen({
    super.key,
    this.trip,
    this.service,
    this.locationPicker,
    this.receiptPicker,
    this.receiptCamera,
    this.ticketCheck,
  });

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  // Route
  LocationSelection? _departure;
  LocationSelection? _arrival;
  DateTime? _depDate;
  DateTime? _arrDate;

  // Capacity
  late List<(String, double)> _weightOptions;
  late List<String> _sizeOptions;
  late String _maxWeightLabel;
  late String _maxSize;
  final _refCtrl = TextEditingController();
  late String _currency;

  // Receipt: a newly picked file, or the one already on file when editing.
  PickedReceipt? _receipt;
  String? _existingReceiptPath;

  bool _saving = false;

  /// The ticket is being read before saving.
  bool _checkingTicket = false;
  String? _error;

  static const _baseWeights = <(String, double)>[
    ('Up to 1.0 kg', 1.0),
    ('Up to 3.0 kg', 3.0),
    ('Up to 5.0 kg', 5.0),
    ('Up to 10.0 kg', 10.0),
  ];
  static const _baseSizes = <String>[
    'Envelope / Document',
    'Shoebox (30×20×15 cm)',
    'Backpack size',
  ];
  static const _maxReceiptBytes = 10 * 1024 * 1024;

  bool get _editing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    _weightOptions = [..._baseWeights];
    _sizeOptions = [..._baseSizes];
    _maxWeightLabel = _baseWeights[1].$1;
    _maxSize = _baseSizes[1];
    _currency = PreferencesService().currency.code;

    final t = widget.trip;
    if (t != null) _prefill(t);
  }

  void _prefill(Trip t) {
    LocationSelection sel(String country, String code, String city, int id) =>
        LocationSelection(
          country: country,
          countryCode: code,
          city: city,
          displayLabel: '$city, $country',
          cityId: id,
        );
    _departure = sel(
      t.departureCountry,
      t.departureCountryCode,
      t.departureCity,
      t.departureCityId,
    );
    _arrival = sel(
      t.arrivalCountry,
      t.arrivalCountryCode,
      t.arrivalCity,
      t.arrivalCityId,
    );
    _depDate = t.departureDate;
    _arrDate = t.arrivalDate;
    _currency = t.currency;
    _existingReceiptPath = t.ticketReceiptPath.isEmpty
        ? null
        : t.ticketReceiptPath;

    final w = t.maxWeightKg;
    if (w != null) {
      final match = _weightOptions.where((o) => o.$2 == w);
      if (match.isNotEmpty) {
        _maxWeightLabel = match.first.$1;
      } else {
        final label = 'Up to ${w.toStringAsFixed(1)} kg';
        _weightOptions.add((label, w));
        _maxWeightLabel = label;
      }
    }
    final size = t.maxSize;
    if (size != null && size.isNotEmpty) {
      if (!_sizeOptions.contains(size)) _sizeOptions.add(size);
      _maxSize = size;
    }
    _refCtrl.text = t.bookingReference ?? '';
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _departure = null;
      _arrival = null;
      _depDate = null;
      _arrDate = null;
      _receipt = null;
      _existingReceiptPath = null;
      _maxWeightLabel = _baseWeights[1].$1;
      _maxSize = _baseSizes[1];
      _refCtrl.clear();
      _error = null;
    });
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  Future<void> _pickLocation({
    required bool departure,
    required bool startAtCity,
  }) async {
    final current = departure ? _departure : _arrival;
    final picker = widget.locationPicker ?? _defaultLocationPicker;
    final result = await picker(
      context,
      title: departure ? context.l10n.departingFrom : context.l10n.arrivingIn,
      // The city field opens straight on that country's cities; the country
      // field starts from the country list.
      initial: startAtCity ? current : null,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (departure) {
        _departure = result;
      } else {
        _arrival = result;
      }
      _error = null;
    });
  }

  static Future<LocationSelection?> _defaultLocationPicker(
    BuildContext context, {
    required String title,
    LocationSelection? initial,
  }) => LocationSearchSheet.show(context, title: title, initial: initial);

  Future<void> _pickDate({required bool departure}) async {
    final today = DateTime.now();
    final result = await DatePickerSheet.show(
      context,
      title: departure
          ? context.l10n.departureDateTitle
          : context.l10n.arrivalDateTitle,
      initialDate: departure ? _depDate : _arrDate,
      // A trip cannot arrive before it departs.
      firstDate: departure
          ? DateTime(today.year, today.month, today.day)
          : (_depDate ?? DateTime(today.year, today.month, today.day)),
    );
    final picked = result?.date;
    if (picked == null || !mounted) return;
    setState(() {
      if (departure) {
        _depDate = picked;
        // Keep the arrival valid: default it to the departure day.
        if (_arrDate == null || _arrDate!.isBefore(picked)) _arrDate = picked;
      } else {
        _arrDate = picked;
      }
      _error = null;
    });
  }

  Future<void> _pickReceipt() async {
    try {
      final picked = await (widget.receiptPicker ?? _defaultReceiptPicker)();
      _acceptReceipt(picked);
    } catch (e) {
      debugPrint('[AddTrip] receipt picker error: $e');
      if (mounted) setState(() => _error = context.l10n.errOpenFile);
    }
  }

  /// "Take Photo": photograph the receipt with the camera.
  Future<void> _takePhoto() async {
    try {
      final photo = await (widget.receiptCamera ?? _defaultReceiptCamera)();
      _acceptReceipt(photo);
    } catch (e) {
      // Also covers a missing camera (simulator) and a denied permission.
      debugPrint('[AddTrip] camera error: $e');
      if (mounted) setState(() => _error = context.l10n.errCamera);
    }
  }

  /// Attaches [picked] as the receipt, unless it is missing or too large.
  void _acceptReceipt(PickedReceipt? picked) {
    if (picked == null || !mounted) return;
    if (picked.sizeBytes > _maxReceiptBytes) {
      setState(() => _error = context.l10n.errFileTooLarge);
      return;
    }
    setState(() {
      _receipt = picked;
      _error = null;
    });
  }

  static Future<PickedReceipt?> _defaultReceiptCamera() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (photo == null) return null;
    final name = photo.name.isEmpty ? 'receipt_photo.jpg' : photo.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return PickedReceipt(
      bytes: await photo.readAsBytes(),
      name: name,
      extension: ext,
    );
  }

  static Future<PickedReceipt?> _defaultReceiptPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes == null) return null;
    return PickedReceipt(
      bytes: file.bytes!,
      name: file.name,
      extension: (file.extension ?? 'jpg').toLowerCase(),
    );
  }

  // ── Validation + save ──────────────────────────────────────────────────────
  bool _sameCity(LocationSelection a, LocationSelection b) =>
      (a.cityId != null && a.cityId == b.cityId) ||
      (a.countryCode == b.countryCode && a.city == b.city);

  /// The first problem with the form, or null when it can be saved.
  String? _validate() {
    final l = context.l10n;
    if (_departure?.cityId == null) return l.errPickDeparture;
    if (_arrival?.cityId == null) return l.errPickArrival;
    if (_sameCity(_departure!, _arrival!)) return l.errSameCity;
    if (_depDate == null) return l.errPickDepDate;
    if (_arrDate == null) return l.errPickArrDate;
    if (_arrDate!.isBefore(_depDate!)) return l.errArrivalBeforeDeparture;
    if (_receipt == null && _existingReceiptPath == null) {
      return l.errAttachReceipt;
    }
    // The booking reference is optional, but if given it must be valid.
    final ref = _bookingReference;
    if (ref != null && !TripDraft.bookingReferencePattern.hasMatch(ref)) {
      return l.errBookingReference;
    }
    return null;
  }

  /// Whether the booking reference card is shown: until both countries are
  /// picked, and then for every trip except a domestic one within Africa or
  /// South America.
  bool get _asksForBookingReference {
    final from = _departure?.countryCode;
    final to = _arrival?.countryCode;
    if (from == null || to == null) return true;
    return TripDraft.asksForBookingReference(from, to);
  }

  /// What is saved: the typed reference, or null when there is none or the
  /// card is hidden (what was typed is kept in case the route changes back).
  String? get _bookingReference {
    if (!_asksForBookingReference) return null;
    final ref = _refCtrl.text.trim();
    return ref.isEmpty ? null : ref;
  }

  Future<void> _save() async {
    if (_saving) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    TripService? service;
    String? uploadedPath;
    try {
      service = widget.service ?? TripService();

      // The ticket must be the traveler's, for this trip's dates.
      final ticketProblem = await _checkTicket(service);
      if (ticketProblem != null) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = ticketProblem;
        });
        return;
      }

      var receiptPath = _existingReceiptPath ?? '';
      if (_receipt != null) {
        uploadedPath = await service.uploadReceipt(_receipt!);
        receiptPath = uploadedPath;
      }

      final draft = TripDraft(
        departureCityId: _departure!.cityId!,
        arrivalCityId: _arrival!.cityId!,
        departureDate: _depDate!,
        arrivalDate: _arrDate!,
        // Prices come from the pricing formula, not from the traveler. The
        // column is still required: 0 for new trips, unchanged on edits.
        price: widget.trip?.price ?? 0,
        currency: _currency,
        maxWeightKg: _weightOptions
            .firstWhere((o) => o.$1 == _maxWeightLabel)
            .$2,
        maxSize: _maxSize,
        ticketReceiptPath: receiptPath,
        bookingReference: _bookingReference,
      );

      if (_editing) {
        await service.updateTrip(widget.trip!.id, draft);
        // The old receipt is no longer referenced once a new one replaced it.
        if (uploadedPath != null) {
          unawaited(service.deleteReceipt(widget.trip!.ticketReceiptPath));
        }
      } else {
        await service.createTrip(draft);
      }

      if (!mounted) return;
      final l = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? l.tripUpdated : l.tripSubmitted)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[AddTrip] save failed: $e');
      // Do not leave an orphaned upload behind.
      if (uploadedPath != null) unawaited(service?.deleteReceipt(uploadedPath));
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.errSaveFailed;
      });
    }
  }

  /// Reads the ticket and checks the traveler's name and the trip's dates are
  /// on it. Returns what is wrong, or null when it is fine (or can't be
  /// checked). A ticket already on file is checked again only when the dates
  /// changed.
  Future<String?> _checkTicket(TripService service) async {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    Uint8List? bytes;
    var fileName = '';
    final picked = _receipt;
    if (picked != null) {
      bytes = picked.bytes;
      fileName = picked.name;
    } else {
      final old = widget.trip;
      final path = _existingReceiptPath;
      final datesChanged =
          old != null &&
          (!_sameDay(old.departureDate, _depDate!) ||
              !_sameDay(old.arrivalDate, _arrDate!));
      if (path == null || !datesChanged) return null;
      try {
        bytes = await service.downloadReceipt(path);
        fileName = path;
      } catch (e) {
        // Can't fetch it: don't block the edit over it.
        debugPrint('[AddTrip] could not fetch the ticket to check it: $e');
        return null;
      }
    }

    setState(() => _checkingTicket = true);
    try {
      final result = await (widget.ticketCheck ?? TicketCheckService()).check(
        bytes: bytes,
        fileName: fileName,
        departure: _depDate!,
        arrival: _arrDate!,
      );
      return switch (result) {
        TicketCheckResult.nameMismatch => l.errTicketNameMismatch,
        TicketCheckResult.dateMismatch => l.errTicketDateMismatch(
          DateFormat.yMMMMd(locale).format(_depDate!),
        ),
        TicketCheckResult.unreadable => l.errTicketUnreadable,
        TicketCheckResult.passed || TicketCheckResult.unverifiable => null,
      };
    } catch (e) {
      debugPrint('[AddTrip] ticket check failed: $e');
      return null;
    } finally {
      if (mounted) setState(() => _checkingTicket = false);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                child: Column(
                  children: [
                    _buildHeroBanner(),
                    const SizedBox(height: 16),
                    _buildDepartureCard(),
                    const SizedBox(height: 16),
                    _buildArrivalCard(),
                    const SizedBox(height: 16),
                    _buildTicketCard(),
                    const SizedBox(height: 16),
                    if (_asksForBookingReference) ...[
                      _buildBookingReferenceCard(),
                      const SizedBox(height: 16),
                    ],
                    _buildCapacityCard(),
                    const SizedBox(height: 16),
                    _buildInfoBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildSaveBar(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _editing ? context.l10n.editTrip : context.l10n.addATripTitle,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('add-trip-clear'),
            onTap: _clear,
            child: Text(
              context.l10n.clear,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Decorative blur circle
          Positioned(
            right: -24,
            bottom: -24,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Traveler mode pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.send,
                            size: 11,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            context.l10n.travelerMode,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1.4,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.headingSomewhere,
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.luggageEarnings,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.backpack_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Departure card ─────────────────────────────────────────────────────────
  Widget _buildDepartureCard() {
    return _FormCard(
      child: Column(
        children: [
          _cardHeader(
            icon: Icons.location_on_outlined,
            label: context.l10n.departureDetailsTitle,
            iconColor: AppColors.primary,
            labelColor: AppColors.primary,
            badge: context.l10n.from,
          ),
          const SizedBox(height: 14),
          _pickerField(
            fieldKey: 'add-trip-departure-date',
            label: context.l10n.departureDate,
            icon: Icons.calendar_today_rounded,
            iconColor: AppColors.primary,
            value: _depDate == null ? null : _fmtDate(_depDate!),
            hint: context.l10n.selectDate,
            onTap: () => _pickDate(departure: true),
            fullWidth: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _pickerField(
                  fieldKey: 'add-trip-departure-country',
                  label: context.l10n.departureCountryLabel,
                  icon: Icons.language_rounded,
                  iconColor: AppColors.primary,
                  value: _departure?.country,
                  hint: context.l10n.selectCountry,
                  onTap: () =>
                      _pickLocation(departure: true, startAtCity: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickerField(
                  fieldKey: 'add-trip-departure-city',
                  label: context.l10n.departureCityLabel,
                  icon: Icons.location_city_rounded,
                  iconColor: AppColors.primary,
                  value: _departure?.city,
                  hint: context.l10n.selectCity,
                  onTap: () => _pickLocation(
                    departure: true,
                    startAtCity: _departure != null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Arrival card ───────────────────────────────────────────────────────────
  Widget _buildArrivalCard() {
    return _FormCard(
      child: Column(
        children: [
          _cardHeader(
            icon: Icons.location_on,
            label: context.l10n.arrivalDetailsTitle,
            iconColor: AppColors.accent,
            labelColor: AppColors.accent,
            badge: context.l10n.to,
          ),
          const SizedBox(height: 14),
          _pickerField(
            fieldKey: 'add-trip-arrival-date',
            label: context.l10n.arrivalDate,
            icon: Icons.calendar_today_rounded,
            iconColor: AppColors.accent,
            value: _arrDate == null ? null : _fmtDate(_arrDate!),
            hint: context.l10n.selectDate,
            onTap: () => _pickDate(departure: false),
            fullWidth: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _pickerField(
                  fieldKey: 'add-trip-arrival-country',
                  label: context.l10n.arrivalCountryLabel,
                  icon: Icons.language_rounded,
                  iconColor: AppColors.accent,
                  value: _arrival?.country,
                  hint: context.l10n.selectCountry,
                  onTap: () =>
                      _pickLocation(departure: false, startAtCity: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _pickerField(
                  fieldKey: 'add-trip-arrival-city',
                  label: context.l10n.arrivalCityLabel,
                  icon: Icons.location_city_rounded,
                  iconColor: AppColors.accent,
                  value: _arrival?.city,
                  hint: context.l10n.selectCity,
                  onTap: () => _pickLocation(
                    departure: false,
                    startAtCity: _arrival != null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Ticket card ────────────────────────────────────────────────────────────
  Widget _buildTicketCard() {
    final hasReceipt = _receipt != null || _existingReceiptPath != null;
    final fileName =
        _receipt?.name ??
        (_existingReceiptPath == null
            ? ''
            : _existingReceiptPath!.split('/').last);
    final detail = _receipt != null
        ? '${_fmtSize(_receipt!.sizeBytes)}  '
        : '${context.l10n.receiptOnFile}  ';

    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                Icons.confirmation_num_rounded,
                context.l10n.flightTicket,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.flightTicketSub,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasReceipt) ...[
            Container(
              key: const ValueKey('add-trip-receipt-card'),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6EE).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.6),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF168A68),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              detail,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            Text(
                              '✓ ${context.l10n.attached}',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: const Color(0xFF168A68),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    key: const ValueKey('add-trip-remove-receipt'),
                    onTap: () => setState(() {
                      _receipt = null;
                      _existingReceiptPath = null;
                    }),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Take Photo (filled) and Upload File (outlined), side by side.
          Row(
            children: [
              Expanded(
                child: _receiptButton(
                  key: 'add-trip-take-photo',
                  icon: Icons.photo_camera_rounded,
                  label: context.l10n.takePhoto,
                  onTap: _takePhoto,
                  filled: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _receiptButton(
                  key: 'add-trip-upload-receipt',
                  icon: Icons.upload_rounded,
                  label: context.l10n.uploadFile,
                  onTap: _pickReceipt,
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptButton({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    final fg = filled ? AppColors.primaryForeground : AppColors.primary;
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.input,
          borderRadius: BorderRadius.circular(12),
          // Both buttons carry a 1px border so they are exactly the same height.
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Booking reference card ─────────────────────────────────────────────────
  Widget _buildBookingReferenceCard() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.bookmark_rounded,
            context.l10n.bookingReference.toUpperCase(),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.bookingReferenceSub,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.tag_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('add-trip-booking-reference'),
                    controller: _refCtrl,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [_BookingReferenceFormatter()],
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.44,
                      color: AppColors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.bookingRefHint,
                      hintStyle: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0,
                        color: AppColors.mutedForeground,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
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

  // ── Capacity card ──────────────────────────────────────────────────────────
  Widget _buildCapacityCard() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            Icons.inventory_2_outlined,
            context.l10n.luggageCapacity,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  fieldKey: 'add-trip-weight',
                  label: context.l10n.maxWeight.toUpperCase(),
                  value: _maxWeightLabel,
                  options: _weightOptions.map((o) => o.$1).toList(),
                  // Shown in the app's language; the English label is only
                  // used to find the weight.
                  display: (o) => context.l10n.upToKg(
                    _weightOptions
                        .firstWhere((w) => w.$1 == o)
                        .$2
                        .toStringAsFixed(1),
                  ),
                  onChanged: (v) =>
                      setState(() => _maxWeightLabel = v ?? _maxWeightLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  fieldKey: 'add-trip-size',
                  label: context.l10n.maxItemSize.toUpperCase(),
                  value: _maxSize,
                  options: _sizeOptions,
                  // Saved in English (the database reads it), shown translated.
                  display: context.l10n.tripSize,
                  onChanged: (v) => setState(() => _maxSize = v ?? _maxSize),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String fieldKey,
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String Function(String option)? display,
  }) {
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
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.input,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey(fieldKey),
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.foreground,
              ),
              dropdownColor: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        display?.call(o) ?? o,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: AppColors.foreground,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ── Info banner ────────────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF168A68).withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: Color(0xFF168A68),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.howMatchingWorks,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: const Color(0xFF168A68),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.howMatchingBody,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fixed save bar ─────────────────────────────────────────────────────────
  Widget _buildSaveBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: AppColors.background.withValues(alpha: 0.95),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  key: const ValueKey('add-trip-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
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
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const ValueKey('add-trip-save'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    _checkingTicket
                        ? context.l10n.checkingTicket
                        : _editing
                        ? context.l10n.saveChanges
                        : context.l10n.saveAndPublish,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.accent.withValues(alpha: 0.35),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  /// A small uppercase card title with an icon. The text wraps (up to two
  /// lines) instead of overflowing, which matters for long translations on
  /// narrow phones.
  Widget _sectionTitle(
    IconData icon,
    String text, {
    Color iconColor = AppColors.primary,
    Color color = AppColors.foreground,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.4,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardHeader({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color labelColor,
    required String badge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _sectionTitle(
            icon,
            label.toUpperCase(),
            iconColor: iconColor,
            color: labelColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  /// A tappable field that shows [value] (or [hint] while empty).
  Widget _pickerField({
    required String fieldKey,
    required String label,
    required IconData icon,
    required Color iconColor,
    required String? value,
    required String hint,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final hasValue = value != null && value.isNotEmpty;
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
        const SizedBox(height: 5),
        GestureDetector(
          key: ValueKey(fieldKey),
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.input,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: fullWidth ? 14 : 10,
              vertical: fullWidth ? 11 : 10,
            ),
            child: Row(
              children: [
                Icon(icon, size: fullWidth ? 18 : 16, color: iconColor),
                SizedBox(width: fullWidth ? 10 : 8),
                Expanded(
                  child: Text(
                    hasValue ? value : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                      color: hasValue
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      DateFormat.yMMMMd(Localizations.localeOf(context).toString()).format(d);

  String _fmtSize(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).clamp(0.1, double.infinity).toStringAsFixed(1)} KB';
}

/// Keeps a booking reference valid as the user types: letters and digits only,
/// upper case, at most 8 characters (what `trips_booking_reference_check`
/// accepts).
class _BookingReferenceFormatter extends TextInputFormatter {
  static final _invalid = RegExp(r'[^A-Z0-9]');

  String _clean(String text) => text.toUpperCase().replaceAll(_invalid, '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var cleaned = _clean(newValue.text);
    if (cleaned.length > 8) cleaned = cleaned.substring(0, 8);
    if (cleaned == newValue.text) return newValue;

    // Keep the cursor after the same characters it followed before cleaning.
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final offset = _clean(
      newValue.text.substring(0, cursor),
    ).length.clamp(0, cleaned.length);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

// ── Shared card wrapper ────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
