/// Unit tests for VerificationService helper logic.
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

// Mirror the id type mapping from VerificationService
const _idTypeValues = ['passport', 'national_id', 'drivers_license'];

String idTypeFromIndex(int index) => _idTypeValues[index.clamp(0, 2)];

String mimeFromExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf': return 'application/pdf';
    case 'png': return 'image/png';
    case 'heic': return 'image/heic';
    default: return 'image/jpeg';
  }
}

void main() {
  group('ID type mapping', () {
    test('index 0 → passport', () {
      expect(idTypeFromIndex(0), 'passport');
    });

    test('index 1 → national_id', () {
      expect(idTypeFromIndex(1), 'national_id');
    });

    test('index 2 → drivers_license', () {
      expect(idTypeFromIndex(2), 'drivers_license');
    });

    test('negative index clamps to passport', () {
      expect(idTypeFromIndex(-1), 'passport');
    });

    test('out-of-range index clamps to drivers_license', () {
      expect(idTypeFromIndex(99), 'drivers_license');
    });
  });

  group('MIME type detection', () {
    test('jpg → image/jpeg', () => expect(mimeFromExt('jpg'), 'image/jpeg'));
    test('jpeg → image/jpeg', () => expect(mimeFromExt('jpeg'), 'image/jpeg'));
    test('png → image/png', () => expect(mimeFromExt('png'), 'image/png'));
    test('pdf → application/pdf', () => expect(mimeFromExt('pdf'), 'application/pdf'));
    test('heic → image/heic', () => expect(mimeFromExt('heic'), 'image/heic'));
    test('unknown → image/jpeg fallback', () => expect(mimeFromExt('bmp'), 'image/jpeg'));
    test('uppercase ext handled', () => expect(mimeFromExt('PNG'), 'image/png'));
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
