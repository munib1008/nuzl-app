import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kLocaleKey = 'nuzl_locale';
const _storage = FlutterSecureStorage();

/// The app locale (null = English default). Persisted on the device, so a guest's
/// choice survives until sign-in and then sticks. Mirrors the theme-mode pattern.
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _load();
  }
  Future<void> _load() async {
    final v = await _storage.read(key: _kLocaleKey);
    if (v == 'ar' || v == 'en') state = Locale(v!);
  }

  Future<void> set(Locale? l) async {
    state = l;
    if (l == null) {
      await _storage.delete(key: _kLocaleKey);
    } else {
      await _storage.write(key: _kLocaleKey, value: l.languageCode);
    }
  }

  void toggle() => set((state?.languageCode == 'ar') ? const Locale('en') : const Locale('ar'));
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) => LocaleNotifier());
