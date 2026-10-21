import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/request_service.dart';
import '../widgets/avatar_image.dart';
import '../widgets/nata_toast.dart';

/// The sender rates the traveler once they confirmed they received the item:
/// stars, what stood out, and a written review. Reviews are public as soon as
/// they are submitted. Pops true once a review was sent.
class ReviewScreen extends StatefulWidget {
  /// The delivered request being reviewed.
  final SentRequest request;

  /// Override for tests; defaults to the real [RequestService].
  final RequestService? service;

  const ReviewScreen({super.key, required this.request, this.service});

  /// What stood out, as the database stores it, in display order.
  static const tags = [
    'on_time',
    'communication',
    'careful',
    'flexible_pickup',
    'use_again',
  ];

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final Set<String> _tags = {};
  final _comment = TextEditingController();
  bool _sending = false;

  SentRequest get _r => widget.request;

  static const _green = Color(0xFF168A68);
  static const _greenBg = Color(0xFFE4F4EE);
  static const _amber = Color(0xFFE5A83B);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String _tagLabel(String tag) {
    final l = context.l10n;
    return switch (tag) {
      'on_time' => l.reviewTagOnTime,
      'communication' => l.tagCommunication,
      'careful' => l.tagCareful,
      'flexible_pickup' => l.tagFlexiblePickup,
      _ => l.reviewTagAgain,
    };
  }

  String _ratingLabel(int r) {
    final l = context.l10n;
    return switch (r) {
      1 => l.ratingPoor,
      2 => l.ratingFair,
      3 => l.ratingGood,
      4 => l.ratingGreat,
      5 => l.ratingExcellent,
      _ => l.tapStarToRate,
    };
  }

  /// "Amara K."
  String get _shortName {
    final last = _r.trip.lastName.trim();
    return last.isEmpty
        ? _r.trip.firstName
        : '${_r.trip.firstName} ${last[0].toUpperCase()}.';
  }

  Future<void> _submit() async {
    if (_rating == 0 || _sending) return;
    setState(() => _sending = true);
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await (widget.service ?? RequestService()).submitReview(
        _r.id,
        rating: _rating,
        tags: [
          for (final t in ReviewScreen.tags)
            if (_tags.contains(t)) t,
        ],
        comment: _comment.text,
      );
      messenger.showSnackBar(
        nataToast(l.reviewThanksName(_shortName), tone: ToastTone.success),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RequestException catch (e) {
      messenger.showSnackBar(
        nataToast(switch (e.reason) {
          RequestFailure.alreadyReviewed => l.errAlreadyReviewed,
          RequestFailure.notDelivered => l.errNotDelivered,
          RequestFailure.notSignedIn => l.errSessionExpired,
          _ => l.errReviewFailed,
        }, tone: ToastTone.error),
      );
      if (!mounted) return;
      setState(() => _sending = false);
      // Nothing more to send: leave.
      if (e.reason == RequestFailure.alreadyReviewed) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      messenger.showSnackBar(
        nataToast(l.errReviewFailed, tone: ToastTone.error),
      );
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l.rateYourTraveler,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: _green,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Delivery complete
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _greenBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.deliveryCompleteLabel,
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 1.1,
                            color: _green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.itemArrivedSafely,
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l.reviewHelpsOthers,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Traveler and delivery
            _card(
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AvatarImage(
                        path: _r.trip.avatarPath,
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
                                _shortName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.foreground,
                                ),
                              ),
                            ),
                            if (_r.travelerVerified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                key: ValueKey('review-traveler-verified'),
                                size: 15,
                                color: _green,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${_r.trip.departureCity} → ${_r.trip.arrivalCity} · '
                          '${DateFormat.MMMd(locale).format(_r.trip.departureDate)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        Text(
                          _r.itemsSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
            ),
            const SizedBox(height: 14),
            // Stars
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(l.overallRating),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var v = 1; v <= 5; v++)
                        Expanded(
                          child: IconButton(
                            key: ValueKey('review-star-$v'),
                            onPressed: _sending
                                ? null
                                : () => setState(() => _rating = v),
                            iconSize: 34,
                            tooltip: '$v',
                            icon: Icon(
                              Icons.star_rounded,
                              color: v <= _rating
                                  ? _amber
                                  : AppColors.mutedForeground.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Center(
                    child: Text(
                      _ratingLabel(_rating),
                      key: const ValueKey('review-rating-label'),
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: _rating == 0
                            ? AppColors.mutedForeground
                            : AppColors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // What stood out
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(l.whatStoodOut),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in ReviewScreen.tags)
                        _tagChip(tag, selected: _tags.contains(tag)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Written review
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(l.writtenReview),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('review-comment'),
                    controller: _comment,
                    maxLines: 4,
                    maxLength: 1000,
                    style: GoogleFonts.dmSans(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: l.reviewHint,
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                      filled: true,
                      fillColor: AppColors.input,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 12,
                        color: _green,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          l.reviewsFinal,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.reviewSharedNote(_r.trip.firstName),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                key: const ValueKey('review-submit'),
                onPressed: _rating == 0 || _sending ? null : _submit,
                icon: const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  l.submitReview,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.muted,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                key: const ValueKey('review-skip'),
                onPressed: _sending
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  l.skipForNow,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

  Widget _tagChip(String tag, {required bool selected}) {
    return GestureDetector(
      key: ValueKey('review-tag-$tag'),
      onTap: _sending
          ? null
          : () => setState(() => _tags.remove(tag) || _tags.add(tag)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.input,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          _tagLabel(tag),
          style: GoogleFonts.dmSans(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12,
            color: selected ? AppColors.primary : AppColors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _title(String text) => Text(
    text,
    style: GoogleFonts.dmSans(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 1.2,
      color: AppColors.mutedForeground,
    ),
  );
}
