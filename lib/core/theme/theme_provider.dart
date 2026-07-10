import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _themeBoxName = 'settings';
const _themeModeKey = 'themeMode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = Hive.box(_themeBoxName);
    final stored = box.get(_themeModeKey) as String?;
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        // This app is designed to always look like the (light-themed)
        // website — deliberately NOT following the phone's system
        // dark/light setting by default. Without this, any screen that
        // doesn't hardcode its own colors falls back to Flutter's
        // automatic dark theme, which is what caused every screen to
        // look like a different, inconsistent shade.
        return ThemeMode.light;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    final box = Hive.box(_themeBoxName);
    box.put(_themeModeKey, mode.name);
  }
}
