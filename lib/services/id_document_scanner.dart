import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What [IdDocumentScanner.scan] found.
enum IdScanOutcome {
  /// A page was scanned: see [IdScan.bytes].
  scanned,

  /// The user closed the scanner without scanning.
  cancelled,

  /// The user refused the camera.
  cameraDenied,

  /// The scanner can't run here (no document camera, as on the iOS
  /// simulator, or a native error): take a plain photo instead.
  unavailable,
}

/// The result of scanning an ID.
class IdScan {
  const IdScan(this.outcome, [this.bytes]);

  final IdScanOutcome outcome;

  /// The scanned page as a JPEG (iOS) or JPEG/PNG (Android), already cropped
  /// to the document's edges and straightened.
  final Uint8List? bytes;
}

/// Photographs an ID with the phone's own document scanner: Apple's document
/// camera (VisionKit) on iOS, Google's ML Kit scanner on Android. Both find
/// the card's edges, fix the perspective and crop to the document, so the
/// whole ID fills the picture and its text reads cleanly.
///
/// One page only, in colour with no filter, so the face on the ID still
/// matches the selfie.
class IdDocumentScanner {
  /// Opens the native scanner. Replaced in tests.
  @visibleForTesting
  static Future<ScanResult?> Function() openScanner = _openScanner;

  /// Reads a scanned page from disk. Replaced in tests.
  @visibleForTesting
  static Future<Uint8List> Function(String path) readFile = _readFile;

  /// Removes the scanner's own copies once the page is read. Replaced in
  /// tests.
  @visibleForTesting
  static Future<void> Function() cleanUp = CunningDocumentScanner.cleanCache;

  static Future<ScanResult?> _openScanner() =>
      CunningDocumentScanner.scanDocuments(
        noOfPages: 1,
        androidScannerMode: AndroidScannerMode.base,
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.9,
          showFilterBar: false,
        ),
      );

  static Future<Uint8List> _readFile(String path) => File(path).readAsBytes();

  /// Scans one ID page. Never throws: problems come back as an outcome.
  static Future<IdScan> scan() async {
    final ScanResult? result;
    try {
      result = await openScanner();
    } on CunningDocumentScannerException catch (e) {
      debugPrint('[IdDocumentScanner] $e');
      return IdScan(
        e.code == 'permission_denied'
            ? IdScanOutcome.cameraDenied
            : IdScanOutcome.unavailable,
      );
    } on PlatformException catch (e) {
      debugPrint('[IdDocumentScanner] $e');
      return const IdScan(IdScanOutcome.unavailable);
    } on MissingPluginException catch (e) {
      debugPrint('[IdDocumentScanner] $e');
      return const IdScan(IdScanOutcome.unavailable);
    }
    if (result == null || result.images.isEmpty) {
      return const IdScan(IdScanOutcome.cancelled);
    }
    try {
      final bytes = await readFile(result.images.first);
      return IdScan(IdScanOutcome.scanned, bytes);
    } catch (e) {
      debugPrint('[IdDocumentScanner] could not read the scan: $e');
      return const IdScan(IdScanOutcome.unavailable);
    } finally {
      try {
        await cleanUp();
      } catch (_) {}
    }
  }

  /// The file extension for [bytes]: 'png' for a PNG, otherwise 'jpg'.
  static String extensionOf(Uint8List bytes) =>
      bytes.length >= 4 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47
      ? 'png'
      : 'jpg';
}
