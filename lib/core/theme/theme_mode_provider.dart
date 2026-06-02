import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kThemeKey = 'nuzl_theme_mode';
const _storage = FlutterSecureStorage();

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }
  Future<void> _load() async {
    final v = await _storage.read(key: _kThemeKey);
    state = switch (v) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
  }
  Future<void> set(ThemeMode m) async {
    state = m;
    await _storage.write(key: _kThemeKey, value: m.name);
  }
  void toggle() => set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());
