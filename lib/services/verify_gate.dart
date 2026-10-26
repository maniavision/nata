import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/verify_prompt_sheet.dart';

/// Posting a trip or sending a request needs a passed identity check
/// (20240153 refuses both otherwise). Before opening either, this asks the
/// user to verify first, or to wait while their check is under review.
class VerifyGate {
  VerifyGate._();

  /// The signed-in user's verification_status: 'verified', 'pending' or
  /// 'unverified'; or 'needs_contact' when their ID check passed and only
  /// the emergency contact is missing (20240178). Replaced in tests.
  static Future<String> Function() status = _loadStatus;

  static Future<String> _loadStatus() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return 'unverified';
    final row = await client
        .schema('nata')
        .from('profiles')
        .select('verification_status, awaiting_emergency_contact')
        .eq('id', uid)
        .maybeSingle();
    if (row?['awaiting_emergency_contact'] == true) return 'needs_contact';
    return (row?['verification_status'] as String?) ?? 'unverified';
  }

  /// True when the user is verified. Otherwise shows the verify prompt, with
  /// [message] saying what they were trying to do, and returns false. If
  /// the status can't be read it lets them through: the server checks too.
  static Future<bool> check(
    BuildContext context, {
    required String message,
  }) async {
    String current;
    try {
      current = await status();
    } catch (e) {
      debugPrint('[VerifyGate] status: $e');
      return true;
    }
    if (current == 'verified') return true;
    if (!context.mounted) return false;
    await showVerifyPrompt(
      context,
      message: message,
      pending: current == 'pending',
      needsContact: current == 'needs_contact',
    );
    return false;
  }
}
