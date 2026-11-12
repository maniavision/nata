import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n_ext.dart';
import '../main.dart';
import '../services/market_service.dart';
import 'nata_toast.dart';
import 'traveler_photo.dart';

/// Under the sender's request (one item or a bundle): a switch that shows it
/// on the Parcel Market, and the travelers' offers to carry it, to accept or
/// decline (migration 20240213). Nothing shows when it can't be loaded.
class MarketOffersPanel extends StatefulWidget {
  final String groupId;
  final MarketService? service;

  /// An offer was accepted: [requestId] is the new request, to pay for.
  final ValueChanged<String> onAccepted;

  const MarketOffersPanel({
    super.key,
    required this.groupId,
    this.service,
    required this.onAccepted,
  });

  @override
  State<MarketOffersPanel> createState() => _MarketOffersPanelState();
}

class _MarketOffersPanelState extends State<MarketOffersPanel> {
  MarketService get _service => widget.service ?? MarketService();

  MarketListingState? _state;
  List<MarketOffer> _offers = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await _service.listing(widget.groupId);
      final offers = state == null
          ? const <MarketOffer>[]
          : await _service.offers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _state = state;
        _offers = offers;
      });
    } catch (e) {
      debugPrint('[MarketOffers] load: $e');
    }
  }

  Future<void> _setListed(bool listed) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await _service.setListed(widget.groupId, listed);
    } catch (e) {
      debugPrint('[MarketOffers] list: $e');
      messenger.showSnackBar(
        nataToast(l.marketErrListing, tone: ToastTone.error),
      );
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _accept(MarketOffer o) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final requestId = await _service.acceptOffer(o.id);
      messenger.showSnackBar(
        nataToast(l.marketOfferAcceptedToast, tone: ToastTone.success),
      );
      widget.onAccepted(requestId);
    } on MarketException catch (e) {
      messenger.showSnackBar(
        nataToast(
          e.reason == MarketFailure.tripFull
              ? l.marketErrTripFull
              : e.reason == MarketFailure.other
              ? l.marketErrListing
              : l.marketErrOfferGone,
          tone: ToastTone.error,
        ),
      );
    } catch (e) {
      debugPrint('[MarketOffers] accept: $e');
      messenger.showSnackBar(
        nataToast(l.marketErrListing, tone: ToastTone.error),
      );
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _decline(MarketOffer o) async {
    setState(() {
      _busy = true;
      _offers = _offers.where((x) => x.id != o.id).toList();
    });
    try {
      await _service.declineOffer(o.id);
    } catch (e) {
      debugPrint('[MarketOffers] decline: $e');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) return const SizedBox.shrink();
    final l = context.l10n;
    return Container(
      key: ValueKey('market-panel-${widget.groupId}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
              const Icon(
                Icons.storefront_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.marketShowOn,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      l.marketShowOnSub,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: ValueKey('market-switch-${widget.groupId}'),
                value: state.listed,
                activeThumbColor: AppColors.accent,
                onChanged: _busy ? null : _setListed,
              ),
            ],
          ),
          if (_offers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l.marketOffersTitle,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.mutedForeground,
              ),
            ),
            for (final o in _offers)
              _OfferRow(
                offer: o,
                busy: _busy,
                onAccept: () => _accept(o),
                onDecline: () => _decline(o),
              ),
          ],
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  final MarketOffer offer;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferRow({
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final date = offer.departureDate;
    final rating = offer.rating;
    return Padding(
      key: ValueKey('market-offer-row-${offer.id}'),
      padding: const EdgeInsets.only(top: 10, right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TravelerPhoto(
                path: offer.avatarPath,
                revealed: offer.photoRevealed,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            offer.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        if (offer.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      [
                        if (date != null) DateFormat.MMMd(locale).format(date),
                        if (rating != null && rating > 0)
                          '★ ${rating.toStringAsFixed(1)}',
                        l.marketDelivered(offer.itemsDelivered),
                      ].join(' · '),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: FilledButton(
                    key: ValueKey('market-accept-${offer.id}'),
                    onPressed: busy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentForeground,
                      shape: const StadiumBorder(),
                      textStyle: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    child: Text(l.marketAcceptOffer),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: ValueKey('market-decline-${offer.id}'),
                onPressed: busy ? null : onDecline,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                ),
                child: Text(l.marketDeclineOffer),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
