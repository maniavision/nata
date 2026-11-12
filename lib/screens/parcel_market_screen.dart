import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/market_service.dart';
import '../widgets/nata_toast.dart';
import '../widgets/traveler_photo.dart';
import 'route_alerts_screen.dart' show formatKg;

/// The Parcel Market (migration 20240213): items senders want to send on the
/// routes of the traveler's live trips. The traveler offers to carry one and
/// the sender decides. Built from the app's existing cards (Sleek was signed
/// out when it was made).
class ParcelMarketScreen extends StatefulWidget {
  final MarketService? service;

  /// Whether the traveler has a live trip; false shows how to get one.
  final bool hasLiveTrip;

  const ParcelMarketScreen({super.key, this.service, this.hasLiveTrip = true});

  @override
  State<ParcelMarketScreen> createState() => _ParcelMarketScreenState();
}

class _ParcelMarketScreenState extends State<ParcelMarketScreen> {
  MarketService get _service => widget.service ?? MarketService();

  List<MarketListing> _items = const [];
  bool _loading = true;
  bool _failed = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _service.listings();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _failed = false;
      });
    } catch (e) {
      debugPrint('[Market] load: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _error(MarketFailure f) {
    final l = context.l10n;
    return switch (f) {
      MarketFailure.closed => l.marketErrClosed,
      MarketFailure.offerLimit => l.marketErrLimit,
      MarketFailure.alreadyOffered => l.marketErrAlready,
      MarketFailure.tripFull => l.marketErrTripFull,
      MarketFailure.tripDoesNotFit => l.marketErrTrip,
      MarketFailure.offerGone => l.marketErrClosed,
      MarketFailure.other => l.marketErrFailed,
    };
  }

  Future<void> _offer(MarketListing item) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.foreground.withValues(alpha: 0.45),
      builder: (_) => _OfferSheet(item: item),
    );
    if (confirmed != true || !mounted) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(item.groupId));
    try {
      final outcome = await _service.offer(item.groupId, item.tripId);
      messenger.showSnackBar(
        nataToast(
          outcome == OfferOutcome.accepted
              ? l.marketAcceptedToast
              : l.marketOfferedToast,
          tone: ToastTone.success,
        ),
      );
    } on MarketException catch (e) {
      messenger.showSnackBar(
        nataToast(_error(e.reason), tone: ToastTone.error),
      );
    } catch (e) {
      debugPrint('[Market] offer: $e');
      messenger.showSnackBar(
        nataToast(l.marketErrFailed, tone: ToastTone.error),
      );
    }
    if (mounted) setState(() => _busy.remove(item.groupId));
    _load();
  }

  Future<void> _withdraw(MarketListing item) async {
    final id = item.myOfferId;
    if (id == null) return;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(item.groupId));
    try {
      await _service.withdraw(id);
    } catch (e) {
      debugPrint('[Market] withdraw: $e');
      messenger.showSnackBar(
        nataToast(l.marketErrFailed, tone: ToastTone.error),
      );
    }
    if (mounted) setState(() => _busy.remove(item.groupId));
    _load();
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
                    key: const ValueKey('market-back'),
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
                      l.parcelMarket,
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
              l.marketLoadFailed,
              key: const ValueKey('market-error'),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            l.marketIntro,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.5,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 18),
          if (_items.isEmpty)
            _empty()
          else
            for (final item in _items)
              _ListingCard(
                item: item,
                busy: _busy.contains(item.groupId),
                onOffer: () => _offer(item),
                onWithdraw: () => _withdraw(item),
              ),
        ],
      ),
    );
  }

  Widget _empty() {
    final l = context.l10n;
    final noTrip = !widget.hasLiveTrip;
    return Container(
      key: const ValueKey('market-empty'),
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
            child: Icon(
              noTrip ? Icons.flight_takeoff_rounded : Icons.inventory_2_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            noTrip ? l.marketNoTripTitle : l.marketEmptyTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            noTrip ? l.marketNoTripBody : l.marketEmptyBody,
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

/// One item on the market: the sender (public name, blurred photo), the
/// item and its route, how many travelers were asked and offered, and the
/// traveler's action.
class _ListingCard extends StatelessWidget {
  final MarketListing item;
  final bool busy;
  final VoidCallback onOffer;
  final VoidCallback onWithdraw;

  const _ListingCard({
    required this.item,
    required this.busy,
    required this.onOffer,
    required this.onWithdraw,
  });

  Widget _chip(String text, {Color? fg, Color? bg, Key? key, IconData? icon}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg ?? AppColors.primary),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rating = item.senderRating;
    return Container(
      key: ValueKey('market-item-${item.groupId}'),
      margin: const EdgeInsets.only(bottom: 12),
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
            children: [
              TravelerPhoto(path: item.senderAvatar, revealed: false, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.senderName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        if (item.senderVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            key: ValueKey('market-sender-verified'),
                            size: 15,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    if (rating != null && rating > 0)
                      Text(
                        '★ ${rating.toStringAsFixed(1)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.itemName,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.fromCity} → ${item.toCity} · ${l.marketItems(item.itemCount)} · ${formatKg(item.weightKg)} kg',
            key: ValueKey('market-route-${item.groupId}'),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                l.marketAsked(item.pendingRequests),
                key: ValueKey('market-asked-${item.groupId}'),
                icon: Icons.send_rounded,
              ),
              if (item.offers > 0)
                _chip(
                  l.marketOffered(item.offers),
                  key: ValueKey('market-offers-${item.groupId}'),
                  icon: Icons.back_hand_rounded,
                ),
              if (item.restricted)
                _chip(
                  l.marketRestricted,
                  key: ValueKey('market-restricted-${item.groupId}'),
                  icon: Icons.info_outline_rounded,
                  fg: const Color(0xFFB45309),
                  bg: const Color(0xFFFEF3C7),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (item.offered)
            Row(
              children: [
                Expanded(
                  child: _chip(
                    l.marketOfferSent,
                    key: ValueKey('market-offer-sent-${item.groupId}'),
                    icon: Icons.check_circle_rounded,
                    fg: const Color(0xFF168A68),
                    bg: const Color(0xFFE4F4EE),
                  ),
                ),
                TextButton(
                  key: ValueKey('market-withdraw-${item.groupId}'),
                  onPressed: busy ? null : onWithdraw,
                  child: Text(l.marketWithdraw),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                key: ValueKey('market-offer-${item.groupId}'),
                onPressed: busy ? null : onOffer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(
                  item.requested ? l.marketAcceptRequest : l.marketOffer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Confirms an offer: what happens next, and a word on restricted items.
class _OfferSheet extends StatelessWidget {
  final MarketListing item;

  const _OfferSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      key: const ValueKey('market-offer-sheet'),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottom),
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
            const SizedBox(height: 20),
            Text(
              item.requested ? l.marketAcceptRequest : l.marketOfferTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.requested
                  ? l.marketOfferRequestedBody(item.senderName)
                  : l.marketOfferBody(item.senderName),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            if (item.restricted) ...[
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('market-restricted-note'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  l.marketRestrictedNote,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey('market-offer-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.accentForeground,
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                child: Text(
                  item.requested ? l.marketAcceptRequest : l.marketSendOffer,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('market-offer-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
              ),
              child: Text(l.notNow),
            ),
          ],
        ),
      ),
    );
  }
}
