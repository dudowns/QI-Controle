// lib/utils/loading_mixin.dart
import 'package:flutter/material.dart';
import '../services/loading_service.dart';
import 'result.dart';

mixin LoadingMixin {
  LoadingService? _loadingService;

  LoadingService get _loading {
    _loadingService ??= LoadingService();
    return _loadingService!;
  }

  /// Executa uma operação com loading automático
  Future<T> withLoading<T>(Future<T> Function() operation) async {
    _loading.show();
    try {
      return await operation();
    } finally {
      _loading.hide();
    }
  }

  /// Executa uma operação com Result e loading
  Future<Result<T>> withLoadingResult<T>(
    Future<Result<T>> Function() operation,
  ) async {
    _loading.show();
    try {
      return await operation();
    } finally {
      _loading.hide();
    }
  }

  /// Executa uma operação com loading e retorna Result
  Future<Result<T>> toResult<T>(
    Future<T> Function() operation, {
    String errorMessage = 'Erro ao executar operação',
  }) async {
    _loading.show();
    try {
      final result = await operation();
      return Result.success(result);
    } catch (e) {
      return Result.failure('$errorMessage: $e');
    } finally {
      _loading.hide();
    }
  }

  /// Mostra snackbar de erro
  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Mostra snackbar de sucesso
  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Mostra snackbar de aviso
  void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
