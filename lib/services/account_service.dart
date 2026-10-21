import 'package:supabase_flutter/supabase_flutter.dart';

/// What stops the signed-in user from deleting their account right now
/// (public.account_deletion_blockers, 20240156_delete_account.sql).
class AccountDeletionBlockers {
  /// Payments held in escrow, paid by the user or waiting to be paid to them.
  final int escrow;

  /// Payouts to the user and refunds to the user that aren't settled yet.
  final int payments;

  /// Accepted, paid or picked-up deliveries, as sender or traveler.
  final int deliveries;

  /// Open problem reports.
  final int disputes;

  /// Staff accounts are removed by hand.
  final bool staff;

  const AccountDeletionBlockers({
    this.escrow = 0,
    this.payments = 0,
    this.deliveries = 0,
    this.disputes = 0,
    this.staff = false,
  });

  static const none = AccountDeletionBlockers();

  bool get any =>
      escrow > 0 || payments > 0 || deliveries > 0 || disputes > 0 || staff;

  factory AccountDeletionBlockers.fromJson(Map<String, dynamic> json) {
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return AccountDeletionBlockers(
      escrow: count('escrow'),
      payments: count('payments'),
      deliveries: count('deliveries'),
      disputes: count('disputes'),
      staff: json['staff'] == true,
    );
  }
}

/// The account could not be deleted yet; [code] is the nata:… reason.
class AccountDeletionBlockedException implements Exception {
  final String code;

  const AccountDeletionBlockedException(this.code);

  @override
  String toString() => 'AccountDeletionBlockedException($code)';
}

/// Deleting the signed-in user's account.
class AccountService {
  final SupabaseClient _client;

  AccountService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  Future<AccountDeletionBlockers> deletionBlockers() async {
    final result = await _client.rpc('account_deletion_blockers');
    return AccountDeletionBlockers.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  /// Deletes the account (the delete-account edge function): personal data,
  /// files and the sign-in. Throws [AccountDeletionBlockedException] while
  /// money or a delivery is in flight. Sign out afterwards.
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? '${details['error']}' : '';
      if (e.status == 409 && code.startsWith('nata:')) {
        throw AccountDeletionBlockedException(code);
      }
      rethrow;
    }
  }
}
