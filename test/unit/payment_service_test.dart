import 'package:carrywise_app/l10n/app_localizations_en.dart';
import 'package:carrywise_app/services/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Client extends Mock implements SupabaseClient {}

class _Functions extends Mock implements FunctionsClient {}

void main() {
  final l = AppLocalizationsEn();

  group('PaymentMethod', () {
    test('reads a card row', () {
      final m = PaymentMethod.fromJson({
        'id': 'a',
        'kind': 'card',
        'is_default': true,
        'card_brand': 'Visa',
        'card_last4': '4242',
        'card_exp_month': 8,
        'card_exp_year': 2027,
        'card_holder_name': 'Fortune Niama',
      });
      expect(m.kind, PaymentMethodKind.card);
      expect(m.isDefault, isTrue);
      expect(m.title, 'Visa •••• 4242');
      expect(m.subtitle(l), 'Expires 08/27');
    });

    test('mobile money and Apple Pay titles', () {
      final mobile = PaymentMethod.fromJson({
        'id': 'b',
        'kind': 'mobile_money',
        'mobile_provider': 'M-Pesa',
        'mobile_number': '+254712345678',
        'mobile_registered_name': 'Fortune Niama',
      });
      expect(mobile.title, 'M-Pesa •••• 5678');
      expect(mobile.subtitle(l), 'Fortune Niama');

      final apple = PaymentMethod.fromJson({
        'id': 'c',
        'kind': 'apple_pay',
        'wallet_device_label': "Fortune's iPhone",
      });
      expect(apple.title, 'Apple Pay');
      expect(apple.subtitle(l), "Fortune's iPhone");
    });

    test('a card row has only card columns, and no card number', () {
      const m = PaymentMethod(
        kind: PaymentMethodKind.card,
        cardBrand: 'Visa',
        cardLast4: '4242',
        cardExpMonth: 8,
        cardExpYear: 2027,
        cardHolderName: ' Fortune Niama ',
      );
      expect(m.toInsertJson('u1'), {
        'user_id': 'u1',
        'kind': 'card',
        'is_default': false,
        'card_brand': 'Visa',
        'card_last4': '4242',
        'card_exp_month': 8,
        'card_exp_year': 2027,
        'card_holder_name': 'Fortune Niama',
      });
    });

    test('a mobile money row has only mobile money columns', () {
      const m = PaymentMethod(
        kind: PaymentMethodKind.mobileMoney,
        isDefault: true,
        mobileProvider: 'Orange Money',
        mobileNetwork: 'ORANGE_SEN',
        mobileNumber: '+221771234567',
        mobileRegisteredName: 'Awa Diop',
      );
      expect(m.toInsertJson('u1'), {
        'user_id': 'u1',
        'kind': 'mobile_money',
        'is_default': true,
        'mobile_provider': 'Orange Money',
        'mobile_network': 'ORANGE_SEN',
        'mobile_number': '+221771234567',
        'mobile_registered_name': 'Awa Diop',
      });
    });
  });

  test('PayoutAccount summary', () {
    final a = PayoutAccount.fromJson({
      'id': 'p',
      'institution_name': 'Barclays Bank',
      'country_code': 'GB',
      'account_last4': '2093',
      'holder_name': 'Fortune Niama',
      'is_default': true,
    });
    expect(a.summary, 'GB •••• 2093 · Fortune Niama');
  });

  test('PayoutSchedule from the database, automatic by default', () {
    expect(PayoutSchedule.fromDb('weekly'), PayoutSchedule.weekly);
    expect(PayoutSchedule.fromDb(null), PayoutSchedule.automatic);
    expect(PayoutSchedule.fromDb('???'), PayoutSchedule.automatic);
  });

  group('the bank through Stripe (stripe-connect)', () {
    late _Client client;
    late _Functions functions;
    late PaymentService service;
    final sent = <Map<String, dynamic>>[];

    setUp(() {
      client = _Client();
      functions = _Functions();
      sent.clear();
      when(() => client.functions).thenReturn(functions);
      service = PaymentService(client: client);
    });

    void answer(Map<String, dynamic> data) =>
        when(
          () => functions.invoke('stripe-connect', body: any(named: 'body')),
        ).thenAnswer((inv) async {
          sent.add(Map<String, dynamic>.from(inv.namedArguments[#body] as Map));
          return FunctionResponse(data: data, status: 200);
        });

    test('start gives Stripe\'s page', () async {
      answer({'url': 'https://connect.stripe.com/setup/e/abc'});
      final link = await service.stripeBankLink();
      expect(sent.single, {'action': 'start'});
      expect(link, Uri.parse('https://connect.stripe.com/setup/e/abc'));
    });

    test('enabled comes with the payout account it became', () async {
      answer({
        'status': 'enabled',
        'account': {
          'id': 'pa1',
          'kind': 'bank',
          'institution_name': 'Barclays',
          'country_code': 'GB',
          'account_last4': '2345',
          'holder_name': 'Amara Kalu',
          'is_default': true,
        },
      });
      final bank = await service.stripeBankStatus();
      expect(sent.single, {'action': 'status'});
      expect(bank.status, StripeBankStatus.enabled);
      expect(bank.account?.institutionName, 'Barclays');
      expect(bank.account?.accountLast4, '2345');
    });

    test('pending and none have no account', () async {
      answer({'status': 'pending'});
      expect(
        (await service.stripeBankStatus()).status,
        StripeBankStatus.pending,
      );
      answer({'status': 'none'});
      final none = await service.stripeBankStatus();
      expect(none.status, StripeBankStatus.none);
      expect(none.account, isNull);
    });

    test('a country Stripe can\'t pay out to is notSupported', () async {
      when(
        () => functions.invoke('stripe-connect', body: any(named: 'body')),
      ).thenThrow(
        const FunctionException(
          status: 409,
          details: {'error': 'not_supported'},
        ),
      );
      expect(
        service.stripeBankLink(),
        throwsA(
          isA<PayoutAccountException>().having(
            (e) => e.reason,
            'reason',
            PayoutAccountFailure.notSupported,
          ),
        ),
      );
    });
  });
}
