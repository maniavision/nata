import '../services/notification_service.dart';
import '../services/request_service.dart';
import 'app_localizations.dart';

/// A notification's title and body in the user's language, written from its
/// event and details. Notifications without a known event keep the text they
/// were stored with.
(String, String) notificationText(AppLocalizations l, AppNotification n) {
  final p = n.payload;
  String s(String key) => (p[key] as String?)?.trim() ?? '';
  final sender = s('sender');
  final traveler = s('traveler');
  final route = s('route');

  return switch (n.event) {
    'request_new' => (
      l.notifRequestNewTitle,
      l.notifRequestNewBody(sender, route),
    ),
    'request_accepted' => (l.notifAcceptedTitle, l.notifAcceptedBody(traveler)),
    'request_declined' => (
      l.notifDeclinedTitle,
      l.notifDeclinedBody(traveler, route),
    ),
    'request_expired_unanswered' => (
      l.notifExpiredTitle,
      l.notifExpiredUnansweredBody(traveler),
    ),
    'request_expired_unpaid' => (l.notifExpiredTitle, l.notifExpiredUnpaidBody),
    'request_expired_unpaid_traveler' => (
      l.notifExpiredTitle,
      l.notifExpiredUnpaidTravelerBody(sender),
    ),
    'request_cancelled_by_traveler' => (
      l.notifCancelledTitle,
      l.notifCancelledByTravelerBody(traveler),
    ),
    'request_cancelled_by_sender' => (
      l.notifCancelledTitle,
      l.notifCancelledBySenderBody(sender, route),
    ),
    'request_paid' => (l.notifPaidTitle, l.notifPaidBody(sender)),
    'trip_match' => (
      l.notifTripMatchTitle,
      l.notifTripMatchBody(traveler, route),
    ),
    'message_new' => (
      l.notifMessageTitle(s('author')),
      s('message').isEmpty && p['photo'] == true
          ? l.notifMessagePhotoBody
          : l.notifMessageBody(s('message')),
    ),
    'item_picked_up' => (l.notifPickedUpTitle, l.notifPickedUpBody(traveler)),
    'item_delivered' => (l.notifDeliveredTitle, l.notifDeliveredBody(traveler)),
    'payout_paid' => (
      l.notifPayoutTitle,
      l.notifPayoutBody(
        PriceFormatter.write(
          (p['amount'] as num?)?.toDouble() ?? 0,
          s('currency').toUpperCase(),
        ),
      ),
    ),
    'refund_sent' => (
      l.notifRefundTitle,
      l.notifRefundBody(
        PriceFormatter.write(
          (p['amount'] as num?)?.toDouble() ?? 0,
          s('currency').toUpperCase(),
        ),
      ),
    ),
    'identity_verified' => (l.notifVerifiedTitle, l.notifVerifiedBody),
    'identity_rejected' => (l.notifRejectedTitle, l.notifRejectedBody),
    'problem_reported' => (l.notifProblemTitle, l.notifProblemBody),
    _ => (n.title, n.body),
  };
}

/// The Requests tab a notification is about: 0 (Incoming, the traveler's
/// side) or 1 (Outgoing, the sender's side); null when it isn't about a
/// request.
int? requestsTabFor(AppNotification n) => requestsTabForEvent(n.event);

/// The same, from a notification's event (a tapped push carries only that).
int? requestsTabForEvent(String? event) => switch (event) {
  'request_new' ||
  'request_paid' ||
  'request_cancelled_by_sender' ||
  'request_expired_unpaid_traveler' ||
  'payout_paid' => 0,
  'request_accepted' ||
  'request_declined' ||
  'request_expired_unanswered' ||
  'request_expired_unpaid' ||
  'request_cancelled_by_traveler' ||
  'item_picked_up' ||
  'item_delivered' ||
  'refund_sent' => 1,
  _ => null,
};
