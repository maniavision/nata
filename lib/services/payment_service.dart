import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

enum PaymentMethodKind {
  card('card'),
  mobileMoney('mobile_money'),
  applePay('apple_pay');

  const PaymentMethodKind(this.dbValue);

  /// What `payment_methods.kind` stores.
  final String dbValue;

  static PaymentMethodKind fromDb(String? value) =>
      values.firstWhere((k) => k.dbValue == value, orElse: () => card);
}

/// A saved way to pay (`nata.payment_methods`). Only what is safe to show is
/// kept: a card's brand and last 4 digits, never its number or CVV.
class PaymentMethod {
  /// Empty for a method not saved yet.
  final String id;
  final PaymentMethodKind kind;
  final bool isDefault;

  final String? cardBrand;
  final String? cardLast4;
  final int? cardExpMonth;
  final int? cardExpYear;
  final String? cardHolderName;

  final String? mobileProvider;

  /// International format, e.g. "+254712345678".
  final String? mobileNumber;
  final String? mobileRegisteredName;

  /// Apple Pay: the device it is set up on, e.g. "Fortune's iPhone".
  final String? walletDeviceLabel;

  const PaymentMethod({
    this.id = '',
    required this.kind,
    this.isDefault = false,
    this.cardBrand,
    this.cardLast4,
    this.cardExpMonth,
    this.cardExpYear,
    this.cardHolderName,
    this.mobileProvider,
    this.mobileNumber,
    this.mobileRegisteredName,
    this.walletDeviceLabel,
  });

  /// "Visa •••• 4242", "M-Pesa •••• 5678", "Apple Pay".
  String get title => switch (kind) {
    PaymentMethodKind.card => '$cardBrand •••• $cardLast4',
    PaymentMethodKind.mobileMoney =>
      '$mobileProvider •••• ${_last4(mobileNumber)}',
    PaymentMethodKind.applePay => 'Apple Pay',
  };

  static String _last4(String? s) {
    final v = s ?? '';
    return v.length <= 4 ? v : v.substring(v.length - 4);
  }

  /// "MM/YY" of a card's expiry.
  String get expiry =>
      '${(cardExpMonth ?? 0).toString().padLeft(2, '0')}/'
      '${((cardExpYear ?? 0) % 100).toString().padLeft(2, '0')}';

  /// "Expires 08/27", the registered name, or the device.
  String subtitle(AppLocalizations l) => switch (kind) {
    PaymentMethodKind.card => l.cardExpires(expiry),
    PaymentMethodKind.mobileMoney => mobileRegisteredName ?? '',
    PaymentMethodKind.applePay => walletDeviceLabel ?? '',
  };

  PaymentMethod copyWith({bool? isDefault}) => PaymentMethod(
    id: id,
    kind: kind,
    isDefault: isDefault ?? this.isDefault,
    cardBrand: cardBrand,
    cardLast4: cardLast4,
    cardExpMonth: cardExpMonth,
    cardExpYear: cardExpYear,
    cardHolderName: cardHolderName,
    mobileProvider: mobileProvider,
    mobileNumber: mobileNumber,
    mobileRegisteredName: mobileRegisteredName,
    walletDeviceLabel: walletDeviceLabel,
  );

  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
    id: j['id'] as String,
    kind: PaymentMethodKind.fromDb(j['kind'] as String?),
    isDefault: j['is_default'] as bool? ?? false,
    cardBrand: j['card_brand'] as String?,
    cardLast4: j['card_last4'] as String?,
    cardExpMonth: (j['card_exp_month'] as num?)?.toInt(),
    cardExpYear: (j['card_exp_year'] as num?)?.toInt(),
    cardHolderName: j['card_holder_name'] as String?,
    mobileProvider: j['mobile_provider'] as String?,
    mobileNumber: j['mobile_number'] as String?,
    mobileRegisteredName: j['mobile_registered_name'] as String?,
    walletDeviceLabel: j['wallet_device_label'] as String?,
  );

  /// The row to insert for [userId]: only the columns of this kind.
  Map<String, dynamic> toInsertJson(String userId) => {
    'user_id': userId,
    'kind': kind.dbValue,
    'is_default': isDefault,
    if (kind == PaymentMethodKind.card) ...{
      'card_brand': cardBrand,
      'card_last4': cardLast4,
      'card_exp_month': cardExpMonth,
      'card_exp_year': cardExpYear,
      'card_holder_name': cardHolderName?.trim(),
    },
    if (kind == PaymentMethodKind.mobileMoney) ...{
      'mobile_provider': mobileProvider,
      'mobile_number': mobileNumber,
      'mobile_registered_name': mobileRegisteredName?.trim(),
    },
    if (kind == PaymentMethodKind.applePay)
      'wallet_device_label': walletDeviceLabel,
  };
}

/// Where earnings are paid out (`nata.payout_accounts`).
enum PayoutAccountKind {
  bank,
  mobileMoney;

  static PayoutAccountKind fromDb(String? value) =>
      value == 'mobile_money' ? mobileMoney : bank;
}

class PayoutAccount {
  final String id;
  final PayoutAccountKind kind;
  final String institutionName;
  final String? countryCode;
  final String accountLast4;
  final String holderName;
  final bool isDefault;

  const PayoutAccount({
    required this.id,
    this.kind = PayoutAccountKind.bank,
    required this.institutionName,
    this.countryCode,
    required this.accountLast4,
    required this.holderName,
    this.isDefault = false,
  });

  /// "GB •••• 2093 · Fortune Niama".
  String get summary => [
    if (countryCode != null) '$countryCode ',
    '•••• $accountLast4 · $holderName',
  ].join();

  factory PayoutAccount.fromJson(Map<String, dynamic> j) => PayoutAccount(
    id: j['id'] as String,
    kind: PayoutAccountKind.fromDb(j['kind'] as String?),
    institutionName: j['institution_name'] as String,
    countryCode: (j['country_code'] as String?)?.trim(),
    accountLast4: j['account_last4'] as String,
    holderName: j['holder_name'] as String,
    isDefault: j['is_default'] as bool? ?? false,
  );
}

/// When earnings are paid out (`payment_preferences.payout_schedule`).
enum PayoutSchedule {
  automatic,
  weekly,
  manual;

  static PayoutSchedule fromDb(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => automatic);
}

/// Reads and saves the user's payment settings.
///
/// Needs `supabase/migrations/20240124_payment_settings.sql`. The database
/// keeps exactly one default method / payout account per user (the first one
/// added, or the last one marked default).
class PaymentService {
  final SupabaseClient _client;

  PaymentService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Not authenticated');
    return id;
  }

  SupabaseQueryBuilder _table(String name) => _client.schema('nata').from(name);

  /// The user's payment methods, oldest first.
  Future<List<PaymentMethod>> methods() async {
    final rows = await _table(
      'payment_methods',
    ).select().eq('user_id', _userId).order('created_at');
    return [for (final r in rows) PaymentMethod.fromJson(r)];
  }

  /// Saves [method] (built by the Add Payment Method screen); returns it as
  /// stored. Other methods may change too (the default), so callers reload.
  Future<PaymentMethod> addMethod(PaymentMethod method) async {
    final row = await _table(
      'payment_methods',
    ).insert(method.toInsertJson(_userId)).select().single();
    return PaymentMethod.fromJson(row);
  }

  Future<void> removeMethod(String id) async {
    await _table('payment_methods').delete().eq('id', id);
  }

  /// The user's payout accounts, oldest first.
  Future<List<PayoutAccount>> payoutAccounts() async {
    final rows = await _table(
      'payout_accounts',
    ).select().eq('user_id', _userId).order('created_at');
    return [for (final r in rows) PayoutAccount.fromJson(r)];
  }

  /// The payout schedule; automatic until the user changes it.
  Future<PayoutSchedule> payoutSchedule() async {
    final row = await _table(
      'payment_preferences',
    ).select('payout_schedule').eq('user_id', _userId).maybeSingle();
    return PayoutSchedule.fromDb(row?['payout_schedule'] as String?);
  }
}
