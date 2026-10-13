import 'package:supabase_flutter/supabase_flutter.dart';

/// How the emergency contact is related to the user.
enum EmergencyRelationship {
  friend,
  relative,
  partner,
  colleague;

  /// What `emergency_contacts.relationship` stores.
  String get dbValue => name;

  static EmergencyRelationship? fromDb(String? value) {
    for (final r in values) {
      if (r.name == value) return r;
    }
    return null;
  }
}

/// Someone to reach if something goes wrong during a delivery.
class EmergencyContact {
  final String fullName;

  /// International format, e.g. "+447700900123".
  final String phone;
  final EmergencyRelationship relationship;

  const EmergencyContact({
    required this.fullName,
    required this.phone,
    required this.relationship,
  });
}

/// Saves the user's emergency contact.
///
/// Needs `supabase/migrations/20240119_emergency_contacts.sql`.
class EmergencyContactService {
  final SupabaseClient _client;

  EmergencyContactService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Not authenticated');
    return id;
  }

  /// Creates the contact, or replaces the one saved earlier (one per user).
  Future<void> save(EmergencyContact contact) async {
    await _client.schema('nata').from('emergency_contacts').upsert({
      'user_id': _userId,
      'full_name': contact.fullName.trim(),
      'phone': contact.phone,
      'relationship': contact.relationship.dbValue,
    }, onConflict: 'user_id');
  }

  /// The saved contact, or null if there is none.
  Future<EmergencyContact?> get() async {
    final row = await _client
        .schema('nata')
        .from('emergency_contacts')
        .select('full_name, phone, relationship')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return null;
    final relationship = EmergencyRelationship.fromDb(
      row['relationship'] as String?,
    );
    final name = row['full_name'] as String?;
    final phone = row['phone'] as String?;
    if (relationship == null || name == null || phone == null) return null;
    return EmergencyContact(
      fullName: name,
      phone: phone,
      relationship: relationship,
    );
  }
}
