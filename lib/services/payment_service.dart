import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import 'request_service.dart' show StripeSheet;

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
/// How many payout accounts a traveler can have (20240175).
const maxPayoutAccounts = 2;

enum PayoutAccountFailure {
  invalid,
  notSupported,

  /// Not the traveler's country of residence.
  countryMismatch,

  /// Stripe needs an email for the account, and Nata has none.
  emailRequired,

  /// Already [maxPayoutAccounts] payout accounts.
  limitReached,

  /// Flutterwave doesn't recognise the Nigerian bank account.
  accountNotFound,
  unavailable,
  other,
}

/// Where a traveler's bank stands with Stripe (stripe-connect, 20240170):
/// not given yet, Stripe checking it, Stripe needing more than Nata's form
/// gives (finished on Stripe's page), or paid to.
enum StripeBankStatus { none, pending, actionNeeded, enabled }

/// What a traveler gives in Nata's form for their bank through Stripe.
/// [idNumber] is the ID number Stripe needs in their country (US: the last
/// 4 digits of the SSN); [routingNumber] is empty for IBAN countries.
class StripeBankDetails {
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String phone;
  final String line1;
  final String city;
  final String state;
  final String postalCode;
  final String? idNumber;
  final String routingNumber;
  final String accountNumber;

  /// Only when Nata has no email for the traveler.
  final String? email;

  const StripeBankDetails({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.phone,
    required this.line1,
    required this.city,
    this.state = '',
    required this.postalCode,
    this.idNumber,
    this.routingNumber = '',
    required this.accountNumber,
    this.email,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'dob': {
      'day': dateOfBirth.day,
      'month': dateOfBirth.month,
      'year': dateOfBirth.year,
    },
    'phone': phone,
    'address': {
      'line1': line1,
      'city': city,
      'state': state,
      'postal_code': postalCode,
    },
    if (idNumber != null) 'id_number': idNumber,
    'bank': {'routing_number': routingNumber, 'account_number': accountNumber},
    if (email != null) 'email': email,
    'tos_accepted': true,
  };
}

/// [status], and the payout account it became once [StripeBankStatus.enabled].
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

  /// What Stripe refused, in its words (an invalid routing number...).
  final String? message;

  const PayoutAccountException(this.reason, [this.message]);
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

  /// Makes [id] the account payouts go to; the other stops being the
  /// default (keep_single_default, 20240124).
  Future<void> setDefaultPayoutAccount(String id) async {
    await _table('payout_accounts').update({'is_default': true}).eq('id', id);
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
        'limit_reached' => PayoutAccountFailure.limitReached,
        'account_not_found' => PayoutAccountFailure.accountNotFound,
        'payments_unavailable' => PayoutAccountFailure.unavailable,
        _ => PayoutAccountFailure.other,
      });
    }
  }

  /// Sends what the traveler gave in Nata's form: Stripe's account is made
  /// (or updated) with it and the bank account added. Answers where it
  /// stands, as [stripeBankStatus]. Travelers living where Stripe can't pay
  /// out get [PayoutAccountFailure.notSupported]; with no email known,
  /// [PayoutAccountFailure.emailRequired]; something Stripe refuses,
  /// [PayoutAccountFailure.invalid] with its message.
  Future<StripeBank> submitStripeBank(StripeBankDetails details) async {
    final data = await _stripeConnect('submit', details.toJson());
    return _stripeBank(data);
  }

  /// Stripe's page for what Nata's form doesn't cover, once Stripe asks for
  /// more ([StripeBankStatus.actionNeeded]: an ID photo, a review).
  Future<Uri> stripeBankLink() async {
    final data = await _stripeConnect('finish');
    return Uri.parse(data['url'] as String);
  }

  /// Where the traveler's bank stands with Stripe. [save] adds the
  /// connected bank as a payout account ("Use this bank"); it is otherwise
  /// added by itself only the first time (20240172).
  Future<StripeBank> stripeBankStatus({bool save = false}) async {
    return _stripeBank(
      await _stripeConnect('status', {if (save) 'save': true}),
    );
  }

  StripeBank _stripeBank(Map<String, dynamic> data) {
    final account = data['account'];
    final bank = data['bank'];
    return (
      status: switch (data['status']) {
        'enabled' => StripeBankStatus.enabled,
        'pending' => StripeBankStatus.pending,
        'action_needed' => StripeBankStatus.actionNeeded,
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
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    try {
      final response = await _client.functions.invoke(
        'stripe-connect',
        body: {'action': action, ...fields},
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['error']}' : '';
      final message = details is Map ? details['message'] as String? : null;
      throw PayoutAccountException(switch (code) {
        'not_supported' => PayoutAccountFailure.notSupported,
        'email_required' => PayoutAccountFailure.emailRequired,
        'limit_reached' => PayoutAccountFailure.limitReached,
        'invalid' || 'bad_request' => PayoutAccountFailure.invalid,
        'payments_unavailable' => PayoutAccountFailure.unavailable,
        _ => PayoutAccountFailure.other,
      }, message);
    }
  }

  /// The member's cards saved with Stripe (stripe-cards, 20240196), the
  /// default first.
  Future<List<StripeCard>> stripeCards() async =>
      _cardsFrom(await _stripeCards('list'));

  /// Saves a card through Stripe's own sheet, in setup mode: [present]
  /// shows it and says whether it was saved. Returns the cards then, or
  /// null when the member closed the sheet. [makeDefault] makes it the
  /// default (the first card always is).
  Future<List<StripeCard>?> addStripeCard({
    required Future<bool> Function(StripeSheet sheet) present,
    bool makeDefault = false,
  }) async {
    final setup = await _stripeCards('setup');
    final saved = await present(
      StripeSheet(
        clientSecret: setup['client_secret'] as String,
        publishableKey: setup['publishable_key'] as String? ?? '',
        merchantCountry: setup['merchant_country'] as String? ?? 'US',
        appleMerchantId: setup['apple_merchant_id'] as String?,
        customerId: setup['customer_id'] as String?,
        ephemeralKey: setup['ephemeral_key'] as String?,
        setup: true,
      ),
    );
    if (!saved) return null;
    return _cardsFrom(
      await _stripeCards('finish_setup', {
        'setup_intent': setup['setup_intent'],
        'make_default': makeDefault,
      }),
    );
  }

  Future<List<StripeCard>> setDefaultStripeCard(String cardId) async =>
      _cardsFrom(await _stripeCards('set_default', {'card_id': cardId}));

  /// Removes a saved card; the newest other one becomes the default.
  Future<List<StripeCard>> removeStripeCard(String cardId) async =>
      _cardsFrom(await _stripeCards('remove', {'card_id': cardId}));

  static List<StripeCard> _cardsFrom(Map<String, dynamic> data) => [
    for (final c in (data['cards'] as List? ?? const []))
      StripeCard.fromJson(Map<String, dynamic>.from(c as Map)),
  ];

  Future<Map<String, dynamic>> _stripeCards(
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final response = await _client.functions.invoke(
      'stripe-cards',
      body: {'action': action, ...fields},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Sends the traveler's pending payouts (send-payouts). Returns how many
  /// were sent; the rest wait for a payout account or failed.
  Future<int> sendPayouts() async {
    // Withdraw also sends what the member keeps in their Nata balance.
    final response = await _client.functions.invoke(
      'send-payouts',
      body: {'withdraw': true},
    );
    return ((response.data as Map?)?['sent'] as num?)?.toInt() ?? 0;
  }

  /// The Nata balance: what can be spent (in US dollars) and the member's
  /// choices (20240187_nata_balance.sql).
  Future<NataBalance> myBalance() async {
    final data = await _client.rpc('my_balance');
    return NataBalance.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Keep earnings in the balance (instead of sending them after each
  /// delivery), and refunds into it (instead of the card or mobile money).
  Future<void> setBalancePreferences({
    required bool keepEarnings,
    required bool refundsToBalance,
  }) => _client.rpc(
    'set_balance_preferences',
    params: {
      'p_keep_earnings': keepEarnings,
      'p_refunds_to_balance': refundsToBalance,
    },
  );

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
enum WalletEntryKind {
  payout,
  payment,

  /// A refund kept in the Nata balance (20240187).
  refund,

  /// A deposit the traveler paid before pickup (20240195).
  deposit,

  /// A traveler's deposit paid to the sender, for items kept.
  depositReceived;

  /// Money paid out of the member's pocket, rather than money in.
  bool get isOutgoing => this == payment || this == deposit;
}

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

  /// Payout: used to pay for a delivery from the Nata balance.
  spent,
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

  /// A payment made from the Nata balance.
  final bool fromBalance;

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
    this.fromBalance = false,
  });

  factory WalletEntry.fromJson(Map<String, dynamic> j) {
    final kind = switch (j['kind']) {
      'payment' => WalletEntryKind.payment,
      'refund' => WalletEntryKind.refund,
      'deposit' => WalletEntryKind.deposit,
      'deposit_received' => WalletEntryKind.depositReceived,
      _ => WalletEntryKind.payout,
    };
    final raw = j['status'] as String?;
    final status = !kind.isOutgoing
        ? switch (raw) {
            'paid' => WalletEntryStatus.paid,
            'processing' => WalletEntryStatus.sending,
            'failed' => WalletEntryStatus.failed,
            'spent' => WalletEntryStatus.spent,
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
      fromBalance: j['method'] == 'balance',
    );
  }
}

/// The member's Nata balance: earnings and refunds kept in Nata.
class NataBalance {
  final double availableUsd;
  final bool keepEarnings;
  final bool refundsToBalance;

  const NataBalance({
    required this.availableUsd,
    this.keepEarnings = false,
    this.refundsToBalance = false,
  });

  factory NataBalance.fromJson(Map<String, dynamic> j) => NataBalance(
    availableUsd: (j['available_usd'] as num?)?.toDouble() ?? 0,
    keepEarnings: j['keep_earnings'] == true,
    refundsToBalance: j['refunds_to_balance'] == true,
  );
}

/// A card saved with Stripe (20240196): only what is safe to show.
class StripeCard {
  final String id;

  /// Stripe's brand code: visa, mastercard, amex...
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  const StripeCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  /// "Visa", "Mastercard", "American Express".
  String get brandName => switch (brand) {
    'visa' => 'Visa',
    'mastercard' => 'Mastercard',
    'amex' => 'American Express',
    'discover' => 'Discover',
    'jcb' => 'JCB',
    'unionpay' => 'UnionPay',
    'diners' => 'Diners Club',
    _ => 'Card',
  };

  /// "Visa •••• 4242".
  String get title => '$brandName •••• $last4';

  /// "08/27".
  String get expiry =>
      '${expMonth.toString().padLeft(2, '0')}/'
      '${(expYear % 100).toString().padLeft(2, '0')}';

  factory StripeCard.fromJson(Map<String, dynamic> j) => StripeCard(
    id: j['id'] as String,
    brand: (j['brand'] as String? ?? 'card').toLowerCase(),
    last4: j['last4'] as String? ?? '',
    expMonth: (j['exp_month'] as num?)?.toInt() ?? 0,
    expYear: (j['exp_year'] as num?)?.toInt() ?? 0,
    isDefault: j['is_default'] == true,
  );
}
