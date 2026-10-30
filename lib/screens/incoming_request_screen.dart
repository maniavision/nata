import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/exchange_rate_service.dart';
import '../services/request_service.dart';
import '../services/traveler_service.dart' show TravelerReview, TravelerReviews;
import '../widgets/avatar_image.dart';
import '../widgets/nata_toast.dart';
import '../widgets/storage_photo.dart';

/// Accepting and declining a request, shared by the Incoming card and the
/// request details screen. Each returns true when the request changed.
class IncomingRequestActions {
  IncomingRequestActions._();

  static Future<bool> accept(
    BuildContext context,
    RequestService service,
    IncomingRequest request,
  ) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.accept(request.id);
      messenger.showSnackBar(
        nataToast(l.requestAcceptedSnack, tone: ToastTone.success),
      );
      return true;
    } on RequestException catch (e) {
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.rateUnavailable => l.errRateUnavailable,
          RequestFailure.tripFull => l.errTripFull,
          RequestFailure.senderOnTrip => l.errSenderOnTrip,
          RequestFailure.notPending => l.errRequestNotPending,
          RequestFailure.requestNotFound => l.errRequestNotFound,
          RequestFailure.notSignedIn => l.errSessionExpired,
          _ => l.errAcceptFailed,
        }, tone: ToastTone.error),
      );
      // Already answered or gone: the list should show what it is now.
      return e.reason == RequestFailure.notPending ||
          e.reason == RequestFailure.requestNotFound;
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errAcceptFailed, tone: ToastTone.error),
      );
      return false;
    }
  }

  static Future<bool> decline(
    BuildContext context,
    RequestService service,
    IncomingRequest request,
  ) async {
    final l = context.l10n;
    // The reason typed, or null if the traveler kept the request.
    final answer = await showDialog<({String reason})>(
      context: context,
      builder: (_) => const _DeclineDialog(),
    );
    if (answer == null || !context.mounted) return false;
    final reason = answer.reason;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.decline(request.id, reason: reason.isEmpty ? null : reason);
      messenger.showSnackBar(
        nataToast(l.requestDeclinedSnack, tone: ToastTone.success),
      );
      return true;
    } on RequestException catch (e) {
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.notPending => l.errRequestNotPending,
          RequestFailure.requestNotFound => l.errRequestNotFound,
          RequestFailure.notSignedIn => l.errSessionExpired,
          _ => l.errDeclineFailed,
        }, tone: ToastTone.error),
      );
      return e.reason == RequestFailure.notPending ||
          e.reason == RequestFailure.requestNotFound;
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errDeclineFailed, tone: ToastTone.error),
      );
      return false;
    }
  }
}

/// Asks before declining, with an optional reason. Pops the reason (possibly
/// empty), or null to keep the request.
class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog();

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      key: const ValueKey('decline-dialog'),
      title: Text(l.declineTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.declineBody),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('decline-reason'),
            controller: _reason,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(hintText: l.declineReasonHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('decline-keep'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.keepIt),
        ),
        TextButton(
          key: const ValueKey('decline-confirm'),
          onPressed: () =>
              Navigator.of(context).pop((reason: _reason.text.trim())),
          style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
          child: Text(l.decline),
        ),
      ],
    );
  }
}

/// Everything about a request made on one of the traveler's trips: the
/// sender, the items and their photos, the trip, the payout and the deadline.
/// A pending request is accepted or declined from here. Pops true when the
/// request changed.
class IncomingRequestScreen extends StatefulWidget {
  final IncomingRequest request;

  /// Shows the payout (stored in dollars) in the traveler's currency.
  final PriceFormatter money;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  /// Override for tests; defaults to [DateTime.now].
  final DateTime Function()? now;

  /// Override for tests: today's exchange rates, to compare the items'
  /// value with the traveler's carrying limit.
  final Future<ExchangeRates?> Function()? loadRates;

  const IncomingRequestScreen({
    super.key,
    required this.request,
    this.money = PriceFormatter.usd,
    this.service,
    this.now,
    this.loadRates,
  });

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen> {
  IncomingRequest get _r => widget.request;
  RequestService get _service => widget.service ?? RequestService();

  /// Links to the item photos, in order; null while loading.
  List<String>? _photoUrls;
  bool _busy = false;

  /// What other travelers said about the sender; null while loading or if
  /// they couldn't be loaded.
  TravelerReviews? _senderReviews;
  bool _senderReviewsLoading = true;

  /// The traveler's carrying limit and today's rates (20240194); null while
  /// loading or if they couldn't be loaded.
  CarryLimit? _limit;
  ExchangeRates? _rates;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _loadSenderReviews();
    _loadLimit();
  }

  Future<void> _loadLimit() async {
    final declared = declaredValue(_r.items);
    if (declared == null) return;
    try {
      final limit = await _service.myCarryLimit();
      if (mounted) setState(() => _limit = limit);
      // Values in another currency are compared in dollars.
      if (declared.currency == 'USD') return;
      final rates =
          await (widget.loadRates ?? ExchangeRateService.shared.rates)();
      if (mounted) setState(() => _rates = rates);
    } catch (e) {
      debugPrint('[IncomingRequest] carry limit: $e');
    }
  }

  /// The items' declared value in dollars, if it can be worked out.
  double? get _declaredUsd {
    final d = declaredValue(_r.items);
    if (d == null) return null;
    if (d.currency == 'USD') return d.total;
    final rate = _rates?.rateFor(d.currency);
    return rate == null || rate <= 0 ? null : d.total / rate;
  }

  Future<void> _loadSenderReviews() async {
    try {
      final reviews = await _service.listSenderReviews(_r.senderId);
      if (mounted) setState(() => _senderReviews = reviews);
    } catch (e) {
      debugPrint('[IncomingRequest] sender reviews: $e');
    } finally {
      if (mounted) setState(() => _senderReviewsLoading = false);
    }
  }

  Future<void> _loadPhotos() async {
    if (_r.photoPaths.isEmpty) {
      setState(() => _photoUrls = const []);
      return;
    }
    try {
      final urls = <String>[];
      for (final p in _r.photoPaths) {
        urls.add(await _service.photoUrl(p));
      }
      if (mounted) setState(() => _photoUrls = urls);
    } catch (e) {
      debugPrint('[IncomingRequest] photos: $e');
      if (mounted) setState(() => _photoUrls = const []);
    }
  }

  Future<void> _act(
    Future<bool> Function(BuildContext, RequestService, IncomingRequest) act,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final changed = await act(context, _service, _r);
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) Navigator.of(context).pop(true);
  }

  void _openPhoto(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image(image: StoragePhoto.provider(url)),
            ),
          ),
        ),
      ),
    );
  }

  String get _payoutText {
    final shown = widget.money.format(_r.payoutUsd);
    return widget.money.currency == 'USD' ? shown : '≈ $shown';
  }

  /// "23h 48m" left until [expiresAt]; null when there is none or it passed.
  String? _left(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final left = expiresAt.difference((widget.now ?? DateTime.now)());
    if (left.isNegative) return null;
    return context.l10n.hoursMinutes(left.inHours, left.inMinutes % 60);
  }

  String _categoryName(RequestCategory c) {
    final l = context.l10n;
    return switch (c) {
      RequestCategory.electronics => l.electronics,
      RequestCategory.apparel => l.apparel,
      RequestCategory.documents => l.documents,
    };
  }

  String _sizeName(RequestSizeClass c) {
    final l = context.l10n;
    return switch (c) {
      RequestSizeClass.envelope => l.sizeEnvelope,
      RequestSizeClass.shoebox => l.sizeShoebox,
      RequestSizeClass.backpack => l.sizeBackpack,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final left = _left(_r.expiresAt);
    final weight = NumberFormat('0.##', locale).format(_r.weightKg);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l.requestDetailsTitle,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (left != null) ...[
                    _banner(
                      _r.isPending
                          ? l.answerWithin(left)
                          : l.payDueWithin(left),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _card(
                    child: Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: AvatarImage(
                              path: _r.senderAvatarPath,
                              fallback: Container(
                                color: AppColors.secondary,
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _r.senderName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.foreground,
                                      ),
                                    ),
                                  ),
                                  if (_r.senderVerified) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      key: ValueKey('sender-verified'),
                                      size: 16,
                                      color: Color(0xFF168A68),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                l.senderDeliveries(_r.senderDeliveries),
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4F4EE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _payoutText,
                                key: const ValueKey('incoming-payout'),
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: const Color(0xFF168A68),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l.yourPayout,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _senderReviewsCard(),
                  const SizedBox(height: 12),
                  _card(
                    child: Column(
                      children: [
                        _row(l.tripLabel, _r.routeLabel),
                        _row(
                          l.travelDate,
                          DateFormat.yMMMd(locale).format(_r.departureDate),
                        ),
                        _row(
                          l.weightAndSize,
                          [
                            '$weight kg',
                            if (_r.sizeClass != null) _sizeName(_r.sizeClass!),
                            if (_r.dimensions != null) _r.dimensions!,
                          ].join(' · '),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionTitle(l.itemsTitle.toUpperCase()),
                  for (final item in _r.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                ),
                                Text(
                                  _categoryName(item.category),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                            if (item.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                            if (item.value != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                l.itemValueShort(
                                  PriceFormatter.write(
                                    item.value!,
                                    item.valueCurrency ?? 'USD',
                                  ),
                                ),
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ..._declaredValue(),
                  if (_r.photoPaths.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _sectionTitle(l.itemPhotosTitle),
                    _photos(),
                    const SizedBox(height: 12),
                  ],
                  _sectionTitle(l.recipientDetails.toUpperCase()),
                  _card(
                    child: _r.recipientName == null
                        ? Text(
                            l.recipientHiddenNote,
                            key: const ValueKey('recipient-hidden'),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          )
                        : Column(
                            children: [
                              _row(l.recipientNameLabel, _r.recipientName!),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            if (_r.isPending) _actions(),
          ],
        ),
      ),
    );
  }

  /// The items' total value, whether a receipt came with them, and a note
  /// when it's above the traveler's carrying limit (20240194).
  List<Widget> _declaredValue() {
    final l = context.l10n;
    final d = declaredValue(_r.items);
    if (d == null) return const [];
    final receipt = _r.items.any((i) => i.hasReceipt);
    final usd = _declaredUsd;
    final limit = _limit;
    final over = usd != null && limit != null && usd > limit.limitUsd;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.declaredValueRow(PriceFormatter.write(d.total, d.currency)),
                key: const ValueKey('incoming-declared-value'),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
            if (receipt) ...[
              const Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: Color(0xFF168A68),
              ),
              const SizedBox(width: 4),
              Text(
                l.itemReceiptAttached,
                key: const ValueKey('incoming-receipt'),
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: const Color(0xFF168A68),
                ),
              ),
            ],
          ],
        ),
      ),
      if (over)
        Container(
          key: const ValueKey('incoming-over-limit'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF0DC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFA86B12).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: Color(0xFFA86B12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.overCarryLimit(
                    limit.limitTextIn(
                      widget.money.currency,
                      ExchangeRateService.shared.latest ?? _rates,
                    ),
                  ),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _photos() {
    final urls = _photoUrls;
    if (urls == null) {
      return const SizedBox(
        height: 96,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          key: ValueKey('incoming-photo-$i'),
          onTap: () => _openPhoto(urls[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              color: AppColors.secondary,
              child: Image(
                image: StoragePhoto.provider(urls[i]),
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final l = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('incoming-decline'),
              onPressed: _busy
                  ? null
                  : () => _act(IncomingRequestActions.decline),
              icon: const Icon(Icons.cancel_rounded, size: 16),
              label: Text(l.decline),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              key: const ValueKey('incoming-accept'),
              onPressed: _busy
                  ? null
                  : () => _act(IncomingRequestActions.accept),
              icon: const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                l.acceptRequest,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text) => Container(
    key: const ValueKey('incoming-deadline'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3C7).withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.access_time_rounded,
          size: 18,
          color: Color(0xFFB45309),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: const Color(0xFF92400E),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Reviews from travelers ─────────────────────────────────────────────────
  static const _amber = Color(0xFFE5A83B);

  Widget _stars(double rating, {double size = 13}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var v = 1; v <= 5; v++)
        Icon(
          v <= rating.round() ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: v <= rating.round() ? _amber : AppColors.border,
        ),
    ],
  );

  /// The sender's rating as a sender and their latest reviews, or that they
  /// have none yet.
  Widget _senderReviewsCard() {
    final l = context.l10n;
    final reviews = _senderReviews?.reviews ?? const <TravelerReview>[];
    final total = _senderReviews?.total ?? 0;
    final rating =
        _r.senderRating ??
        (reviews.isEmpty
            ? null
            : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                  reviews.length);
    return Container(
      key: const ValueKey('sender-reviews'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 14, color: _amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.senderReviewsTitle.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              if (total > 0)
                Text(
                  l.reviewsCount(total),
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_senderReviewsLoading)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            )
          else if (reviews.isEmpty)
            Container(
              key: const ValueKey('sender-reviews-none'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rate_review_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.senderNoReviews,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.foreground,
                          ),
                        ),
                        Text(
                          l.senderNoReviewsSub,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (rating != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.senderRatingLabel.toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 1,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _stars(rating, size: 15),
                        ],
                      ),
                    ),
                    Text.rich(
                      key: const ValueKey('sender-rating'),
                      TextSpan(
                        text: rating.toStringAsFixed(1),
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.foreground,
                        ),
                        children: [
                          TextSpan(
                            text: ' · ${l.reviewsCount(total)}',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            for (var i = 0; i < reviews.length; i++) ...[
              if (i > 0) const Divider(height: 24, color: AppColors.border),
              _senderReviewTile(reviews[i]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _senderReviewTile(TravelerReview r) {
    final locale = Localizations.localeOf(context).toString();
    return Column(
      key: ValueKey('sender-review-${r.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.secondary,
              child: Text(
                r.initials,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.reviewerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.foreground,
                ),
              ),
            ),
            Text(
              DateFormat.yMMMd(locale).format(r.createdAt),
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _stars(r.rating.toDouble()),
            const SizedBox(width: 4),
            Text(
              r.rating.toStringAsFixed(1),
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            r.comment,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.2,
        color: AppColors.mutedForeground,
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    ),
  );
}
