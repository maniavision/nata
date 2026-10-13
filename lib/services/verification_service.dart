import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The kinds of ID a user can upload, in the order the ID screen shows them.
enum IdDocumentType {
  passport('passport'),
  driversLicense('drivers_license'),
  nationalId('national_id');

  const IdDocumentType(this.dbValue);

  /// What `identity_verifications.id_document_type` stores.
  final String dbValue;
}

/// Handles uploading ID documents to Supabase Storage and writing
/// records to nata.identity_verifications.
class VerificationService {
  static final VerificationService _instance = VerificationService._();
  factory VerificationService() => _instance;
  VerificationService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ── Storage ───────────────────────────────────────────────────────────────

  /// The one name a user's ID document is stored under, whatever the picked
  /// file was called ("Scan 12.PDF" -> "id_document.pdf"), so a new upload
  /// replaces the old one instead of piling up next to it.
  static String idDocumentFileName(String pickedName) {
    final dot = pickedName.lastIndexOf('.');
    final ext = dot < 0 ? '' : pickedName.substring(dot + 1).toLowerCase();
    final safe = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'jpg';
    return 'id_document.$safe';
  }

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

  /// Creates the user's identity verification record, or updates it: there
  /// is one per user (unique `user_id`, see
  /// 20240121_identity_verifications_unique_user.sql), so a new ID replaces
  /// the old one. If the old document was stored under another name (other
  /// extension), that file is deleted.
  ///
  /// [documentPath] — storage path returned by [uploadDocument]
  Future<void> submitVerification({
    required IdDocumentType idType,
    required String documentPath,
  }) async {
    final uid = _userId;
    if (uid == null) throw Exception('Not authenticated');

    final previous = await _client
        .schema('nata')
        .from('identity_verifications')
        .select('id_document_path')
        .eq('user_id', uid)
        .maybeSingle();
    final previousPath = previous?['id_document_path'] as String?;

    // Upsert — if the user already submitted, update the existing record.
    await _client.schema('nata').from('identity_verifications').upsert({
      'user_id': uid,
      'id_document_type': idType.dbValue,
      'id_document_path': documentPath,
      'status': 'pending',
    }, onConflict: 'user_id');

    if (previousPath != null && previousPath != documentPath) {
      try {
        await _client.storage.from('identity-documents').remove([previousPath]);
      } catch (e) {
        // The new document is saved; a leftover file is not worth failing for.
        debugPrint('[VerificationService] old document not removed: $e');
      }
    }

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
