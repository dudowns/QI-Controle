// lib/services/renda_fixa_diaria.dart
import 'dart:math';
import '../models/renda_fixa_model.dart';

class RendaFixaDiaria {
  // CDI atual
  static const double cdiAnual = 14.65; // %

  // CDI diário (juros compostos)
  static double get cdiDiario {
    // (1 + CDI)^(1/252) - 1
    return pow(1 + (cdiAnual / 100), 1 / 252) - 1;
  }

  // Calcular valor em uma data específica
  static double calcularValorEm(
    RendaFixaModel investimento,
    DateTime data,
  ) {
    if (data.isBefore(investimento.dataAplicacao)) {
      return investimento.valorAplicado;
    }

    // Dias úteis entre a aplicação e a data
    final diasUteis = _calcularDiasUteis(
      investimento.dataAplicacao,
      data,
    );

    double valorAtual = investimento.valorAplicado;

    for (int i = 1; i <= diasUteis; i++) {
      final rendimentoHoje = _calcularRendimentoDiario(
        valorAtual,
        investimento,
      );
      valorAtual += rendimentoHoje;
    }

    return valorAtual;
  }

  // Calcular rendimento de um único dia
  static double _calcularRendimentoDiario(
    double valor,
    RendaFixaModel inv,
  ) {
    switch (inv.indexador) {
      case Indexador.preFixado:
        // Taxa diária: (1 + taxaAnual)^(1/252) - 1
        final taxaDiaria = pow(1 + (inv.taxa / 100), 1 / 252) - 1;
        return valor * taxaDiaria;

      case Indexador.posFixadoCDI:
        // % do CDI aplicado ao CDI diário
        final percentual = inv.taxa / 100;
        return valor * cdiDiario * percentual;

      case Indexador.ipca:
        // IPCA + taxa real (simplificado)
        // Aqui você pode buscar IPCA real de uma API
        const double ipcaDiario = 0.016; // ~4,5% ao ano / 252
        final taxaRealDiaria = pow(1 + (inv.taxa / 100), 1 / 252) - 1;
        return valor * (ipcaDiario + taxaRealDiaria);
    }
  }

  // Calcular dias úteis entre duas datas
  static int _calcularDiasUteis(DateTime inicio, DateTime fim) {
    int diasUteis = 0;
    DateTime atual = inicio;

    while (atual.isBefore(fim) || atual.isAtSameMomentAs(fim)) {
      // Pular sábado (6) e domingo (7)
      if (atual.weekday != DateTime.saturday &&
          atual.weekday != DateTime.sunday) {
        diasUteis++;
      }
      atual = atual.add(const Duration(days: 1));
    }
    return diasUteis;
  }

  // Gerar evolução diária para gráfico
  static List<Map<String, dynamic>> gerarEvolucaoDiaria(
    RendaFixaModel investimento, {
    int maxPontos = 30,
  }) {
    final hoje = DateTime.now();
    final dataFinal = hoje.isBefore(investimento.dataVencimento)
        ? hoje
        : investimento.dataVencimento;

    final diasTotais = dataFinal.difference(investimento.dataAplicacao).inDays;
    final intervalo = (diasTotais / maxPontos).ceil();

    List<Map<String, dynamic>> evolucao = [];

    for (int i = 0; i <= diasTotais; i += intervalo) {
      final data = investimento.dataAplicacao.add(Duration(days: i));
      if (data.isAfter(dataFinal)) break;

      final valor = calcularValorEm(investimento, data);
      evolucao.add({
        'data': data,
        'valor': valor,
        'rendimento': valor - investimento.valorAplicado,
      });
    }

    // Garantir que tenha o valor atual
    if (!evolucao.any((e) =>
        e['data'].year == hoje.year &&
        e['data'].month == hoje.month &&
        e['data'].day == hoje.day)) {
      evolucao.add({
        'data': hoje,
        'valor': calcularValorEm(investimento, hoje),
        'rendimento':
            calcularValorEm(investimento, hoje) - investimento.valorAplicado,
        'hoje': true,
      });
      evolucao.sort((a, b) => a['data'].compareTo(b['data']));
    }

    return evolucao;
  }

  // Calcular IR sobre o rendimento até hoje
  static double calcularIRParcial(
    RendaFixaModel investimento,
    DateTime data,
  ) {
    if (investimento.isIsento) return 0;

    final valorHoje = calcularValorEm(investimento, data);
    final rendimento = valorHoje - investimento.valorAplicado;

    final diasUteis = _calcularDiasUteis(investimento.dataAplicacao, data);

    // Usa a mesma tabela regressiva
    double aliquota;
    if (diasUteis <= 180) {
      aliquota = 0.225;
    } else if (diasUteis <= 360) {
      aliquota = 0.20;
    } else if (diasUteis <= 720) {
      aliquota = 0.175;
    } else {
      aliquota = 0.15;
    }

    return rendimento * aliquota;
  }
}
