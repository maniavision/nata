import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:carrywise_app/l10n/app_localizations.dart';
import 'package:carrywise_app/main.dart';

/// Wraps [child] with MaterialApp + all localization delegates so that
/// context.l10n works inside widget tests without needing a real NataApp.
Widget appWrapper(Widget child, {Locale locale = const Locale('en')}) {
  return LocaleNotifier(
    notifier: ValueNotifier(locale),
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}
