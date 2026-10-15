import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'auth_service.dart';
import 'verification_service.dart';

/// Outcome of the automatic checks on an uploaded ID.
enum IdCheckResult {
  /// Every check ran and passed.
  passed,

  /// Fewer than [IdDocumentCheckService.minKeywords] ID labels were found
  /// ("passport", "date of birth", ...): probably not an ID document.
  notAnId,

  /// An ID, but not the type the user selected: nothing on it says
  /// "passport" when Passport was chosen, and so on.
  wrongType,

  /// The profile's first or last name is not on the document.
  nameMismatch,

  /// No human face (the ID photo) was found on the document.
  noFace,

  /// No text could be read from the document (blurry photo, OCR failure),
  /// so the name cannot be checked.
  unreadable,

  /// Nothing failed, but some check could not run (face detection
  /// unavailable, or the profile has no name). The submission falls back to
  /// manual review.
  unverifiable,
}

/// Checks an uploaded ID on-device before it is submitted:
/// - its text contains ID labels in one of several languages,
/// - it names the selected ID type ("passport", "permis de conduire", ...),
/// - the user's nata.profiles first_name / last_name appear in it,
/// - it shows a human face.
///
/// Text: pdfrx for PDFs, native OCR for images. Faces: native detection
/// (Apple Vision on iOS, ML Kit on Android), on the first page for PDFs.
class IdDocumentCheckService {
  IdDocumentCheckService({
    Future<String?> Function(Uint8List bytes, String fileName)? readText,
    Future<bool?> Function(Uint8List bytes, String fileName)? detectFace,
    Future<Map<String, dynamic>?> Function()? loadProfile,
  }) : _readText = readText ?? readDocumentText,
       _detectFace = detectFace ?? _detectDocumentFace,
       _loadProfile = loadProfile ?? AuthService().getProfile;

  final Future<String?> Function(Uint8List bytes, String fileName) _readText;
  final Future<bool?> Function(Uint8List bytes, String fileName) _detectFace;
  final Future<Map<String, dynamic>?> Function() _loadProfile;

  /// Longest a single step (text reading, face detection) may take before it
  /// counts as "could not run", so a stuck native call never blocks the UI.
  static const stepTimeout = Duration(seconds: 20);

  /// How many distinct ID labels (see [idKeywords]) must be on the document.
  static const minKeywords = 2;

  /// Labels printed on passports, ID cards and driver's licences, grouped by
  /// meaning. Written without accents or punctuation (matching ignores both).
  /// A group counts once, however many of its languages are on the ID.
  static const idKeywords = <String, List<String>>{
    'document': [
      'PASSPORT',
      'PASSEPORT',
      'PASAPORTE',
      'PASSAPORTE',
      'REISEPASS',
      'IDENTITY CARD',
      'CARTE D IDENTITE',
      'CARTE NATIONALE',
      'DOCUMENTO NACIONAL',
      'DOCUMENTO DE IDENTIDAD',
      'CEDULA',
      'CARTEIRA DE IDENTIDADE',
      'PERSONALAUSWEIS',
      'DRIVER LICENSE',
      'DRIVERS LICENSE',
      'DRIVER S LICENSE',
      'DRIVING LICENCE',
      'PERMIS DE CONDUIRE',
      'LICENCIA DE CONDUCIR',
      'CARTEIRA DE HABILITACAO',
      'RESIDENCE CARD',
      'RESIDENCE PERMIT',
      'TITRE DE SEJOUR',
      'CARTE DE SEJOUR',
      'PERMISO DE RESIDENCIA',
      'TARJETA DE RESIDENCIA',
      'AUFENTHALTSTITEL',
      'FUHRERSCHEIN',
    ],
    'surname': [
      'SURNAME',
      'LAST NAME',
      'FAMILY NAME',
      'NOM',
      'NOM DE FAMILLE',
      'APELLIDO',
      'APELLIDOS',
      'SOBRENOME',
      'NACHNAME',
      'FAMILIENNAME',
    ],
    'givenNames': [
      'GIVEN NAME',
      'GIVEN NAMES',
      'FIRST NAME',
      'PRENOM',
      'PRENOMS',
      'NOMBRE',
      'NOMBRES',
      'NOME',
      'VORNAME',
      'VORNAMEN',
    ],
    'dateOfBirth': [
      'DATE OF BIRTH',
      'BIRTH DATE',
      'DOB',
      'DATE DE NAISSANCE',
      'NE LE',
      'NEE LE',
      'FECHA DE NACIMIENTO',
      'DATA DE NASCIMENTO',
      'GEBURTSDATUM',
      'GEBURTSTAG',
    ],
    'placeOfBirth': [
      'PLACE OF BIRTH',
      'LIEU DE NAISSANCE',
      'LUGAR DE NACIMIENTO',
      'LOCAL DE NASCIMENTO',
      'GEBURTSORT',
    ],
    'nationality': [
      'NATIONALITY',
      'NATIONALITE',
      'NACIONALIDAD',
      'NACIONALIDADE',
      'STAATSANGEHORIGKEIT',
    ],
    'sex': ['SEX', 'SEXE', 'SEXO', 'GESCHLECHT'],
    'issueDate': [
      'DATE OF ISSUE',
      'ISSUE DATE',
      'DATE DE DELIVRANCE',
      'FECHA DE EXPEDICION',
      'FECHA DE EMISION',
      'DATA DE EMISSAO',
      'AUSSTELLUNGSDATUM',
    ],
    'expiryDate': [
      'DATE OF EXPIRY',
      'DATE OF EXPIRATION',
      'EXPIRY DATE',
      'EXPIRES',
      'DATE D EXPIRATION',
      'FECHA DE CADUCIDAD',
      'FECHA DE VENCIMIENTO',
      'VALIDADE',
      'GULTIG BIS',
    ],
    'authority': ['AUTHORITY', 'AUTORITE', 'AUTORIDAD', 'BEHORDE'],
  };

  /// Words that name each type of ID, in the languages IDs are commonly
  /// printed in. Like [idKeywords], written without accents or punctuation.
  /// One of them (or the type's machine-readable zone) must be on the ID.
  static const typeKeywords = <IdDocumentType, List<String>>{
    IdDocumentType.passport: [
      'PASSPORT',
      'PASSEPORT',
      'PASAPORTE',
      'PASSAPORTE',
      'PASSAPORTO',
      'REISEPASS',
      'PASPOORT',
    ],
    IdDocumentType.driversLicense: [
      'DRIVER LICENSE',
      'DRIVERS LICENSE',
      'DRIVER S LICENSE',
      'DRIVER LICENCE',
      'DRIVERS LICENCE',
      'DRIVER S LICENCE',
      'DRIVING LICENCE',
      'DRIVING LICENSE',
      'PERMIS DE CONDUIRE',
      'LICENCIA DE CONDUCIR',
      'LICENCIA DE CONDUCCION',
      'PERMISO DE CONDUCIR',
      'CARTEIRA DE HABILITACAO',
      'CARTEIRA NACIONAL DE HABILITACAO',
      'FUHRERSCHEIN',
      'PATENTE DI GUIDA',
    ],
    IdDocumentType.nationalId: [
      'IDENTITY CARD', 'NATIONAL ID', 'NATIONAL IDENTITY', 'ID CARD',
      'CARTE D IDENTITE', 'CARTE NATIONALE D IDENTITE', 'CARTE NATIONALE',
      'DOCUMENTO NACIONAL DE IDENTIDAD', 'DOCUMENTO DE IDENTIDAD',
      'DOCUMENTO NACIONAL', 'CEDULA DE IDENTIDAD', 'CEDULA DE CIUDADANIA',
      'CEDULA', 'DNI', 'CARTEIRA DE IDENTIDADE', 'REGISTRO GERAL',
      'PERSONALAUSWEIS', 'CARTA D IDENTITA',
      // Residence cards are official ID cards too.
      'RESIDENCE CARD', 'RESIDENCE PERMIT', 'TITRE DE SEJOUR',
      'CARTE DE SEJOUR', 'PERMISO DE RESIDENCIA', 'TARJETA DE RESIDENCIA',
      'AUFENTHALTSTITEL',
    ],
  };

  /// Machine-readable zone line starts (ICAO 9303): "P<USA..." on passports,
  /// "I<CMR...", "ID...", "AC...", "CR..." on ID and residence cards. Driver's
  /// licences have no MRZ.
  static final _mrzStart = <IdDocumentType, RegExp>{
    IdDocumentType.passport: RegExp(r'(^|\n)\s*P[A-Z<][A-Z]{3}[A-Z<]*<'),
    IdDocumentType.nationalId: RegExp(
      r'(^|\n)\s*[IAC][A-Z<][A-Z]{3}[A-Z0-9<]*<<',
    ),
  };

  /// True when [text] names [type]: one of its [typeKeywords] as whole
  /// words, or a machine-readable zone line of that type.
  @visibleForTesting
  static bool mentionsType(String text, IdDocumentType type) {
    final haystack = ' ${_normalize(text)} ';
    if (typeKeywords[type]!.any((k) => haystack.contains(' $k '))) return true;
    final mrz = _mrzStart[type];
    return mrz != null && mrz.hasMatch(text.toUpperCase());
  }

  Future<IdCheckResult> check({
    required Uint8List bytes,
    required String fileName,
    required IdDocumentType idType,
  }) async {
    final text = await _step('read text', _readText(bytes, fileName));
    if (text == null || text.trim().isEmpty) return IdCheckResult.unreadable;

    if (keywordGroupsIn(text) < minKeywords) return IdCheckResult.notAnId;
    if (!mentionsType(text, idType)) return IdCheckResult.wrongType;

    var nameChecked = false;
    final profile = await _loadProfile();
    final first = (profile?['first_name'] as String?)?.trim() ?? '';
    final last = (profile?['last_name'] as String?)?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      if (!nameAppearsIn(text, first) || !nameAppearsIn(text, last)) {
        return IdCheckResult.nameMismatch;
      }
      nameChecked = true;
    }

    final hasFace = await _step('detect face', _detectFace(bytes, fileName));
    if (hasFace == false) return IdCheckResult.noFace;

    return nameChecked && hasFace == true
        ? IdCheckResult.passed
        : IdCheckResult.unverifiable;
  }

  /// Awaits one check step, logging how long it took; null on timeout.
  static Future<T?> _step<T>(String name, Future<T?> work) async {
    final sw = Stopwatch()..start();
    final value = await work.timeout(
      stepTimeout,
      onTimeout: () {
        debugPrint('[IdDocumentCheckService] $name timed out');
        return null;
      },
    );
    debugPrint(
      '[IdDocumentCheckService] $name: ${sw.elapsedMilliseconds}ms '
      '-> ${value is String ? '${value.length} chars' : value}',
    );
    return value;
  }

  /// How many [idKeywords] groups have at least one label in [text], each
  /// matched as whole words.
  @visibleForTesting
  static int keywordGroupsIn(String text) {
    final haystack = ' ${_normalize(text)} ';
    return idKeywords.values
        .where((labels) => labels.any((l) => haystack.contains(' $l ')))
        .length;
  }

  /// True when every word of [name] appears as a whole word in [text].
  /// Case, accents, hyphens/apostrophes and passport MRZ fillers ('<') are
  /// ignored, so "Jean-Éric" matches "JEAN ERIC" and "P<CMRDUPONT<<JEAN<ERIC".
  /// Also used for flight tickets (TicketCheckService).
  static bool nameAppearsIn(String text, String name) {
    final words = _normalize(name).split(' ').where((w) => w.isNotEmpty);
    if (words.isEmpty) return false;
    final haystack = ' ${_normalize(text)} ';
    // Passport MRZ glues the 3-letter country code onto the surname
    // (P<CMRDUPONT), so also accept a word preceded by exactly 3 letters.
    final mrzChunks = text
        .toUpperCase()
        .split(RegExp(r'[^A-Z<]+'))
        .where((l) => l.contains('<'))
        .expand((l) => l.split('<'))
        .map(_normalize)
        .where((c) => c.isNotEmpty)
        .toList();
    return words.every(
      (w) =>
          haystack.contains(' $w ') ||
          mrzChunks.any((c) => c.length == w.length + 3 && c.endsWith(w)),
    );
  }

  /// Upper case, no accents, only letters and single spaces.
  static String normalize(String s) => _normalize(s);

  /// [s] with accented letters replaced by plain ones (upper case input).
  static String stripAccents(String s) => _stripAccents(s);

  static String _normalize(String s) {
    final upper = _stripAccents(s.toUpperCase());
    return upper
        .replaceAll(RegExp(r'[^A-Z]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static const _accents = {
    'ÀÁÂÃÄÅĀĂĄ': 'A',
    'ÇĆĈĊČ': 'C',
    'ĎĐ': 'D',
    'ÈÉÊËĒĔĖĘĚ': 'E',
    'ĜĞĠĢ': 'G',
    'ĤĦ': 'H',
    'ÌÍÎÏĨĪĬĮİ': 'I',
    'Ĵ': 'J',
    'Ķ': 'K',
    'ĹĻĽĿŁ': 'L',
    'ÑŃŅŇ': 'N',
    'ÒÓÔÕÖØŌŎŐ': 'O',
    'ŔŖŘ': 'R',
    'ŚŜŞŠ': 'S',
    'ŢŤŦ': 'T',
    'ÙÚÛÜŨŪŬŮŰŲ': 'U',
    'Ŵ': 'W',
    'ÝŸŶ': 'Y',
    'ŹŻŽ': 'Z',
    'Æ': 'AE',
    'Œ': 'OE',
    'ß': 'SS',
  };

  static String _stripAccents(String s) {
    final buf = StringBuffer();
    for (final ch in s.split('')) {
      final hit = _accents.entries.where((e) => e.key.contains(ch));
      buf.write(hit.isEmpty ? ch : hit.first.value);
    }
    return buf.toString();
  }

  /// PDFs are read with pdfrx, images with native OCR. Also used for flight
  /// tickets (TicketCheckService).
  static Future<String?> readDocumentText(Uint8List bytes, String fileName) =>
      fileName.toLowerCase().endsWith('.pdf')
      ? _extractPdfText(bytes, fileName)
      : _recognizeText(bytes, fileName);

  /// Reads the PDF's embedded text layer. A scanned PDF (just images) has
  /// none, so its pages are rendered and read with native OCR instead.
  static Future<String?> _extractPdfText(
    Uint8List bytes,
    String fileName,
  ) async {
    PdfDocument? doc;
    try {
      await pdfrxFlutterInitialize();
      doc = await PdfDocument.openData(bytes, sourceName: fileName);
      final buf = StringBuffer();
      for (final page in doc.pages) {
        final text = await page.loadText();
        if (text != null) buf.writeln(text.fullText);
      }
      if (buf.toString().trim().isNotEmpty) return buf.toString();
    } catch (e) {
      debugPrint('[IdDocumentCheckService] PDF text error: $e');
    } finally {
      await doc?.dispose();
    }

    final pages = await _renderPdfPages(bytes, fileName);
    final ocr = StringBuffer();
    for (var i = 0; i < pages.length; i++) {
      final text = await _recognizeText(pages[i], 'id_page${i + 1}.png');
      if (text != null) ocr.writeln(text);
    }
    return ocr.toString();
  }

  /// Native OCR and face detection: Apple Vision on iOS, ML Kit on Android
  /// (see IdTextRecognizer.swift / MainActivity.kt). Both read from a file.
  static const _channel = MethodChannel('nata/id_text');

  static Future<String?> _recognizeText(Uint8List bytes, String fileName) =>
      _invokeOnFile<String>('recognizeText', bytes, fileName);

  /// True/false when detection ran; null when it could not. For a PDF, true
  /// as soon as any page shows a face.
  static Future<bool?> _detectDocumentFace(
    Uint8List bytes,
    String fileName,
  ) async {
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      return _invokeOnFile<bool>('detectFace', bytes, fileName);
    }
    final pages = await _renderPdfPages(bytes, fileName);
    bool? found;
    for (var i = 0; i < pages.length; i++) {
      final hasFace = await _invokeOnFile<bool>(
        'detectFace',
        pages[i],
        'id_page${i + 1}.png',
      );
      if (hasFace == true) return true;
      found ??= hasFace;
    }
    return found;
  }

  static Future<T?> _invokeOnFile<T>(
    String method,
    Uint8List bytes,
    String fileName, [
    Map<String, Object> extra = const {},
  ]) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;

    final dir = await Directory.systemTemp.createTemp('id_check');
    final file = File('${dir.path}/$fileName');
    try {
      await file.writeAsBytes(bytes);
      return await _channel.invokeMethod<T>(method, {
        'path': file.path,
        ...extra,
      });
    } catch (e) {
      debugPrint('[IdDocumentCheckService] $method error: $e');
      return null;
    } finally {
      await dir.delete(recursive: true);
    }
  }

  /// The ID image to compare the selfie with, as an upright JPEG of at most
  /// 1600 px (what AWS Rekognition accepts): the photo itself, or for a PDF
  /// the first page that shows a face. Null if none could be made.
  static Future<Uint8List?> faceImage(Uint8List bytes, String fileName) async {
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      return _invokeOnFile<Uint8List>('toJpeg', bytes, fileName, {
        'maxSide': 1600,
      });
    }
    final pages = await _renderPdfPages(bytes, fileName);
    for (var i = 0; i < pages.length; i++) {
      final name = 'id_page${i + 1}.png';
      if (await _invokeOnFile<bool>('detectFace', pages[i], name) == true) {
        return _invokeOnFile<Uint8List>('toJpeg', pages[i], name, {
          'maxSide': 1600,
        });
      }
    }
    return null;
  }

  /// An ID is at most a few pages (front, back); don't render a whole book.
  static const _maxPdfPages = 3;

  /// Renders the first pages of a PDF to PNG for OCR and face detection.
  /// ID cards are tiny in points (~250x160), so pages are scaled to at least
  /// 1600 px on their long side for the OCR to read the small print.
  static Future<List<Uint8List>> _renderPdfPages(
    Uint8List bytes,
    String fileName,
  ) async {
    PdfDocument? doc;
    final pngs = <Uint8List>[];
    try {
      await pdfrxFlutterInitialize();
      doc = await PdfDocument.openData(bytes, sourceName: fileName);
      for (final page in doc.pages.take(_maxPdfPages)) {
        final longSide = math.max(page.width, page.height);
        final scale = math.max(2.0, 1600 / longSide);
        final pdfImage = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: 0xffffffff,
        );
        if (pdfImage == null) continue;
        try {
          final image = await pdfImage.createImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (data != null) pngs.add(data.buffer.asUint8List());
        } finally {
          pdfImage.dispose();
        }
      }
    } catch (e) {
      debugPrint('[IdDocumentCheckService] PDF render error: $e');
    } finally {
      await doc?.dispose();
    }
    return pngs;
  }
}
