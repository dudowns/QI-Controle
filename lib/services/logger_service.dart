import '../services/logger_service.dart';
import 'package:flutter/foundation.dart';

class LoggerService {
  static bool get _isDebug => kDebugMode;

  static void info(String message) {
    if (_isDebug) LoggerService.info('ℹ️ INFO: $message');
  }

  static void success(String message) {
    if (_isDebug) LoggerService.info('✅ SUCCESS: $message');
  }

  static void warning(String message) {
    if (_isDebug) LoggerService.info('⚠️ WARNING: $message');
  }

  static void error(String message, [dynamic error]) {
    if (_isDebug) {
      if (error != null) {
        LoggerService.info('❌ ERROR: $message - $error');
      } else {
        LoggerService.info('❌ ERROR: $message');
      }
    }
  }

  static void debug(String message) {
    if (_isDebug) LoggerService.info('🐛 DEBUG: $message');
  }

  static void database(String operation, {String? table, int? rowsAffected}) {
    if (_isDebug) {
      LoggerService.info(
          '🗄️ DB: $operation${table != null ? ' | Tabela: $table' : ''}${rowsAffected != null ? ' | Linhas: $rowsAffected' : ''}');
    }
  }

  static void performance(String operation, Duration duration) {
    if (_isDebug) {
      LoggerService.info('⚡ PERFORMANCE: $operation levou ${duration.inMilliseconds}ms');
    }
  }
}

