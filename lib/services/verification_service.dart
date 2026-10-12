import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps the UI id-type index to the DB constraint value.
const _idTypeValues = ['passport', 'national_id', 'drivers_license'];

/// Handles uploading ID documents to Supabase Storage and writing
/// records to nata.identity_verifications.
class VerificationService {
  static final VerificationService _instance = VerificationService._();
  factory VerificationService() => _instance;
  VerificationService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Uploads [bytes] to the `identity-documents` bucket under the user's
  /// folder. Returns the storage path on success.
  ///
  /// [fileName] must include extension, e.g. "id_front.jpg"
  Future<String> uploadDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final path = '$uid/$fileName';

    await _client.storage
        .from('identity-documents')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    return path;
  }

  // ── Database ──────────────────────────────────────────────────────────────

  /// Creates (or updates) the user's identity verification record.
  ///
  /// [idTypeIndex] — 0 = passport, 1 = national_id, 2 = drivers_license
  /// [documentPath] — storage path returned by [uploadDocument]
  Future<void> submitVerification({
    required int idTypeIndex,
    required String documentPath,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final docType = _idTypeValues[idTypeIndex.clamp(0, 2)];

    // Upsert — if the user already submitted, update the existing record
    await _client
        .schema('nata')
        .from('identity_verifications')
        .upsert({
          'user_id': uid,
          'id_document_type': docType,
          'id_document_path': documentPath,
          'status': 'pending',
        }, onConflict: 'user_id')
        .select()
        .single();

    // Update profile verification status to pending
    await _client
        .schema('nata')
        .from('profiles')
        .update({'verification_status': 'pending'})
        .eq('id', uid);
  }

  /// Returns the user's latest verification record, or null if none exists.
  Future<Map<String, dynamic>?> getMyVerification() async {
    final uid = _userId;
    if (uid == null) return null;

    try {
      return await _client
          .schema('nata')
          .from('identity_verifications')
          .select('id, status, id_document_type, created_at, updated_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (e) {
      debugPrint('[VerificationService] getMyVerification: $e');
      return null;
    }
  }
}
