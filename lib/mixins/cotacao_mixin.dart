// lib/mixins/cotacao_mixin.dart
import 'package:flutter/material.dart';
import '../services/logger_service.dart';

// B3Service sera implementado futuramente
// import '../services/b3_service.dart';

mixin CotacaoMixin<T extends StatefulWidget> on State<T> {
  bool _atualizandoCotacoes = false;

  bool get atualizandoCotacoes => _atualizandoCotacoes;

  /// Atualiza cotacoes de uma lista de tickers
  Future<void> atualizarCotacoes(List<String> tickers) async {
    if (_atualizandoCotacoes) return;

    setState(() => _atualizandoCotacoes = true);

    try {
      // TODO: Implementar B3Service
      // final b3Service = B3Service();
      // final resultados = await b3Service.getCotacoesEmLote(tickers);

      if (mounted) {
        onCotacoesAtualizadas({});
      }
    } catch (e) {
      LoggerService.error('Erro ao atualizar cotacoes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar cotacoes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _atualizandoCotacoes = false);
      }
    }
  }

  /// Callback quando as cotacoes sao atualizadas
  void onCotacoesAtualizadas(Map<String, Map<String, dynamic>> cotacoes) {
    // Sobrescrever nas classes que usam o mixin
  }
}
