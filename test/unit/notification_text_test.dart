import 'dart:io';

import 'package:carrywise_app/l10n/app_localizations_en.dart';
import 'package:carrywise_app/l10n/app_localizations_fr.dart';
import 'package:carrywise_app/l10n/notification_text.dart';
import 'package:carrywise_app/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification notification(String event) => AppNotification(
  id: 'n1',
  type: 'request',
  title: 'stored title',
  body: 'stored body',
  imageUrl: null,
  isRead: false,
  createdAt: DateTime(2026, 10, 25),
  payload: {
    'event': event,
    'sender': 'Amara',
    'traveler': 'Fortune',
    'route': 'Lagos → London',
  },
);

void main() {
  final en = AppLocalizationsEn();

  test('the sender hears their payment is secured', () {
    expect(notificationText(en, notification('payment_received')), (
      'Payment received',
      'Your payment is held safely until delivery. You can now chat with '
          'Fortune.',
    ));
    expect(requestsTabForEvent('payment_received'), 1);
  });

  test('the traveler hears the delivery is confirmed', () {
    expect(notificationText(en, notification('delivery_confirmed')), (
      'Delivery confirmed',
      "You delivered Amara's item. Your payout is on its way.",
    ));
    expect(requestsTabForEvent('delivery_confirmed'), 0);
  });

  test('in the user\'s language', () {
    expect(
      notificationText(
        AppLocalizationsFr(),
        notification('delivery_confirmed'),
      ).$1,
      'Livraison confirmée',
    );
  });

  test('pushes have the same words (texts.ts is up to date)', () {
    final ts = File('supabase/functions/send-push/texts.ts').readAsStringSync();
    for (final event in ['payment_received', 'delivery_confirmed']) {
      expect(RegExp('"$event"').allMatches(ts).length, 3, reason: event);
    }
    expect(ts, contains('"Paiement reçu"'));
  });
}
