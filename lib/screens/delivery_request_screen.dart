import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/city_service.dart';
import '../services/country_service.dart';
import '../services/delivery_pricing.dart';
import '../services/exchange_rate_service.dart';
import '../services/preferences_service.dart';
import '../services/request_service.dart';
import '../services/traveler_service.dart';
import '../services/trip_service.dart' show PickedReceipt;
import '../widgets/country_code_picker_sheet.dart' show flagEmoji;
import '../widgets/camera_denied_sheet.dart';
import '../widgets/one_line_text.dart';
import '../widgets/nata_toast.dart';
import '../widgets/traveler_photo.dart';

/// Takes or chooses an item photo. [camera] true = take it with the camera.
/// Replaceable in tests.
typedef RequestPhotoPicker =
    Future<PickedReceipt?> Function({required bool camera});

/// Ask a traveler to carry a parcel on one of their trips.
class DeliveryRequestScreen extends StatefulWidget {
  /// The trip (and traveler) the parcel is for.
  final TravelerTrip trip;

  /// Overrides for tests.
  final RequestService? service;
  final RequestPhotoPicker? photoPicker;
  final String Function()? idGenerator;
  final CityService? cityService;
  final ExchangeRateService? exchangeRates;
  final DateTime Function()? now;

  /// A pending request to edit: the form starts from it and saves changes to
  /// it instead of sending a new one. Pops with true once saved.
  final SentRequest? editing;

  const DeliveryRequestScreen({
    super.key,
    required this.trip,
    this.editing,
    this.service,
    this.photoPicker,
    this.idGenerator,
    this.cityService,
    this.exchangeRates,
    this.now,
  });

  @override
  State<DeliveryRequestScreen> createState() => _DeliveryRequestScreenState();
}

class _DeliveryRequestScreenState extends State<DeliveryRequestScreen> {
  static const _maxPhotos = 3;
  static const _maxPhotoBytes = 10 * 1024 * 1024;

  /// The items in the parcel; always at least one.
  final List<_ItemForm> _items = [_ItemForm(0)];
  int _nextItemId = 1;

  final _recipientNameCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();

  /// The trip's destination country: the recipient is there, so their phone
  /// number gets its dialling code. Null until loaded (or if unknown).
  Country? _recipientCountry;
  final _weightCtrl = TextEditingController();
  final _dimsCtrl = TextEditingController();

  RequestSizeClass? _sizeClass;
  final List<PickedReceipt> _photos = [];

  /// Editing: whether the photos differ from the request's (then they are
  /// uploaded again), and whether the current ones are still downloading.
  bool _photosChanged = false;
  bool _loadingPhotos = false;

  SentRequest? get _editing => widget.editing;

  bool _sending = false;
  String? _error;

  /// Created once for this screen. Retrying a failed send reuses it, so the
  /// database can never end up with two copies of the same request.
  late final String _requestId = (widget.idGenerator ?? generateUuidV4).call();

  TravelerTrip get _trip => widget.trip;

  static const _categoryIcons = {
    RequestCategory.electronics: Icons.devices_rounded,
    RequestCategory.apparel: Icons.checkroom_rounded,
    RequestCategory.documents: Icons.description_rounded,
  };

  // ── Price ──────────────────────────────────────────────────────────────────
  // The cost depends on the distance between the two cities, the weight and how
  // close the flight is. It is calculated in US dollars and shown in the
  // currency the user picked.

  /// Kilometres between the departure and arrival city (null until known).
  double? _distanceKm;
  bool _distanceFailed = false;

  /// Exchange rates (null until fetched, or when they cannot be had).
  ExchangeRates? _rates;
  bool _ratesDone = false;

  /// The currency the user picked in the app.
  final String _currency = PreferencesService().currency.code;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _loadDistance();
    _loadRates();
    _loadRecipientCountry();
    final editing = _editing;
    if (editing != null) _startFrom(editing);
  }

  /// Fills the form with the request being edited.
  void _startFrom(SentRequest r) {
    for (final item in _items) {
      item.dispose();
    }
    _items
      ..clear()
      ..addAll([
        for (final i in r.items)
          _ItemForm(_nextItemId++)
            ..name.text = i.name
            ..description.text = i.description
            ..value.text = i.value == null ? '' : _valueText(i.value!)
            ..keepsReceipt = i.hasReceipt
            ..category = i.category,
      ]);
    if (_items.isEmpty) _items.add(_ItemForm(_nextItemId++));
    _recipientNameCtrl.text = r.recipientName;
    _recipientPhoneCtrl.text = r.recipientPhone;
    _weightCtrl.text = r.weightKg.toString();
    _dimsCtrl.text = r.dimensions ?? '';
    _sizeClass = r.sizeClass;
    _loadPhotos(r);
  }

  Future<void> _loadPhotos(SentRequest r) async {
    if (r.photoPaths.isEmpty) return;
    setState(() => _loadingPhotos = true);
    try {
      final photos = await (widget.service ?? RequestService()).downloadPhotos(
        r.photoPaths,
      );
      if (!mounted || _photosChanged) return;
      setState(() => _photos.addAll(photos));
    } catch (e) {
      debugPrint('[DeliveryRequest] photos: $e');
    } finally {
      if (mounted) setState(() => _loadingPhotos = false);
    }
  }

  Future<void> _loadRecipientCountry() async {
    try {
      final country = await CountryService().byIsoCode(_trip.arrivalCountry);
      if (country != null && mounted) {
        setState(() => _recipientCountry = country);
      }
    } catch (e) {
      debugPrint('[DeliveryRequest] destination country: $e');
    }
  }

  /// The recipient's number in international format, with the destination
  /// country's code (or as typed with its own "+" code).
  String? get _recipientPhone {
    final country = _recipientCountry;
    return country == null
        ? RequestInput.normalizePhone(_recipientPhoneCtrl.text)
        : RequestInput.internationalPhone(
            country.phoneCode,
            _recipientPhoneCtrl.text,
          );
  }

  Future<void> _loadDistance() async {
    // (A retry clears the error; the first call comes from initState, where
    // setState is not allowed and there is nothing to clear.)
    if (_distanceFailed) setState(() => _distanceFailed = false);
    try {
      final cities = widget.cityService ?? CityService();
      final from = await cities.coordinates(
        _trip.departureCountry,
        _trip.departureCity,
      );
      final to = await cities.coordinates(
        _trip.arrivalCountry,
        _trip.arrivalCity,
      );
      if (!mounted) return;
      if (from == null || to == null) {
        setState(() => _distanceFailed = true);
        return;
      }
      setState(() {
        _distanceKm = DistanceCalculator.haversine(
          from.latitude,
          from.longitude,
          to.latitude,
          to.longitude,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _distanceFailed = true);
    }
  }

  Future<void> _loadRates() async {
    if (_currency == 'USD') {
      _ratesDone = true;
      return;
    }
    ExchangeRates? rates;
    try {
      rates = await (widget.exchangeRates ?? ExchangeRateService()).rates();
    } catch (_) {
      rates = null;
    }
    if (!mounted) return;
    setState(() {
      _rates = rates;
      _ratesDone = true;
    });
  }

  /// The weight typed so far; 0 until it is a valid weight.
  double get _weightKg => RequestInput.parseWeightKg(_weightCtrl.text) ?? 0;

  /// The price in US dollars, or null while the distance is unknown.
  DeliveryQuote? get _quote {
    final km = _distanceKm;
    if (km == null) return null;
    return DeliveryQuote.compute(
      distanceKm: km,
      departureDate: _trip.departureDate,
      now: _now(),
      weightKg: _weightKg,
    );
  }

  /// The rate for the user's currency, or null if it is not known.
  double? get _rate => _currency == 'USD' ? 1 : _rates?.rateFor(_currency);

  /// The price ready to show, or null while it is still being worked out.
  RequestPricing? get _pricing {
    final quote = _quote;
    if (quote == null || !_ratesDone) return null;
    final rate = _rate;
    // Without a rate the price is shown in dollars rather than guessed.
    return rate == null
        ? RequestPricing.forQuote(quote)
        : RequestPricing.forQuote(quote, currency: _currency, rate: rate);
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _recipientNameCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _weightCtrl.dispose();
    _dimsCtrl.dispose();
    super.dispose();
  }

  String _categoryName(RequestCategory c) {
    final l = context.l10n;
    switch (c) {
      case RequestCategory.electronics:
        return l.electronics;
      case RequestCategory.apparel:
        return l.apparel;
      case RequestCategory.documents:
        return l.documents;
    }
  }

  String _sizeName(RequestSizeClass c) {
    final l = context.l10n;
    switch (c) {
      case RequestSizeClass.envelope:
        return l.sizeEnvelope;
      case RequestSizeClass.shoebox:
        return l.sizeShoebox;
      case RequestSizeClass.backpack:
        return l.sizeBackpack;
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  // ── Items ──────────────────────────────────────────────────────────────────
  void _addItem() {
    if (_items.length >= RequestDraft.maxItems) return;
    setState(() {
      _items.add(_ItemForm(_nextItemId++));
      _error = null;
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
      _error = null;
    });
    // The field is still on screen for this frame; free it afterwards.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  // ── Photos ─────────────────────────────────────────────────────────────────
  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) {
      setState(() => _error = context.l10n.errPhotoLimit);
      return;
    }
    final camera = await _askCameraOrLibrary();
    if (camera == null || !mounted) return;
    await _pickPhotos(camera);
  }

  /// True for the camera, false for the library, null when closed.
  Future<bool?> _askCameraOrLibrary() => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('request-photo-camera'),
            leading: const Icon(
              Icons.photo_camera_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              ctx.l10n.takePhoto,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          ListTile(
            key: const ValueKey('request-photo-library'),
            leading: const Icon(
              Icons.photo_library_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              ctx.l10n.chatChoosePhoto,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Future<void> _pickPhotos(bool camera) async {
    try {
      final room = _maxPhotos - _photos.length;
      // From the library, several at once (up to the room left).
      final picked = widget.photoPicker == null && !camera && room > 1
          ? await _defaultMultiPicker(room)
          : [
              ?await (widget.photoPicker ?? _defaultPhotoPicker)(
                camera: camera,
              ),
            ];
      if (picked.isEmpty || !mounted) return;
      final fits = [
        for (final p in picked.take(room))
          if (p.sizeBytes <= _maxPhotoBytes) p,
      ];
      setState(() {
        _photos.addAll(fits);
        if (fits.isNotEmpty) _photosChanged = true;
        _error = fits.length < picked.take(room).length
            ? context.l10n.errPhotoTooBig
            : null;
      });
    } catch (e) {
      if (mounted && isCameraDenied(e)) {
        await showCameraDeniedSheet(context);
      } else if (mounted) {
        setState(() => _error = context.l10n.chatCameraFailed);
      }
    }
  }

  /// A receipt or listing photo for item [index] (20240194).
  Future<void> _addReceipt(int index) async {
    final camera = await _askCameraOrLibrary();
    if (camera == null || !mounted) return;
    try {
      final picked = await (widget.photoPicker ?? _defaultPhotoPicker)(
        camera: camera,
      );
      if (picked == null || !mounted) return;
      if (picked.sizeBytes > _maxPhotoBytes) {
        setState(() => _error = context.l10n.errPhotoTooBig);
        return;
      }
      setState(() {
        _items[index].receipt = picked;
        _error = null;
      });
    } catch (e) {
      if (mounted && isCameraDenied(e)) {
        await showCameraDeniedSheet(context);
      } else if (mounted) {
        setState(() => _error = context.l10n.chatCameraFailed);
      }
    }
  }

  void _removeReceipt(int index) => setState(() {
    _items[index]
      ..receipt = null
      ..keepsReceipt = false;
  });

  /// The currency item values are entered in: the request's own while
  /// editing, else the member's.
  String get _valueCurrency => _editing?.displayCurrency ?? _currency;

  static String _valueText(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// "450", "450.50" or "1,200" → 450.0 / 450.5 / 1200.0; null if it isn't
  /// an amount from 0 to 1,000,000.
  static double? _parseValue(String input) {
    final t = input.trim().replaceAll(RegExp(r'[\s,]'), '');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
    final v = double.tryParse(t);
    return v != null && v <= 1000000 ? v : null;
  }

  /// The items' total value while the form is filled in.
  double? get _declaredTotal {
    double total = 0;
    var any = false;
    for (final item in _items) {
      final v = _parseValue(item.value.text);
      if (v == null) continue;
      total += v;
      any = true;
    }
    return any ? total : null;
  }

  static Future<List<PickedReceipt>> _defaultMultiPicker(int limit) async {
    final photos = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
      limit: limit,
    );
    return [
      for (final photo in photos)
        PickedReceipt(
          bytes: await photo.readAsBytes(),
          name: photo.name.isEmpty ? 'photo.jpg' : photo.name,
          extension: photo.name.contains('.')
              ? photo.name.split('.').last.toLowerCase()
              : 'jpg',
        ),
    ];
  }

  static Future<PickedReceipt?> _defaultPhotoPicker({
    required bool camera,
  }) async {
    final photo = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (photo == null) return null;
    final name = photo.name.isEmpty ? 'photo.jpg' : photo.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    return PickedReceipt(
      bytes: await photo.readAsBytes(),
      name: name,
      extension: ext,
    );
  }

  // ── Validation + send ──────────────────────────────────────────────────────
  /// The first thing wrong with the form, or null when it can be sent.
  String? _validate() {
    final l = context.l10n;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].name.text.trim().isEmpty) {
        return _items.length == 1 ? l.errItemName : l.errItemNameN(i + 1);
      }
      if (_parseValue(_items[i].value.text) == null) {
        return _items.length == 1 ? l.errItemValue : l.errItemValueN(i + 1);
      }
    }
    if (_recipientNameCtrl.text.trim().length < 2) return l.errRecipientName;
    if (_recipientPhone == null) {
      return l.errRecipientPhone;
    }
    final weight = RequestInput.parseWeightKg(_weightCtrl.text);
    if (weight == null) return l.errWeight;
    final max = _trip.maxWeightKg;
    if (max != null && weight > max) {
      return l.errWeightTooHeavy(max.toStringAsFixed(1));
    }
    final size = _sizeClass;
    if (size == null) return l.errSizeRequired;
    if (!size.fitsIn(RequestSizeClass.fromTripSize(_trip.maxSize))) {
      return l.errSizeTooBig;
    }
    // While editing, the request's photos may still be downloading.
    if (_photos.isEmpty && !(_loadingPhotos && !_photosChanged)) {
      return l.errPhotoRequired;
    }
    return null;
  }

  /// The receipts picked in this visit, by item index.
  Map<int, PickedReceipt> get _pickedReceipts => {
    for (var i = 0; i < _items.length; i++)
      if (_items[i].receipt != null) i: _items[i].receipt!,
  };

  Future<void> _send() async {
    if (_sending) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final quote = _quote;
    if (quote == null) {
      setState(() => _error = context.l10n.errQuoteUnavailable);
      return;
    }

    final draft = RequestDraft(
      tripId: _trip.tripId,
      items: [
        for (final item in _items)
          RequestItem(
            name: item.name.text,
            category: item.category,
            description: item.description.text,
            value: _parseValue(item.value.text),
          ),
      ],
      weightKg: RequestInput.parseWeightKg(_weightCtrl.text)!,
      dimensions: _dimsCtrl.text,
      sizeClass: _sizeClass!,
      recipientName: _recipientNameCtrl.text,
      recipientPhone: _recipientPhone!,
      // Always in US dollars: that is what the database calculates and stores.
      expectedTotal: quote.totalUsd,
    );

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final service = widget.service ?? RequestService();
      final editing = _editing;
      if (editing != null) {
        await service.update(
          editing,
          draft,
          photos: _photosChanged ? List.of(_photos) : null,
          receipts: _pickedReceipts,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            nataToast(context.l10n.requestUpdated, tone: ToastTone.success),
          );
        Navigator.of(context).pop(true);
        return;
      }
      await service.send(
        _requestId,
        draft,
        List.of(_photos),
        receipts: _pickedReceipts,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          nataToast(context.l10n.requestSent, tone: ToastTone.success),
        );
      // Back to the start of the app: the request is on its way.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on RequestException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _messageFor(e.reason);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = context.l10n.errRequestFailed;
      });
    }
  }

  String _messageFor(RequestFailure reason) {
    final l = context.l10n;
    switch (reason) {
      case RequestFailure.notSignedIn:
        return l.errSessionExpired;
      case RequestFailure.tripUnavailable:
        return l.errTripUnavailable;
      case RequestFailure.notVerified:
        return l.errNotVerified;
      case RequestFailure.tripFull:
      case RequestFailure.senderOnTrip:
        return l.errTripFull;
      case RequestFailure.ownTrip:
        return l.errOwnTrip;
      case RequestFailure.weightTooHeavy:
        return l.errWeightTooHeavy((_trip.maxWeightKg ?? 0).toStringAsFixed(1));
      case RequestFailure.duplicate:
        return l.errDuplicate;
      case RequestFailure.destinationLimit:
        return l.errDestinationLimit(_trip.arrivalCity);
      case RequestFailure.priceChanged:
        return l.errPriceChanged;
      case RequestFailure.sizeTooBig:
        return l.errSizeTooBig;
      case RequestFailure.invalid:
        return l.errInvalidRequest;
      case RequestFailure.requestNotFound:
        return l.errRequestNotFound;
      case RequestFailure.notEditable:
        return l.errRequestNotEditable;
      case RequestFailure.rateUnavailable:
        return l.errRateUnavailable;
      case RequestFailure.notPending:
        return l.errRequestNotPending;
      case RequestFailure.notPayable:
        return l.errRequestNotPayable;
      case RequestFailure.notCancellable:
        return l.errNotCancellable;
      case RequestFailure.feeChanged:
        return l.errFeeChanged;
      case RequestFailure.itemValueInvalid:
        return l.errItemValue;
      case RequestFailure.notPaid:
      case RequestFailure.smsUnavailable:
      case RequestFailure.phoneRejected:
      case RequestFailure.amountOutOfBounds:
      case RequestFailure.networkUnavailable:
      case RequestFailure.tooSoon:
      case RequestFailure.alreadyReported:
      case RequestFailure.reportWindowClosed:
        return l.errRequestFailed;
      case RequestFailure.mobileMoneyUnavailable:
      case RequestFailure.methodNotOffered:
        return l.errMobileMoneyUnavailable;
      case RequestFailure.paymentsUnavailable:
        return l.errPaymentsUnavailable;
      case RequestFailure.notDelivered:
        return l.errNotDelivered;
      case RequestFailure.alreadyReviewed:
        return l.errAlreadyReviewed;
      case RequestFailure.balanceTooLow:
      case RequestFailure.other:
        return l.errRequestFailed;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 160),
                child: Column(
                  children: [
                    _buildTravelerSummary(),
                    const SizedBox(height: 16),
                    _buildItemRequirementBanner(),
                    const SizedBox(height: 16),
                    _buildItemsSection(),
                    const SizedBox(height: 16),
                    _buildRecipientCard(),
                    const SizedBox(height: 16),
                    _buildSizeWeightCard(),
                    const SizedBox(height: 16),
                    _buildPhotosCard(),
                    const SizedBox(height: 16),
                    _buildPricingCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildSendBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('request-back'),
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _editing == null
                  ? context.l10n.deliveryRequest
                  : context.l10n.editRequest,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Selected traveler ──────────────────────────────────────────────────────
  Widget _buildTravelerSummary() {
    final l = context.l10n;
    final max = _trip.maxWeightKg;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: TravelerPhoto(
              path: _trip.avatarPath,
              revealed: _trip.photoRevealed,
              size: 44,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.selectedTraveler,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  _trip.fullName,
                  key: const ValueKey('request-traveler-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  '${_trip.departureCity} → ${_trip.arrivalCity} · '
                  '${DateFormat('MMM d').format(_trip.departureDate)}',
                  key: const ValueKey('request-traveler-route'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (max != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l.travelerMaxKg(max.toStringAsFixed(1)),
                key: const ValueKey('request-max-chip'),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRequirementBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
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
                  context.l10n.itemRequirement,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.itemRequirementBody,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.foreground,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Items ──────────────────────────────────────────────────────────────────
  Widget _buildItemsSection() {
    final l = context.l10n;
    final atLimit = _items.length >= RequestDraft.maxItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.itemsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.itemsCount(_items.length),
                key: const ValueKey('request-item-count'),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _items.length; i++) ...[
          _buildItemCard(i),
          const SizedBox(height: 12),
        ],
        if (_declaredTotal case final total?)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.declaredValueTotal(
                      PriceFormatter.write(total, _valueCurrency),
                    ),
                    key: const ValueKey('request-declared-total'),
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (atLimit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              l.itemsMaxNote(RequestDraft.maxItems),
              key: const ValueKey('request-items-max'),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
          )
        else
          _buildAddItemButton(),
      ],
    );
  }

  Widget _buildAddItemButton() {
    return GestureDetector(
      key: const ValueKey('request-add-item'),
      onTap: _addItem,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.border,
          radius: 20,
          strokeWidth: 2,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.input,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.addAnotherItem,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final l = context.l10n;
    final item = _items[index];
    return KeyedSubtree(
      key: ValueKey('request-item-card-${item.id}'),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.itemNumber(index + 1).toUpperCase(),
                    key: ValueKey('request-item-title-$index'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (_items.length > 1)
                  GestureDetector(
                    key: ValueKey('request-item-remove-$index'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _removeItem(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 14,
                            color: AppColors.destructive,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.removeItem,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: AppColors.destructive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _fieldLabel(l.whatIsTheItem.toUpperCase()),
            const SizedBox(height: 6),
            _iconTextField(
              fieldKey: 'request-item-$index',
              icon: Icons.sell_rounded,
              controller: item.name,
              hint: l.itemNameHint,
              maxLength: 80,
              capitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),
            _fieldLabel(l.itemCategory.toUpperCase()),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final c in RequestCategory.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: c == RequestCategory.values.last ? 0 : 8,
                      ),
                      child: _categoryTile(index, c),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _fieldLabel(l.itemDescription.toUpperCase()),
            const SizedBox(height: 6),
            TextField(
              key: ValueKey('request-description-$index'),
              controller: item.description,
              maxLines: 3,
              minLines: 2,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _clearError(),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: l.itemDescHint,
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.mutedForeground,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.input,
                isDense: true,
                contentPadding: const EdgeInsets.all(12),
                border: _fieldBorder(),
                enabledBorder: _fieldBorder(),
                focusedBorder: _fieldBorder(focused: true),
              ),
            ),
            const SizedBox(height: 14),
            _fieldLabel('${l.itemValueLabel.toUpperCase()} *'),
            const SizedBox(height: 6),
            _buildValueField(index),
            const SizedBox(height: 6),
            Text(
              l.itemValueHelp,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 14),
            _fieldLabel(l.itemReceiptLabel.toUpperCase()),
            const SizedBox(height: 6),
            _buildReceiptTile(index),
          ],
        ),
      ),
    );
  }

  Widget _buildValueField(int index) {
    final item = _items[index];
    final currency = _valueCurrency;
    final symbol = AppCurrency.fromCode(currency).symbol;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            symbol,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: ValueKey('request-item-value-$index'),
              controller: item.value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(12),
              ],
              onChanged: (_) => setState(() => _error = null),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (currency != 'USD' && symbol != currency)
            Text(
              currency,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }

  /// An optional receipt or listing photo: a dashed tile to add one, or
  /// what was attached with ✕ to remove it.
  Widget _buildReceiptTile(int index) {
    final l = context.l10n;
    final item = _items[index];
    if (item.hasReceipt) {
      final picked = item.receipt;
      return Container(
        key: ValueKey('request-item-receipt-$index'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: picked != null
                    ? Image.memory(
                        picked.bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const _ReceiptIcon(),
                      )
                    : const _ReceiptIcon(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.itemReceiptAttached,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
            IconButton(
              key: ValueKey('request-item-receipt-remove-$index'),
              tooltip: l.remove,
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeReceipt(index),
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
    return GestureDetector(
      key: ValueKey('request-item-receipt-add-$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _addReceipt(index),
      child: CustomPaint(
        painter: const _DashedBorderPainter(
          color: AppColors.border,
          radius: 12,
          strokeWidth: 1.5,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 18,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.itemReceiptAdd,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(int index, RequestCategory c) {
    final active = _items[index].category == c;
    return GestureDetector(
      key: ValueKey('request-category-$index-${c.name}'),
      onTap: () => setState(() => _items[index].category = c),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _categoryIcons[c],
              size: 16,
              color: active ? Colors.white : AppColors.mutedForeground,
            ),
            const SizedBox(height: 3),
            Text(
              _categoryName(c),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
                color: active ? Colors.white : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recipient ──────────────────────────────────────────────────────────────
  Widget _buildRecipientCard() {
    final l = context.l10n;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.recipientDetails,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel(l.recipientName.toUpperCase()),
          const SizedBox(height: 6),
          _iconTextField(
            fieldKey: 'request-recipient-name',
            icon: Icons.person_rounded,
            controller: _recipientNameCtrl,
            hint: l.recipientNameHint,
            maxLength: 80,
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _fieldLabel(l.recipientPhone.toUpperCase()),
          const SizedBox(height: 6),
          Row(
            children: [
              // The destination country's code: where the recipient is.
              if (_recipientCountry != null) ...[
                Container(
                  key: const ValueKey('request-recipient-country'),
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.input,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        flagEmoji(_recipientCountry!.isoCode),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _recipientCountry!.phoneCode,
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _iconTextField(
                  fieldKey: 'request-recipient-phone',
                  icon: Icons.phone_rounded,
                  controller: _recipientPhoneCtrl,
                  hint: _recipientCountry == null
                      ? l.recipientPhoneHint
                      : l.recipientLocalPhoneHint,
                  keyboardType: TextInputType.phone,
                  maxLength: 24,
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-().\s]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.recipientPhoneNote,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          // Recipient consent for the delivery-code SMS (send-delivery-code).
          Text(
            l.recipientSmsConsent,
            key: const ValueKey('request-recipient-sms-consent'),
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  // ── Size and weight ────────────────────────────────────────────────────────
  Widget _buildSizeWeightCard() {
    final l = context.l10n;
    final max = _trip.maxWeightKg;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.sizeAndWeight,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(l.packageWeight.toUpperCase(), small: true),
                    const SizedBox(height: 6),
                    _iconTextField(
                      fieldKey: 'request-weight',
                      icon: Icons.scale_rounded,
                      controller: _weightCtrl,
                      hint: l.weightHint,
                      compact: true,
                      maxLength: 10,
                      onChangedExtra: () => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.travelerLimitLabel(
                        max == null ? '—' : '${max.toStringAsFixed(1)} kg',
                      ),
                      key: const ValueKey('request-weight-limit'),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel(l.packageDimensions.toUpperCase(), small: true),
                    const SizedBox(height: 6),
                    _iconTextField(
                      fieldKey: 'request-dimensions',
                      icon: Icons.inventory_2_outlined,
                      controller: _dimsCtrl,
                      hint: l.dimensionsHint,
                      compact: true,
                      maxLength: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.travelerLimitLabel(l.tripSize(_trip.maxSize)),
                      key: const ValueKey('request-size-limit'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel(l.packageSize.toUpperCase(), small: true),
          const SizedBox(height: 8),
          // Same height for all three, even when one name wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in RequestSizeClass.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: c == RequestSizeClass.values.last ? 0 : 8,
                      ),
                      child: _sizeTile(c),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizeTile(RequestSizeClass c) {
    final active = _sizeClass == c;
    final tooBig = !c.fitsIn(RequestSizeClass.fromTripSize(_trip.maxSize));
    return GestureDetector(
      key: ValueKey('request-size-${c.dbValue}'),
      onTap: () => setState(() {
        _sizeClass = c;
        _error = null;
      }),
      child: Opacity(
        opacity: tooBig ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.input,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            _sizeName(c),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10,
              color: active ? Colors.white : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }

  // ── Photos ─────────────────────────────────────────────────────────────────
  Widget _buildPhotosCard() {
    final l = context.l10n;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.itemPhotos,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.photosAttachedCount(_photos.length),
                key: const ValueKey('request-photo-count'),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < _photos.length; i++) _photoTile(i),
              if (_photos.length < _maxPhotos) _addPhotoTile(),
              if (_photos.length < _maxPhotos - 1) _sealHintTile(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoTile(int index) {
    return ClipRRect(
      key: ValueKey('request-photo-$index'),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _photos[index].bytes,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              color: AppColors.secondary,
              child: const Icon(
                Icons.image_outlined,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Container(
            color: AppColors.primary.withValues(alpha: 0.2),
            alignment: Alignment.center,
            child: const Icon(
              Icons.check_circle_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              key: ValueKey('request-photo-remove-$index'),
              onTap: () => setState(() {
                _photos.removeAt(index);
                _photosChanged = true;
                _error = null;
              }),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      key: const ValueKey('request-add-photo'),
      onTap: _addPhoto,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.input,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_rounded,
              size: 22,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.l10n.addPhoto,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sealHintTile() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              context.l10n.photoMustShowSeal,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 9,
                height: 1.2,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Price ──────────────────────────────────────────────────────────────────
  Widget _buildPricingCard() {
    final l = context.l10n;
    final p = _pricing;

    Widget line(String label, String value) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );

    final Widget body;
    if (_distanceFailed) {
      body = Column(
        children: [
          Text(
            l.errQuoteUnavailable,
            key: const ValueKey('request-quote-error'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          TextButton(
            key: const ValueKey('request-quote-retry'),
            onPressed: _loadDistance,
            child: Text(l.retry),
          ),
        ],
      );
    } else if (p == null) {
      body = Row(
        key: const ValueKey('request-price-loading'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              l.priceCalculating,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      );
    } else {
      final converted = p.currency != 'USD';
      final rates = _rates;
      body = Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.calculatedPrice,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.secondaryForeground,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                p.shownTotalText,
                key: const ValueKey('request-price-total'),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          line(l.priceBasedOn(_distanceKm!.round().toString()), p.costText),
          const SizedBox(height: 8),
          line(l.platformProtectionLine, p.feeText),
          if (_weightKg == 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.priceEnterWeight,
                key: const ValueKey('request-price-weight-hint'),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
          if (converted && rates != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.priceEstimateNote(p.currency),
                key: const ValueKey('request-price-estimate-note'),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryForeground,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.priceRateLine(
                  p.rate.toStringAsFixed(p.rate >= 100 ? 2 : 4),
                  p.currency,
                  DateFormat.MMMd(
                    Localizations.localeOf(context).toString(),
                  ).format(rates.updatedAt.toLocal()),
                ),
                key: const ValueKey('request-price-rate'),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.priceCredit,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
          if (_currency != 'USD' && rates == null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.priceRateUnavailable,
                key: const ValueKey('request-price-rate-missing'),
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppColors.destructive,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.priceNoteNothingCharged,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: body,
    );
  }

  // ── Send bar ───────────────────────────────────────────────────────────────
  Widget _buildSendBar(BuildContext context) {
    final l = context.l10n;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.95),
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  key: const ValueKey('request-error'),
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
                  key: const ValueKey('request-send'),
                  onPressed: (_sending || _pricing == null) ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                  label: Text(
                    _editing != null
                        ? (_pricing == null
                              ? l.saveChanges
                              : l.saveChangesWithPrice(
                                  _pricing!.shownTotalText,
                                ))
                        : _pricing == null
                        ? l.sendDeliveryRequest
                        : l.sendRequestWithPrice(_pricing!.shownTotalText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    elevation: 1,
                    shadowColor: const Color(0x33000000),
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

  // ── Shared pieces ──────────────────────────────────────────────────────────
  OutlineInputBorder _fieldBorder({bool focused = false}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: focused ? AppColors.ring.withValues(alpha: 0.4) : AppColors.border,
      width: focused ? 2 : 1,
    ),
  );

  // One line in every language, so side-by-side fields line up.
  Widget _fieldLabel(String text, {bool small = false}) => OneLineText(
    text,
    style: GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: small ? 10 : 11,
      letterSpacing: 1.3,
      color: AppColors.mutedForeground,
    ),
  );

  Widget _iconTextField({
    required String fieldKey,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    bool compact = false,
    int? maxLength,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    VoidCallback? onChangedExtra,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
      child: Row(
        children: [
          Icon(icon, size: compact ? 16 : 18, color: AppColors.primary),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: TextField(
              key: ValueKey(fieldKey),
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: capitalization,
              maxLength: maxLength,
              inputFormatters: formatters,
              onChanged: (_) {
                _clearError();
                onChangedExtra?.call();
              },
              style: GoogleFonts.dmSans(
                fontWeight: compact ? FontWeight.w700 : FontWeight.w600,
                fontSize: compact ? 12 : 13,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w500,
                  fontSize: compact ? 12 : 13,
                  color: AppColors.mutedForeground,
                ),
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: compact ? 12 : 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
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
      child: child,
    );
  }
}

/// What is typed for one item of the parcel.
class _ItemForm {
  _ItemForm(this.id);

  /// Never reused, so a card keeps its own state when another is removed.
  final int id;
  final name = TextEditingController();
  final description = TextEditingController();
  final value = TextEditingController();
  RequestCategory category = RequestCategory.electronics;

  /// A receipt or listing photo picked now, or (while editing) the one the
  /// item already has.
  PickedReceipt? receipt;
  bool keepsReceipt = false;

  bool get hasReceipt => receipt != null || keepsReceipt;

  void dispose() {
    name.dispose();
    description.dispose();
    value.dispose();
  }
}

/// A dashed rounded rectangle, for the "Add another item" button.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(strokeWidth / 2),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

/// A receipt without a picture to show (kept from before, or unreadable).
class _ReceiptIcon extends StatelessWidget {
  const _ReceiptIcon();

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.secondary,
    child: const Icon(
      Icons.receipt_long_rounded,
      size: 20,
      color: AppColors.primary,
    ),
  );
}
