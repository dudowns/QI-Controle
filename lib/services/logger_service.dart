// lib/services/logger_service.dart
import 'package:flutter/foundation.dart';

class LoggerService {
  static bool get _isDebug => kDebugMode;

  static void info(String message) {
    if (_isDebug) debugPrint('ℹ️ INFO: $message');
  }

  static void success(String message) {
    if (_isDebug) debugPrint('✅ SUCCESS: $message');
  }

  static void warning(String message) {
    if (_isDebug) debugPrint('⚠️ WARNING: $message');
  }

  static void error(String message, [dynamic error]) {
    if (_isDebug) {
      if (error != null) {
        debugPrint('❌ ERROR: $message - $error');
      } else {
        debugPrint('❌ ERROR: $message');
      }
    }
  }

  static void debug(String message) {
    if (_isDebug) debugPrint('🐛 DEBUG: $message');
  }

  static void log(String message) {
    if (_isDebug) debugPrint('📝 LOG: $message');
  }

  static void database(String operation, {String? table, int? rowsAffected}) {
    if (_isDebug) {
      debugPrint(
          '🗄️ DB: $operation${table != null ? ' | Tabela: $table' : ''}${rowsAffected != null ? ' | Linhas: $rowsAffected' : ''}');
    }
  }

  static void performance(String operation, Duration duration) {
    if (_isDebug) {
      debugPrint(
          '⚡ PERFORMANCE: $operation levou ${duration.inMilliseconds}ms');
    }
  }
}
