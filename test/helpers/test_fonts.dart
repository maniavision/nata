import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Widget tests render text with the "Ahem" test font by default, where every
/// character is a full square. That makes text far wider than on a real
/// device, so layout-overflow checks would fail for no real reason.
///
/// This registers the Roboto fonts that ship with the Flutter SDK under the
/// family names the app asks for (the google_fonts names for DM Sans and
/// Manrope, and "Roboto"), giving realistic text widths. Roboto is a little
/// narrower than DM Sans, so tests also use an enlarged text scale as margin.
///
/// Returns false (and changes nothing) if the SDK fonts cannot be found, so
/// callers can skip checks that depend on real text metrics.
Future<bool> loadRealisticTestFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) return false;

  const files = [
    'Roboto-Light.ttf',
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ];
  for (final f in files) {
    if (!File('${dir.path}/$f').existsSync()) return false;
  }

  // Read each file once and share the bytes between the families.
  final data = <ByteData>[
    for (final f in files)
      ByteData.sublistView(
        Uint8List.fromList(File('${dir.path}/$f').readAsBytesSync()),
      ),
  ];

  // google_fonts asks for "<Family>_<variant>" (e.g. DMSans_700, DMSans_regular)
  // and the engine does not fall back to a sibling family when measuring text,
  // so each variant the app uses is registered by its exact name.
  const variants = ['regular', '500', '600', '700', '800'];
  final families = <String>[
    'Roboto',
    for (final base in const ['DMSans', 'Manrope']) ...[
      base,
      for (final v in variants) '${base}_$v',
    ],
  ];

  for (final family in families) {
    final loader = FontLoader(family);
    for (final d in data) {
      loader.addFont(Future<ByteData>.value(d));
    }
    await loader.load();
  }
  return true;
}

Directory? _materialFontsDir() {
  final candidates = <String>[];
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) candidates.add(root);
  // .../flutter/bin/cache/dart-sdk/bin/dart -> .../flutter
  var d = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    candidates.add(d.path);
    d = d.parent;
  }
  for (final c in candidates) {
    final dir = Directory('$c/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) return dir;
  }
  return null;
}
