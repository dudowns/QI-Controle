// lib/utils/loading_mixin.dart
import 'package:flutter/material.dart';
import '../services/loading_service.dart';
import 'result.dart'; // 🔥 IMPORT OBRIGATÓRIO

mixin LoadingMixin {
  final LoadingService _loading = LoadingService();

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

  /// Executa uma operação com loading e retorna Result (versão simplificada)
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
}
