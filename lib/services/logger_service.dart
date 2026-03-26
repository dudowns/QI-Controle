import 'package:flutter/foundation.dart';

class LoggerService {
  static bool get _isDebug => kDebugMode;

  static void info(String message) {
    if (_isDebug) print('ℹ️ INFO: $message');
  }

  static void success(String message) {
    if (_isDebug) print('✅ SUCCESS: $message');
  }

  static void warning(String message) {
    if (_isDebug) print('⚠️ WARNING: $message');
  }

  static void error(String message, [dynamic error]) {
    if (_isDebug) {
      if (error != null) {
        print('❌ ERROR: $message - $error');
      } else {
        print('❌ ERROR: $message');
      }
    }
  }

  static void debug(String message) {
    if (_isDebug) print('🐛 DEBUG: $message');
  }

  static void database(String operation, {String? table, int? rowsAffected}) {
    if (_isDebug) {
      print(
          '🗄️ DB: $operation${table != null ? ' | Tabela: $table' : ''}${rowsAffected != null ? ' | Linhas: $rowsAffected' : ''}');
    }
  }

  static void performance(String operation, Duration duration) {
    if (_isDebug) {
      print('⚡ PERFORMANCE: $operation levou ${duration.inMilliseconds}ms');
    }
  }
}
