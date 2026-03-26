import 'package:flutter/foundation.dart';

// 🔥 CLASSE PARA ARMAZENAR MÉTRICAS DE CADA OPERAÇÃO
class PerformanceMetrics {
  String operacao;
  int totalChamadas = 0;
  int tempoTotalMs = 0;
  int tempoMinimoMs = 0x7FFFFFFF; // Valor máximo
  int tempoMaximoMs = 0;
  List<int> ultimosTempos = []; // Últimos 10 tempos

  PerformanceMetrics(this.operacao);

  void adicionarTempo(int tempoMs) {
    totalChamadas++;
    tempoTotalMs += tempoMs;

    if (tempoMs < tempoMinimoMs) tempoMinimoMs = tempoMs;
    if (tempoMs > tempoMaximoMs) tempoMaximoMs = tempoMs;

    // Manter apenas os últimos 10 tempos
    ultimosTempos.add(tempoMs);
    if (ultimosTempos.length > 10) {
      ultimosTempos.removeAt(0);
    }
  }

  double get tempoMedioMs =>
      totalChamadas > 0 ? tempoTotalMs / totalChamadas : 0;

  Map<String, dynamic> toJson() {
    return {
      'operacao': operacao,
      'totalChamadas': totalChamadas,
      'tempoTotalMs': tempoTotalMs,
      'tempoMedioMs': tempoMedioMs,
      'tempoMinimoMs': tempoMinimoMs == 0x7FFFFFFFFFFFFFFF ? 0 : tempoMinimoMs,
      'tempoMaximoMs': tempoMaximoMs,
      'ultimosTempos': ultimosTempos,
    };
  }
}

class PerformanceService {
  static final Map<String, Stopwatch> _stopwatches = {};
  static final Map<String, PerformanceMetrics> _metrics = {};

  // 🔥 CONSTANTE PARA OPERAÇÕES LENTAS (1 segundo)
  static const int _slowOperationThresholdMs = 1000;

  // 🔥 LISTA DE OPERAÇÕES IGNORADAS PARA RELATÓRIO
  static final Set<String> _operacoesIgnoradas = {};

  // ========== MÉTODOS PRINCIPAIS ==========

  static void start(String operacao) {
    // Se já existe um stopwatch rodando para esta operação, não cria outro
    if (_stopwatches.containsKey(operacao)) {
      if (kDebugMode) {
        debugPrint('⚠️ Aviso: Operação "$operacao" já está sendo medida!');
      }
      return;
    }

    final stopwatch = Stopwatch()..start();
    _stopwatches[operacao] = stopwatch;
  }

  static void stop(String operacao) {
    final stopwatch = _stopwatches[operacao];
    if (stopwatch == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Aviso: Operação "$operacao" não foi iniciada!');
      }
      return;
    }

    stopwatch.stop();
    final elapsedMs = stopwatch.elapsedMilliseconds;

    // Registrar métrica
    _registrarMetrica(operacao, elapsedMs);

    // Log da operação
    if (kDebugMode) {
      final logMsg = '⏱️ $operacao: ${elapsedMs}ms';

      if (elapsedMs >= _slowOperationThresholdMs) {
        debugPrint('🐌 OPERAÇÃO LENTA! $logMsg'); // Caracol para lentidão
      } else if (elapsedMs >= 500) {
        debugPrint('⚠️ $logMsg'); // Aviso para médias
      } else {
        debugPrint('✅ $logMsg'); // OK para rápidas
      }
    }

    // Limpar stopwatch
    _stopwatches.remove(operacao);
  }

  // ========== MÉTODOS COM TIMEOUT ==========

  static Future<T> measureAsync<T>(
    String operacao,
    Future<T> Function() callback,
  ) async {
    start(operacao);
    try {
      return await callback();
    } finally {
      stop(operacao);
    }
  }

  static T measureSync<T>(
    String operacao,
    T Function() callback,
  ) {
    start(operacao);
    try {
      return callback();
    } finally {
      stop(operacao);
    }
  }

  // ========== MÉTODOS DE REGISTRO ==========

  static void _registrarMetrica(String operacao, int tempoMs) {
    if (!_metrics.containsKey(operacao)) {
      _metrics[operacao] = PerformanceMetrics(operacao);
    }
    _metrics[operacao]!.adicionarTempo(tempoMs);
  }

  // ========== MÉTODOS DE RELATÓRIO ==========

  static Map<String, dynamic> getRelatorioCompleto() {
    final relatorio = <String, dynamic>{
      'totalOperacoes': _metrics.length,
      'operacoesAtivas': _stopwatches.length,
      'operacoes': <String, dynamic>{},
      'resumo': {
        'totalChamadas': 0,
        'tempoTotalMs': 0,
        'operacaoMaisLenta': '',
        'tempoMaisLentoMs': 0,
        'operacaoMaisRapida': '',
        'tempoMaisRapidoMs': 0x7FFFFFFFFFFFFFFF,
      },
    };

    for (var entry in _metrics.entries) {
      final metrics = entry.value;
      final json = metrics.toJson();
      relatorio['operacoes'][entry.key] = json;

      // Atualizar resumo
      relatorio['resumo']['totalChamadas'] =
          (relatorio['resumo']['totalChamadas'] as int) + metrics.totalChamadas;
      relatorio['resumo']['tempoTotalMs'] =
          (relatorio['resumo']['tempoTotalMs'] as int) + metrics.tempoTotalMs;

      if (metrics.tempoMaximoMs >
          (relatorio['resumo']['tempoMaisLentoMs'] as int)) {
        relatorio['resumo']['tempoMaisLentoMs'] = metrics.tempoMaximoMs;
        relatorio['resumo']['operacaoMaisLenta'] = metrics.operacao;
      }

      if (metrics.tempoMinimoMs <
          (relatorio['resumo']['tempoMaisRapidoMs'] as int)) {
        relatorio['resumo']['tempoMaisRapidoMs'] = metrics.tempoMinimoMs;
        relatorio['resumo']['operacaoMaisRapida'] = metrics.operacao;
      }
    }

    return relatorio;
  }

  static Map<String, int> getRelatorio() {
    final relatorio = <String, int>{};
    for (var entry in _metrics.entries) {
      relatorio[entry.key] = entry.value.tempoTotalMs;
    }
    return relatorio;
  }

  static Map<String, double> getTemposMedios() {
    final medias = <String, double>{};
    for (var entry in _metrics.entries) {
      medias[entry.key] = entry.value.tempoMedioMs;
    }
    return medias;
  }

  static List<Map<String, dynamic>> getOperacoesLentas(
      {int thresholdMs = 1000}) {
    final lentas = <Map<String, dynamic>>[];
    for (var entry in _metrics.entries) {
      if (entry.value.tempoMaximoMs >= thresholdMs) {
        lentas.add(entry.value.toJson());
      }
    }
    return lentas;
  }

  // ========== MÉTODOS DE LIMPEZA ==========

  static void limpar() {
    _stopwatches.clear();
    _metrics.clear();
    if (kDebugMode) {
      debugPrint('🗑️ PerformanceService: todas as métricas foram limpas');
    }
  }

  static void limparOperacao(String operacao) {
    _metrics.remove(operacao);
    _stopwatches.remove(operacao);
    if (kDebugMode) {
      debugPrint('🗑️ Métricas removidas para: $operacao');
    }
  }

  // ========== MÉTODOS DE UTILITÁRIOS ==========

  static void ignorarOperacao(String operacao) {
    _operacoesIgnoradas.add(operacao);
  }

  static void removerIgnorarOperacao(String operacao) {
    _operacoesIgnoradas.remove(operacao);
  }

  static void imprimirRelatorio() {
    if (!kDebugMode) return;

    final relatorio = getRelatorioCompleto();
    print('\n📊 ========== RELATÓRIO DE PERFORMANCE ==========');
    print('Total de operações medidas: ${relatorio['totalOperacoes']}');
    print('Total de chamadas: ${relatorio['resumo']['totalChamadas']}');
    print(
        'Tempo total: ${relatorio['resumo']['tempoTotalMs']}ms (${(relatorio['resumo']['tempoTotalMs'] / 1000).toStringAsFixed(2)}s)');
    print(
        'Operação mais rápida: ${relatorio['resumo']['operacaoMaisRapida']} - ${relatorio['resumo']['tempoMaisRapidoMs']}ms');
    print(
        'Operação mais lenta: ${relatorio['resumo']['operacaoMaisLenta']} - ${relatorio['resumo']['tempoMaisLentoMs']}ms');

    print('\n📋 Detalhamento por operação:');
    final operacoes = relatorio['operacoes'] as Map<String, dynamic>;
    final sorted = operacoes.entries.toList()
      ..sort((a, b) => (b.value['tempoTotalMs'] as int)
          .compareTo(a.value['tempoTotalMs'] as int));

    for (var entry in sorted) {
      final op = entry.value;
      print('\n  🔹 ${entry.key}');
      print('     Chamadas: ${op['totalChamadas']}');
      print('     Total: ${op['tempoTotalMs']}ms');
      print('     Média: ${op['tempoMedioMs'].toStringAsFixed(2)}ms');
      print(
          '     Min: ${op['tempoMinimoMs']}ms | Max: ${op['tempoMaximoMs']}ms');
    }

    print('============================================\n');
  }

  // ========== MÉTODOS PARA MONITORAMENTO EM TEMPO REAL ==========

  static void startMonitoramento() {
    if (kDebugMode) {
      // Imprimir relatório a cada 30 segundos se houver atividade
      Future.delayed(const Duration(seconds: 30), () {
        if (_metrics.isNotEmpty) {
          imprimirRelatorio();
          startMonitoramento(); // Continuar monitorando
        } else {
          startMonitoramento(); // Aguardar mais 30s
        }
      });
    }
  }

  static bool isOperacaoAtiva(String operacao) {
    return _stopwatches.containsKey(operacao);
  }

  static List<String> getOperacoesAtivas() {
    return _stopwatches.keys.toList();
  }

  static int getTempoAtual(String operacao) {
    final stopwatch = _stopwatches[operacao];
    if (stopwatch != null && stopwatch.isRunning) {
      return stopwatch.elapsedMilliseconds;
    }
    return 0;
  }
}
