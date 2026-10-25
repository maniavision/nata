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

  /// The wallet's pawaPay network (provider code, e.g. MTN_MOMO_COG); null
  /// for wallets saved before networks came from pawaPay.
  final String? mobileNetwork;

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
    this.mobileNetwork,
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
    mobileNetwork: mobileNetwork,
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
    mobileNetwork: j['mobile_network'] as String?,
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
      'mobile_network': mobileNetwork,
      'mobile_number': mobileNumber,
      'mobile_registered_name': mobileRegisteredName?.trim(),
    },
    if (kind == PaymentMethodKind.applePay)
      'wallet_device_label': walletDeviceLabel,
  };
}

/// What a member can save as payment methods, from where they live
/// (my_payment_options, 20240174): mobile money wallets on their country's
/// pawaPay networks when they live in such a country, else cards and Apple
/// Pay.
class PaymentOptions {
  final String countryCode;
  final String countryName;

  /// "+242"
  final String dialCode;
  final bool mobileMoney;

  /// (code, name) of the country's networks, in the order to show them.
  final List<({String code, String name})> networks;

  const PaymentOptions({
    required this.countryCode,
    required this.countryName,
    required this.dialCode,
    required this.mobileMoney,
    this.networks = const [],
  });

  /// Somewhere without mobile money: cards and Apple Pay.
  static const cards = PaymentOptions(
    countryCode: '',
    countryName: '',
    dialCode: '',
    mobileMoney: false,
  );

  factory PaymentOptions.fromJson(Map<String, dynamic> j) => PaymentOptions(
    countryCode: (j['country_code'] as String? ?? '').trim(),
    countryName: (j['country_name'] as String? ?? '').trim(),
    dialCode: (j['dial_code'] as String? ?? '').trim(),
    mobileMoney: j['mobile_money'] == true,
    networks: [
      for (final n in (j['networks'] as List? ?? const []))
        (code: '${(n as Map)['code']}', name: '${n['name']}'),
    ],
  );
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

/// A bank or mobile money network Nata pays out to, with its code (pawaPay's
/// provider code for mobile money).
class PayoutProvider {
  final String code;
  final String name;
  const PayoutProvider(this.code, this.name);

  factory PayoutProvider.fromJson(Map<String, dynamic> j) =>
      PayoutProvider('${j['code']}', '${j['name']}');
}

/// Where a traveler in a country can be paid (payout-options).
class PayoutOptions {
  final String? currency;
  final List<PayoutProvider> banks;
  final List<PayoutProvider> mobileMoney;

  const PayoutOptions({
    this.currency,
    this.banks = const [],
    this.mobileMoney = const [],
  });

  bool get isEmpty => banks.isEmpty && mobileMoney.isEmpty;

  factory PayoutOptions.fromJson(Map<String, dynamic> j) => PayoutOptions(
    currency: j['currency'] as String?,
    banks: [
      for (final b in (j['banks'] as List? ?? const []))
        PayoutProvider.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
    mobileMoney: [
      for (final m in (j['mobile_money'] as List? ?? const []))
        PayoutProvider.fromJson(Map<String, dynamic>.from(m as Map)),
    ],
  );
}

/// Why saving a payout account failed.
enum PayoutAccountFailure {
  invalid,
  notSupported,

  /// Not the traveler's country of residence.
  countryMismatch,
  unavailable,
  other,
}

/// Where a traveler's bank stands with Stripe (stripe-connect, 20240170):
/// not started, Stripe's form not finished, Stripe checking it, or paid to.
enum StripeBankStatus { none, incomplete, pending, enabled }

/// The bank Stripe pays out to: its name and last digits.
typedef StripeConnectedBank = ({String institution, String last4});

/// [status]; once [StripeBankStatus.enabled], the [bank] connected and the
/// payout account it is (null while it isn't one of the traveler's payout
/// accounts, e.g. after they removed it).
typedef StripeBank = ({
  StripeBankStatus status,
  PayoutAccount? account,
  StripeConnectedBank? bank,
});

class PayoutAccountException implements Exception {
  final PayoutAccountFailure reason;
  const PayoutAccountException(this.reason);
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
  /// What the member can save, from where they live; cards and Apple Pay
  /// for a member without a country of residence.
  Future<PaymentOptions> paymentOptions() async {
    final rows = await _client.rpc('my_payment_options') as List;
    if (rows.isEmpty) return PaymentOptions.cards;
    return PaymentOptions.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<PaymentMethod> addMethod(PaymentMethod method) async {
    final row = await _table(
      'payment_methods',
    ).insert(method.toInsertJson(_userId)).select().single();
    return PaymentMethod.fromJson(row);
  }

  Future<void> removeMethod(String id) async {
    await _table('payment_methods').delete().eq('id', id);
  }

  /// Removes a payout account. Payouts waiting for it go to the default
  /// account instead; removing the default makes the latest other one the
  /// default (20240171).
  Future<void> removePayoutAccount(String id) async {
    await _table('payout_accounts').delete().eq('id', id);
  }

  /// The user's payout accounts, oldest first.
  Future<List<PayoutAccount>> payoutAccounts() async {
    final rows = await _table(
      'payout_accounts',
    ).select().eq('user_id', _userId).order('created_at');
    return [for (final r in rows) PayoutAccount.fromJson(r)];
  }

  /// The banks and mobile money a traveler in [country] can be paid to.
  Future<PayoutOptions> payoutOptions(String country) async {
    final response = await _client.functions.invoke(
      'payout-options',
      body: {'country': country},
    );
    return PayoutOptions.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Saves a payout account (add-payout-account): the full number stays on
  /// the server, only the last 4 digits come back.
  Future<PayoutAccount> addPayoutAccount({
    required PayoutAccountKind kind,
    required String country,
    required PayoutProvider provider,
    required String accountNumber,
    required String holderName,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'add-payout-account',
        body: {
          'kind': kind == PayoutAccountKind.mobileMoney
              ? 'mobile_money'
              : 'bank',
          'country': country,
          'bank_code': provider.code,
          'institution_name': provider.name,
          'account_number': accountNumber,
          'holder_name': holderName,
        },
      );
      return PayoutAccount.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['error']}' : '';
      throw PayoutAccountException(switch (code) {
        'invalid' => PayoutAccountFailure.invalid,
        'not_supported' => PayoutAccountFailure.notSupported,
        'country_mismatch' => PayoutAccountFailure.countryMismatch,
        'payments_unavailable' => PayoutAccountFailure.unavailable,
        _ => PayoutAccountFailure.other,
      });
    }
  }

  /// Stripe's page where the traveler connects their bank (their Stripe
  /// account is made the first time). Travelers living where Stripe can't
  /// pay out get [PayoutAccountFailure.notSupported].
  Future<Uri> stripeBankLink() async {
    final data = await _stripeConnect('start');
    return Uri.parse(data['url'] as String);
  }

  /// Where the traveler's bank stands with Stripe; once Stripe pays out to
  /// it, it is one of their payout accounts.
  /// Where the bank through Stripe stands. [save] adds the connected bank
  /// as a payout account ("Use this bank"); it is otherwise added by itself
  /// only the first time (20240172).
  Future<StripeBank> stripeBankStatus({bool save = false}) async {
    final data = await _stripeConnect('status', save: save);
    final account = data['account'];
    final bank = data['bank'];
    return (
      status: switch (data['status']) {
        'enabled' => StripeBankStatus.enabled,
        'pending' => StripeBankStatus.pending,
        'incomplete' => StripeBankStatus.incomplete,
        _ => StripeBankStatus.none,
      },
      account: account is Map
          ? PayoutAccount.fromJson(Map<String, dynamic>.from(account))
          : null,
      bank: bank is Map
          ? (
              institution: '${bank['institution_name'] ?? ''}',
              last4: '${bank['account_last4'] ?? ''}',
            )
          : null,
    );
  }

  Future<Map<String, dynamic>> _stripeConnect(
    String action, {
    bool save = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'stripe-connect',
        body: {'action': action, if (save) 'save': true},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['error']}' : '';
      throw PayoutAccountException(switch (code) {
        'not_supported' => PayoutAccountFailure.notSupported,
        'payments_unavailable' => PayoutAccountFailure.unavailable,
        _ => PayoutAccountFailure.other,
      });
    }
  }

  /// Sends the traveler's pending payouts (send-payouts). Returns how many
  /// were sent; the rest wait for a payout account or failed.
  Future<int> sendPayouts() async {
    final response = await _client.functions.invoke('send-payouts');
    return ((response.data as Map?)?['sent'] as num?)?.toInt() ?? 0;
  }

  /// The user's payouts and payments, newest first (wallet_history,
  /// 20240141_wallet_history.sql).
  Future<List<WalletEntry>> walletHistory({int limit = 100}) async {
    final rows =
        await _client.rpc('wallet_history', params: {'p_limit': limit})
            as List<dynamic>;
    return [
      for (final r in rows)
        WalletEntry.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// The payout schedule; automatic until the user changes it.
  Future<PayoutSchedule> payoutSchedule() async {
    final row = await _table(
      'payment_preferences',
    ).select('payout_schedule').eq('user_id', _userId).maybeSingle();
    return PayoutSchedule.fromDb(row?['payout_schedule'] as String?);
  }
}

/// What a wallet history row is about.
enum WalletEntryKind { payout, payment }

/// Where a wallet history row stands, as the app shows it.
enum WalletEntryStatus {
  /// Payout: waiting for a payout account or its turn.
  pending,

  /// Payout: being sent.
  sending,

  /// Payout: arrived.
  paid,

  /// Payout: the transfer failed and will be tried again.
  failed,

  /// Payment: held by Nata until delivery.
  inEscrow,

  /// Payment: passed on to the traveler.
  released,

  /// Payment: given back to the sender.
  refunded,
}

/// One payout (as a traveler) or payment (as a sender).
class WalletEntry {
  final WalletEntryKind kind;
  final String id;
  final double amount;
  final String currency;
  final WalletEntryStatus status;
  final DateTime date;
  final String? item;
  final String? fromCity;
  final String? toCity;

  /// The sender (payout) or traveler (payment).
  final String? otherName;

  const WalletEntry({
    required this.kind,
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.date,
    this.item,
    this.fromCity,
    this.toCity,
    this.otherName,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> j) {
    final kind = j['kind'] == 'payment'
        ? WalletEntryKind.payment
        : WalletEntryKind.payout;
    final raw = j['status'] as String?;
    final status = kind == WalletEntryKind.payout
        ? switch (raw) {
            'paid' => WalletEntryStatus.paid,
            'processing' => WalletEntryStatus.sending,
            'failed' => WalletEntryStatus.failed,
            _ => WalletEntryStatus.pending,
          }
        : switch (raw) {
            'released' => WalletEntryStatus.released,
            'refunded' => WalletEntryStatus.refunded,
            _ => WalletEntryStatus.inEscrow,
          };
    return WalletEntry(
      kind: kind,
      id: j['id'] as String,
      amount: (j['amount'] as num?)?.toDouble() ?? 0,
      currency: ((j['currency'] as String?) ?? 'USD').trim().toUpperCase(),
      status: status,
      date: DateTime.parse(j['created_at'] as String).toLocal(),
      item: j['item'] as String?,
      fromCity: j['from_city'] as String?,
      toCity: j['to_city'] as String?,
      otherName: j['other_name'] as String?,
    );
  }
}
