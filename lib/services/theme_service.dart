// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_themes.dart';

enum AppTheme {
  light,
  dark,
  system,
}

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  AppTheme _currentTheme = AppTheme.system;

  // Singleton
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // ========== GETTERS ==========

  AppTheme get currentTheme => _currentTheme;

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

  bool get isDarkMode {
    switch (_currentTheme) {
      case AppTheme.light:
        return false;
      case AppTheme.dark:
        return true;
      case AppTheme.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  Brightness get currentBrightness {
    return isDarkMode ? Brightness.dark : Brightness.light;
  }

  // ========== MÉTODOS PRINCIPAIS ==========

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeKey) ?? AppTheme.system.index;
      _currentTheme = AppTheme.values[themeIndex];
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erro ao carregar tema: $e');
      _currentTheme = AppTheme.system;
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme == theme) return;

    _currentTheme = theme;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, theme.index);
    } catch (e) {
      debugPrint('❌ Erro ao salvar tema: $e');
    }

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

  Future<void> resetToSystem() async {
    await setTheme(AppTheme.system);
  }

  // ========== MÉTODOS DE TEMAS ==========

  ThemeData getLightTheme() {
    return AppThemes.lightTheme;
  }

  ThemeData getDarkTheme() {
    return AppThemes.darkTheme;
  }

  ThemeData getCurrentTheme() {
    return isDarkMode ? AppThemes.darkTheme : AppThemes.lightTheme;
  }

  // ========== MÉTODOS DE CORES DINÂMICAS ==========

  Color getBackgroundColor(BuildContext context) {
    return isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
  }

  Color getSurfaceColor(BuildContext context) {
    return isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  }

  Color getCardColor(BuildContext context) {
    return isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  }

  Color getTextPrimaryColor(BuildContext context) {
    return isDarkMode ? Colors.white : const Color(0xFF343A40);
  }

  Color getTextSecondaryColor(BuildContext context) {
    return isDarkMode ? Colors.white70 : const Color(0xFF6C757D);
  }

  Color getTextHintColor(BuildContext context) {
    return isDarkMode ? Colors.grey[500]! : const Color(0xFFADB5BD);
  }

  Color getBorderColor(BuildContext context) {
    return isDarkMode ? Colors.grey[800]! : const Color(0xFFDEE2E6);
  }

  Color getDividerColor(BuildContext context) {
    return isDarkMode ? Colors.grey[800]! : const Color(0xFFE9ECEF);
  }

  Color getMutedColor(BuildContext context) {
    return isDarkMode ? Colors.grey[700]! : const Color(0xFFCED4DA);
  }
}

// ========== EXTENSÃO PARA FACILITAR ACESSO ==========
extension ThemeServiceExtension on BuildContext {
  ThemeService get themeService => ThemeService();

  bool get isDarkMode => ThemeService().isDarkMode;

  Color get backgroundColor => ThemeService().getBackgroundColor(this);

  Color get surfaceColor => ThemeService().getSurfaceColor(this);

  Color get cardColor => ThemeService().getCardColor(this);

  Color get textPrimary => ThemeService().getTextPrimaryColor(this);

  Color get textSecondary => ThemeService().getTextSecondaryColor(this);

  Color get textHint => ThemeService().getTextHintColor(this);

  Color get borderColor => ThemeService().getBorderColor(this);

  Color get dividerColor => ThemeService().getDividerColor(this);

  Color get mutedColor => ThemeService().getMutedColor(this);
}
