import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Shorthand: context.l10n.keyName
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Trip sizes are stored in English ("Shoebox (30×20×15 cm)") because the
/// database reads the first word to know the size class. These show them in
/// the app's language.
extension TripSizeLabels on AppLocalizations {
  String? _sizeName(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.startsWith('envelope')) return sizeEnvelope;
    if (t.startsWith('shoebox')) return sizeShoebox;
    if (t.startsWith('backpack')) return sizeBackpack;
    if (t.startsWith('custom')) return sizeCustom;
    return null;
  }

  /// "Shoebox (30×20×15 cm)" -> "Boîte à chaussures (30×20×15 cm)". Sizes the
  /// app does not know are shown as typed; none at all is "—".
  String tripSize(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '—';
    // Already in English, as the traveler picked it.
    if (localeName.startsWith('en')) return s;
    final name = _sizeName(s);
    if (name == null) return s;
    final dims = RegExp(r'\(.*\)').firstMatch(s)?.group(0);
    return dims == null ? name : '$name $dims';
  }

  /// Just the kind of size: "Shoebox", "Enveloppe / Document"...
  String tripSizeShort(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '—';
    final first = s.split(RegExp(r'[\s/(]')).first;
    if (localeName.startsWith('en')) return first;
    return _sizeName(s) ?? first;
  }
}
