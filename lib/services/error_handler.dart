// lib/services/error_handler.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'logger_service.dart';

class AppError {
  final String message;
  final String? code;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final String? screen;

  AppError({
    required this.message,
    this.code,
    this.stackTrace,
    DateTime? timestamp,
    this.screen,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'message': message,
        'code': code,
        'timestamp': timestamp.toIso8601String(),
        'screen': screen,
      };
}

class ErrorHandler {
  static final List<AppError> _errorLog = [];
  static final List<String> _ignoredErrors = [
    'setState() called after dispose',
    'Looking up a deactivated widget',
  ];

  static void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    BuildContext? context,
    String? screen,
    bool showSnackBar = true,
  }) {
    final message = _getUserFriendlyMessage(error);

    // Ignorar erros comuns que não afetam o usuário
    if (_shouldIgnore(error)) return;

    final appError = AppError(
      message: message,
      code: error is Exception ? error.runtimeType.toString() : null,
      stackTrace: stackTrace,
      screen: screen,
    );

    _errorLog.add(appError);

    // Manter apenas últimos 50 erros
    if (_errorLog.length > 50) {
      _errorLog.removeAt(0);
    }

    // Log para debug
    LoggerService.error(message, error);
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }

    // Mostrar snackbar se tiver contexto
    if (showSnackBar && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static String _getUserFriendlyMessage(dynamic error) {
    if (error is String) return error;

    final msg = error.toString().toLowerCase();

    if (msg.contains('network') || msg.contains('connection')) {
      return 'Sem conexão com a internet. Verifique sua rede.';
    }
    if (msg.contains('timeout')) {
      return 'Tempo limite excedido. Tente novamente.';
    }
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Permissão negada. Verifique as configurações.';
    }
    if (msg.contains('not found') || msg.contains('404')) {
      return 'Dados não encontrados.';
    }
    if (msg.contains('unique') || msg.contains('duplicate')) {
      return 'Este registro já existe.';
    }

    return 'Ocorreu um erro inesperado. Tente novamente.';
  }

  static bool _shouldIgnore(dynamic error) {
    final msg = error.toString();
    return _ignoredErrors.any((e) => msg.contains(e));
  }

  static List<AppError> getErrorLog() => List.unmodifiable(_errorLog);

  static void clearErrorLog() => _errorLog.clear();

  static Map<String, dynamic> getStats() {
    return {
      'totalErrors': _errorLog.length,
      'lastError': _errorLog.isNotEmpty ? _errorLog.last.toJson() : null,
    };
  }
}
