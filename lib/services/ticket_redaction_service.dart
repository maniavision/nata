import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'id_document_check_service.dart';

/// One word read on a ticket page, in the page image's pixels.
class OcrWord {
  final String text;

  /// Words on the same printed line share this number.
  final int line;
  final Rect rect;

  const OcrWord(this.text, this.rect, {this.line = 0});
}

/// Makes the copy of a flight ticket that senders see: the booking reference
/// (PNR) and any barcode (boarding pass barcodes encode it) are blurred, so a
/// sender can't use them to change or cancel the traveler's booking.
///
/// Runs on the device when a trip is saved: PDFs are rendered to images,
/// photos turned upright, the words and barcodes found with native OCR (see
/// [IdDocumentCheckService.textBoxes]), and the pages joined into one image.
class TicketRedactionService {
  TicketRedactionService({
    Future<List<Uint8List>> Function(Uint8List bytes, String fileName)? pages,
    Future<Map<Object?, Object?>?> Function(Uint8List page)? readPage,
    Future<Uint8List?> Function(Uint8List png)? compress,
  }) : _pages = pages ?? _defaultPages,
       _readPage =
           readPage ??
           ((page) => IdDocumentCheckService.textBoxes(page, 'ticket.png')),
       _compress =
           compress ??
           ((png) => IdDocumentCheckService.uprightJpeg(png, 'ticket.png'));

  final Future<List<Uint8List>> Function(Uint8List bytes, String fileName)
  _pages;
  final Future<Map<Object?, Object?>?> Function(Uint8List page) _readPage;
  final Future<Uint8List?> Function(Uint8List png) _compress;

  static Future<List<Uint8List>> _defaultPages(
    Uint8List bytes,
    String fileName,
  ) async {
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return IdDocumentCheckService.renderPdfPages(bytes, fileName);
    }
    final jpeg = await IdDocumentCheckService.uprightJpeg(bytes, fileName);
    return jpeg == null ? const [] : [jpeg];
  }

  /// The ticket as one image (JPEG, or PNG if it could not be compressed)
  /// with the booking reference and barcodes blurred. Null when the booking
  /// reference could not be found on it: the ticket is then not shared.
  Future<Uint8List?> redact(
    Uint8List bytes,
    String fileName, {
    String? bookingReference,
  }) async {
    final pages = await _pages(bytes, fileName);
    if (pages.isEmpty) return null;

    final images = <ui.Image>[];
    try {
      final regions = <List<Rect>>[];
      var foundReference = false;
      for (final page in pages) {
        final read = await _readPage(page);
        if (read == null) return null;
        final words = parseWords(read['words']);
        final references = referenceRegions(words, bookingReference);
        if (references.isNotEmpty) foundReference = true;
        regions.add([...references, ...parseRects(read['barcodes'])]);
        images.add(await _decode(page));
      }
      if (!foundReference) return null;

      final png = await blurPages(images, regions);
      return await _compress(png) ?? png;
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  // ── Finding the booking reference ──────────────────────────────────────────

  /// Words that introduce a booking reference, without accents, in the
  /// languages tickets are commonly printed in.
  static const _labels = {
    'PNR',
    'BOOKING',
    'RESERVATION',
    'RESERVA',
    'RESERVACION',
    'LOCATOR',
    'LOCALIZADOR',
    'CONFIRMATION',
    'CONFIRMACION',
    'DOSSIER',
    'REFERENCE',
    'REFERENCIA',
    'REF',
    'BUCHUNGSCODE',
    'BUCHUNGSNUMMER',
  };

  /// Ticket words that look like a code (5-8 letters) but aren't one.
  static const _notCodes = {
    'NUMBER',
    'NUMERO',
    'TICKET',
    'BILLET',
    'BILLETE',
    'ISSUED',
    'ISSUE',
    'PASSENGER',
    'PASSAGER',
    'PASAJERO',
    'FLIGHT',
    'VUELO',
    'STATUS',
    'CONFIRMED',
    'ECONOMY',
    'BUSINESS',
    'CLASS',
    'CLASSE',
    'CLASE',
    'AIRLINE',
    'AIRWAYS',
    'AGENCY',
    'CARRIER',
    'OPERATED',
    'DEPARTURE',
    'DEPART',
    'ARRIVAL',
    'ARRIVEE',
    'TERMINAL',
    'BAGGAGE',
    'BAGAGE',
    'EQUIPAJE',
    'NAME',
    'GATE',
    'FROM',
    'DATE',
    'FECHA',
    'ELECTRONIC',
    'RECEIPT',
    'ITINERARY',
    'TOTAL',
    'FARE',
    'TARIF',
    'TARIFA',
    'VALID',
    'ADULT',
    'ADULTE',
    'ADULTO',
    'CODE',
    'CODIGO',
  };

  static final _codeShape = RegExp(r'^[A-Z0-9]{5,8}$');
  static final _hasLetter = RegExp(r'[A-Z]');

  /// "22JUN", "22JUN30", "22JUN2030": dates, not codes.
  static final _dateShape = RegExp(r'^\d{1,2}[A-Z]{3}(\d{2}|\d{4})?$');

  static String _clean(String s) => IdDocumentCheckService.stripAccents(
    s.toUpperCase(),
  ).replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool _looksLikeCode(String w) =>
      _codeShape.hasMatch(w) &&
      _hasLetter.hasMatch(w) &&
      !_dateShape.hasMatch(w) &&
      !_labels.contains(w) &&
      !_notCodes.contains(w);

  /// Where the booking reference is: every word containing the reference the
  /// traveler entered, and the first code after a label such as "Booking
  /// reference" or "PNR" (the next words on that line, then the next line).
  @visibleForTesting
  static List<Rect> referenceRegions(List<OcrWord> words, String? reference) {
    final ref = _clean(reference ?? '');
    final found = <int>{};
    for (var i = 0; i < words.length; i++) {
      final w = _clean(words[i].text);
      if (w.isEmpty) continue;
      if (ref.length >= 5 && w.contains(ref)) found.add(i);
      if (!_labels.contains(w)) continue;
      for (var j = i + 1; j < words.length && j <= i + 6; j++) {
        if (words[j].line > words[i].line + 1) break;
        if (_looksLikeCode(_clean(words[j].text))) {
          found.add(j);
          break;
        }
      }
    }
    return [for (final i in found.toList()..sort()) words[i].rect];
  }

  // ── Reading the native results ─────────────────────────────────────────────

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  static Rect? _rect(Object? v) {
    if (v is! Map) return null;
    final w = _num(v['w']), h = _num(v['h']);
    if (w <= 0 || h <= 0) return null;
    return Rect.fromLTWH(_num(v['x']), _num(v['y']), w, h);
  }

  @visibleForTesting
  static List<OcrWord> parseWords(Object? v) => [
    if (v is List)
      for (final e in v)
        if (e is Map && _rect(e) != null)
          OcrWord(
            (e['text'] as String?) ?? '',
            _rect(e)!,
            line: (e['line'] as num?)?.toInt() ?? 0,
          ),
  ];

  @visibleForTesting
  static List<Rect> parseRects(Object? v) => [
    if (v is List)
      for (final e in v)
        if (_rect(e) != null) _rect(e)!,
  ];

  // ── Drawing ────────────────────────────────────────────────────────────────

  /// The pages one under the other, at the widest page's width, with
  /// [regions] (in each page's own pixels) blurred. As PNG.
  ///
  /// Each region is first reduced to about one colour per character, then
  /// blurred: the text can't be recovered from what is left.
  @visibleForTesting
  static Future<Uint8List> blurPages(
    List<ui.Image> pages,
    List<List<Rect>> regions,
  ) async {
    final width = pages.map((p) => p.width).reduce(math.max).toDouble();
    final scales = [for (final p in pages) width / p.width];
    final height = [
      for (var i = 0; i < pages.length; i++) pages[i].height * scales[i],
    ].fold<double>(0, (a, b) => a + b);

    // About one block per character, averaged from the page.
    final blocks = <(ui.Image, Rect)>[];
    var top = 0.0;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final bounds = Rect.fromLTWH(
        0,
        0,
        page.width.toDouble(),
        page.height.toDouble(),
      );
      for (final region in regions[i]) {
        final src = region.inflate(region.height * 0.3).intersect(bounds);
        if (src.isEmpty) continue;
        final across = math.max(1, (src.width / src.height).ceil());
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawImageRect(
          page,
          src,
          Rect.fromLTWH(0, 0, across.toDouble(), 1),
          Paint()..filterQuality = FilterQuality.medium,
        );
        final picture = recorder.endRecording();
        final block = await picture.toImage(across, 1);
        picture.dispose();
        final dst = Rect.fromLTRB(
          src.left * scales[i],
          top + src.top * scales[i],
          src.right * scales[i],
          top + src.bottom * scales[i],
        );
        blocks.add((block, dst));
      }
      top += page.height * scales[i];
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    top = 0;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final h = page.height * scales[i];
      canvas.drawImageRect(
        page,
        Rect.fromLTWH(0, 0, page.width.toDouble(), page.height.toDouble()),
        Rect.fromLTWH(0, top, width, h),
        Paint()..filterQuality = FilterQuality.high,
      );
      top += h;
    }
    for (final (block, dst) in blocks) {
      final sigma = math.max(4.0, dst.height / 3);
      canvas
        ..save()
        ..clipRect(dst)
        ..saveLayer(
          dst,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.clamp,
            ),
        )
        ..drawImageRect(
          block,
          Rect.fromLTWH(0, 0, block.width.toDouble(), 1),
          dst,
          Paint()..filterQuality = FilterQuality.low,
        )
        ..restore()
        ..restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    picture.dispose();
    for (final (block, _) in blocks) {
      block.dispose();
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
