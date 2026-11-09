import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrywise_app/services/id_document_scanner.dart';

void main() {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
  late int cleanUps;
  late List<String> read;

  setUp(() {
    cleanUps = 0;
    read = [];
    IdDocumentScanner.readFile = (path) async {
      read.add(path);
      return jpeg;
    };
    IdDocumentScanner.cleanUp = () async => cleanUps++;
  });

  void scannerReturns(Future<ScanResult?> Function() f) =>
      IdDocumentScanner.openScanner = f;

  test(
    'a scanned page comes back as bytes, and the cache is cleaned',
    () async {
      scannerReturns(
        () async => const ScanResult(images: ['/cache/page1.jpg']),
      );
      final scan = await IdDocumentScanner.scan();
      expect(scan.outcome, IdScanOutcome.scanned);
      expect(scan.bytes, jpeg);
      expect(read, ['/cache/page1.jpg']);
      expect(cleanUps, 1);
    },
  );

  test('closing the scanner is a cancel', () async {
    scannerReturns(() async => null);
    expect((await IdDocumentScanner.scan()).outcome, IdScanOutcome.cancelled);
    scannerReturns(() async => const ScanResult());
    expect((await IdDocumentScanner.scan()).outcome, IdScanOutcome.cancelled);
    expect(read, isEmpty);
  });

  test('a refused camera says so', () async {
    scannerReturns(
      () async =>
          throw const CunningDocumentScannerException.permissionDenied(),
    );
    expect(
      (await IdDocumentScanner.scan()).outcome,
      IdScanOutcome.cameraDenied,
    );
  });

  test('a scanner that cannot run falls back to a plain photo', () async {
    for (final error in <Object>[
      const CunningDocumentScannerException('no camera', code: 'UNAVAILABLE'),
      PlatformException(code: 'UNAVAILABLE'),
      MissingPluginException(),
    ]) {
      scannerReturns(() async => throw error);
      expect(
        (await IdDocumentScanner.scan()).outcome,
        IdScanOutcome.unavailable,
        reason: '$error',
      );
    }
  });

  test('a scan that cannot be read falls back too', () async {
    scannerReturns(() async => const ScanResult(images: ['/cache/page1.jpg']));
    IdDocumentScanner.readFile = (_) async =>
        throw const FileSystemExceptionLike();
    expect((await IdDocumentScanner.scan()).outcome, IdScanOutcome.unavailable);
    expect(cleanUps, 1);
  });

  test('tells PNG from JPEG', () {
    expect(IdDocumentScanner.extensionOf(png), 'png');
    expect(IdDocumentScanner.extensionOf(jpeg), 'jpg');
    expect(IdDocumentScanner.extensionOf(Uint8List(0)), 'jpg');
  });
}

class FileSystemExceptionLike implements Exception {
  const FileSystemExceptionLike();
}
