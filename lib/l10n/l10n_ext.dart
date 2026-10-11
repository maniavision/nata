import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Shorthand: context.l10n.keyName
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
