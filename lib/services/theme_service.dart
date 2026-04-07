// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  light,
  dark,
  system,
}

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  AppTheme _currentTheme = AppTheme.system;

  AppTheme get currentTheme => _currentTheme;

  ThemeService() {
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? AppTheme.system.index;
    _currentTheme = AppTheme.values[themeIndex];
    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme == theme) return;
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    if (_currentTheme == AppTheme.light) {
      await setTheme(AppTheme.dark);
    } else if (_currentTheme == AppTheme.dark) {
      await setTheme(AppTheme.light);
    } else {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (brightness == Brightness.dark) {
        await setTheme(AppTheme.light);
      } else {
        await setTheme(AppTheme.dark);
      }
    }
  }

  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }

  IconData get themeIcon {
    switch (_currentTheme) {
      case AppTheme.light:
        return Icons.wb_sunny;
      case AppTheme.dark:
        return Icons.nightlight_round;
      case AppTheme.system:
        return Icons.sync;
    }
  }

  String get themeName {
    switch (_currentTheme) {
      case AppTheme.light:
        return 'Claro';
      case AppTheme.dark:
        return 'Escuro';
      case AppTheme.system:
        return 'Automático';
    }
  }
}

