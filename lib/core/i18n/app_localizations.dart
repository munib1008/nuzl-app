import 'package:flutter/material.dart';
import 'strings.dart';

/// Lightweight i18n built on the standard Localizations system (no codegen).
/// English + Arabic; selecting Arabic flips the app to RTL automatically (via
/// the Global*Localizations delegates wired in app.dart). The string store is a
/// Dart map today — swappable for ARB / a remote translation service later
/// without changing any `context.tr('key')` call site.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? AppLocalizations(const Locale('en'));

  bool get isRtl => locale.languageCode == 'ar';

  /// Translate [key] in the current locale, falling back to English then the key.
  String t(String key) {
    final table = locale.languageCode == 'ar' ? kAr : kEn;
    return table[key] ?? kEn[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => const ['en', 'ar'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Ergonomic accessor: `context.tr('dashboard')`.
extension L10nX on BuildContext {
  String tr(String key) => AppLocalizations.of(this).t(key);
}
