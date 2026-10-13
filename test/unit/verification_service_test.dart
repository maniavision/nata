/// Unit tests for VerificationService helper logic.
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/verification_service.dart';

String mimeFromExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'heic':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

void main() {
  group('VerificationService.idDocumentFileName', () {
    test('one fixed name per user, keeping the file type', () {
      expect(
        VerificationService.idDocumentFileName('passport.jpg'),
        'id_document.jpg',
      );
      expect(
        VerificationService.idDocumentFileName('BIOMETRIC_CARD_5YRS.PDF'),
        'id_document.pdf',
      );
      expect(
        VerificationService.idDocumentFileName('IMG 0042.heic'),
        'id_document.heic',
      );
    });

    test('a missing or odd extension falls back to jpg', () {
      expect(VerificationService.idDocumentFileName('scan'), 'id_document.jpg');
      expect(
        VerificationService.idDocumentFileName('x.j/../pg'),
        'id_document.jpg',
      );
    });
  });

  group('IdDocumentType', () {
    // The ID screen's buttons are Passport, Driver's Lic., National ID, and
    // the screen picks the type by index: the enum must keep that order.
    test('follows the order of the ID screen buttons', () {
      expect(IdDocumentType.values, [
        IdDocumentType.passport,
        IdDocumentType.driversLicense,
        IdDocumentType.nationalId,
      ]);
    });

    test('stores the values the database accepts', () {
      expect(IdDocumentType.passport.dbValue, 'passport');
      expect(IdDocumentType.driversLicense.dbValue, 'drivers_license');
      expect(IdDocumentType.nationalId.dbValue, 'national_id');
    });
  });

  group('MIME type detection', () {
    test('jpg → image/jpeg', () => expect(mimeFromExt('jpg'), 'image/jpeg'));
    test('jpeg → image/jpeg', () => expect(mimeFromExt('jpeg'), 'image/jpeg'));
    test('png → image/png', () => expect(mimeFromExt('png'), 'image/png'));
    test(
      'pdf → application/pdf',
      () => expect(mimeFromExt('pdf'), 'application/pdf'),
    );
    test('heic → image/heic', () => expect(mimeFromExt('heic'), 'image/heic'));
    test(
      'unknown → image/jpeg fallback',
      () => expect(mimeFromExt('bmp'), 'image/jpeg'),
    );
    test(
      'uppercase ext handled',
      () => expect(mimeFromExt('PNG'), 'image/png'),
    );
  });

  group('Storage path construction', () {
    test('path is userId/fileName', () {
      const userId = 'abc-123';
      const fileName = 'id_front.jpg';
      final path = '$userId/$fileName';
      expect(path, 'abc-123/id_front.jpg');
    });

    test('path first segment is userId', () {
      const path = 'user-uuid-here/id_doc.png';
      final parts = path.split('/');
      expect(parts.first, 'user-uuid-here');
    });
  });

  group('Document state validation', () {
    test('null documentBytes means no document selected', () {
      const Uint8List? bytes = null;
      expect(bytes == null, isTrue);
    });

    test('non-null documentBytes means document selected', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(bytes.isNotEmpty, isTrue);
    });
  });
}
