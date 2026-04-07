// lib/utils/result.dart
import 'package:flutter/material.dart';

/// Classe para representar o resultado de uma operação
class Result<T> {
  final T? _data;
  final String? _error;
  final bool _isSuccess;

  Result._(this._data, this._error, this._isSuccess);

  /// Construtor para sucesso
  factory Result.success(T data) => Result._(data, null, true);

  /// Construtor para falha
  factory Result.failure(String error) => Result._(null, error, false);

  /// Verifica se foi sucesso
  bool get isSuccess => _isSuccess;

  /// Verifica se foi falha
  bool get isFailure => !_isSuccess;

  /// Retorna os dados (se sucesso)
  T get data {
    if (!isSuccess) throw Exception('Cannot get data from a failed result');
    return _data as T;
  }

  /// Retorna o erro (se falha)
  String get error {
    if (isSuccess) throw Exception('Cannot get error from a successful result');
    return _error!;
  }

  /// Retorna dados ou null
  T? get dataOrNull => _data;

  /// Retorna erro ou null
  String? get errorOrNull => _error;

  /// Método para tratar o resultado de forma segura
  void when({
    required Function(T) onSuccess,
    required Function(String) onError,
  }) {
    if (isSuccess) {
      onSuccess(_data as T);
    } else {
      onError(_error!);
    }
  }

  /// Método para mapear o resultado
  Result<U> map<U>(U Function(T) mapper) {
    if (isSuccess) {
      return Result.success(mapper(_data as T));
    } else {
      return Result.failure(_error!);
    }
  }

  /// Método para encadear operações assíncronas
  Future<Result<U>> flatMap<U>(Future<Result<U>> Function(T) mapper) async {
    if (isSuccess) {
      return await mapper(_data as T);
    } else {
      return Result.failure(_error!);
    }
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'Result.success($_data)';
    } else {
      return 'Result.failure($_error)';
    }
  }
}

/// Extensão para facilitar o uso em widgets
extension ResultExtension<T> on Result<T> {
  /// Mostra snackbar em caso de erro
  void showErrorSnackBar(BuildContext context) {
    if (isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Mostra snackbar em caso de sucesso
  void showSuccessSnackBar(BuildContext context, {String? customMessage}) {
    if (isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(customMessage ?? 'Operação realizada com sucesso!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

