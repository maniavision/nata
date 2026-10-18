import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:carrywise_app/services/ticket_redaction_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The copy of a flight ticket senders see has the booking reference and
/// barcodes blurred.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Words of one line, left to right, 100 px wide and 20 px tall each.
  List<OcrWord> line(int n, List<String> words) => [
    for (var i = 0; i < words.length; i++)
      OcrWord(words[i], Rect.fromLTWH(i * 110.0, n * 30.0, 100, 20), line: n),
  ];

  Rect at(int line, int index) =>
      Rect.fromLTWH(index * 110.0, line * 30.0, 100, 20);

  group('finding the booking reference', () {
    test('the reference the traveler entered, wherever it is', () {
      final words = [
        ...line(0, ['Air', 'France', 'e-ticket']),
        ...line(1, ['Your', 'trip', 'x7kq9r', 'is', 'confirmed']),
      ];
      expect(TicketRedactionService.referenceRegions(words, 'X7KQ9R'), [
        at(1, 2),
      ]);
    });

    test('also when glued to its label', () {
      final words = line(0, ['REF:X7KQ9R']);
      expect(TicketRedactionService.referenceRegions(words, 'X7KQ9R'), [
        at(0, 0),
      ]);
    });

    test('the code after a label, without one entered', () {
      for (final label in [
        ['Booking', 'reference'],
        ['PNR'],
        ['Code', 'de', 'réservation'],
        ['Localizador'],
        ['Record', 'locator'],
      ]) {
        final words = line(0, [...label, 'KQXBTR']);
        expect(
          TicketRedactionService.referenceRegions(words, null),
          [at(0, label.length)],
          reason: label.join(' '),
        );
      }
    });

    test('or on the line under the label', () {
      final words = [
        ...line(0, ['Booking', 'reference']),
        ...line(1, ['LX4P2Q']),
      ];
      expect(TicketRedactionService.referenceRegions(words, null), [at(1, 0)]);
    });

    test('dates and ticket words after a label are not taken for it', () {
      final words = [
        ...line(0, ['Booking', 'date', '22JUN', 'NUMBER']),
        ...line(1, ['Seat', '12A']),
        ...line(2, ['Flight', 'AF1234']),
      ];
      // AF1234 is two lines below the label: too far to be its code.
      expect(TicketRedactionService.referenceRegions(words, null), isEmpty);
    });

    test('nothing found on a page without one', () {
      final words = line(0, ['Seat', '12A', 'Gate', 'B32']);
      expect(TicketRedactionService.referenceRegions(words, 'X7KQ9R'), []);
    });
  });

  test('reads the native results, skipping empty boxes', () {
    final words = TicketRedactionService.parseWords([
      {'text': 'PNR', 'line': 2, 'x': 10, 'y': 20, 'w': 30, 'h': 12},
      {'text': 'empty', 'x': 0, 'y': 0, 'w': 0, 'h': 0},
      'junk',
    ]);
    expect(words, hasLength(1));
    expect(words.single.text, 'PNR');
    expect(words.single.line, 2);
    expect(words.single.rect, const Rect.fromLTWH(10, 20, 30, 12));
    expect(
      TicketRedactionService.parseRects([
        {'x': 1.5, 'y': 2, 'w': 3, 'h': 4},
      ]),
      [const Rect.fromLTWH(1.5, 2, 3, 4)],
    );
    expect(TicketRedactionService.parseRects(null), isEmpty);
  });

  group('the shared copy', () {
    /// A white page with a black block where the reference is.
    Future<Uint8List> page(int width, int height, Rect ink) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..color = const Color(0xFFFFFFFF),
        )
        ..drawRect(ink, Paint()..color = const Color(0xFF000000));
      final image = await recorder.endRecording().toImage(width, height);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return png!.buffer.asUint8List();
    }

    Future<ui.Image> decode(Uint8List bytes) async {
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    }

    Future<int> pixel(ui.Image image, int x, int y) async {
      final data = (await image.toByteData())!;
      return data.getUint32((y * image.width + x) * 4);
    }

    testWidgets('blurs the reference and joins the pages', (tester) async {
      await tester.runAsync(() async {
        const ink = Rect.fromLTWH(40, 40, 120, 20);
        final first = await page(200, 100, ink);
        final second = await page(200, 100, Rect.zero);
        final readCalls = <int>[];

        final service = TicketRedactionService(
          pages: (bytes, name) async => [first, second],
          readPage: (p) async {
            readCalls.add(p.length);
            return identical(p, first)
                ? {
                    'words': [
                      {'text': 'X7KQ9R', 'x': 40, 'y': 40, 'w': 120, 'h': 20},
                    ],
                    'barcodes': [],
                  }
                : {'words': [], 'barcodes': []};
          },
          compress: (png) async => null, // keep the PNG
        );

        final out = await service.redact(
          Uint8List(0),
          'ticket.pdf',
          bookingReference: 'X7KQ9R',
        );
        expect(out, isNotNull);
        expect(readCalls, hasLength(2));

        final image = await decode(out!);
        expect(image.width, 200);
        expect(image.height, 200); // both pages
        // The middle of the black reference is no longer black...
        final middle = await pixel(image, 100, 50);
        expect(middle, isNot(0x000000FF));
        // ...and the rest of the page is untouched.
        expect(await pixel(image, 5, 5), 0xFFFFFFFF);
        expect(await pixel(image, 100, 150), 0xFFFFFFFF);
        image.dispose();
      });
    });

    testWidgets('not shared when the reference is not found', (tester) async {
      await tester.runAsync(() async {
        final blank = await page(50, 50, Rect.zero);
        final service = TicketRedactionService(
          pages: (bytes, name) async => [blank],
          readPage: (p) async => {
            'words': [
              {'text': 'Seat', 'x': 1, 'y': 1, 'w': 10, 'h': 5},
            ],
            // A barcode alone doesn't mean the reference was found.
            'barcodes': [
              {'x': 1, 'y': 10, 'w': 20, 'h': 20},
            ],
          },
          compress: (png) async => null,
        );
        expect(
          await service.redact(
            Uint8List(0),
            'a.jpg',
            bookingReference: 'X7KQ9R',
          ),
          isNull,
        );
      });
    });

    test('not shared when the text could not be read', () async {
      final service = TicketRedactionService(
        pages: (bytes, name) async => [Uint8List(1)],
        readPage: (p) async => null,
      );
      expect(await service.redact(Uint8List(0), 'a.jpg'), isNull);

      final noPages = TicketRedactionService(pages: (b, n) async => []);
      expect(await noPages.redact(Uint8List(0), 'a.jpg'), isNull);
    });
  });
}
