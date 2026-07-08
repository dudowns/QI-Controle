// lib/services/investment_insight_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/investimento_model.dart';

// ============================================
// CLASSE INVESTMENT INSIGHT
// ============================================
class InvestmentInsight {
  final String title;
  final String description;
  final InsightType type;
  final String emoji;
  final DateTime date;
  final String? actionLabel;
  final VoidCallback? onAction;

  InvestmentInsight({
    required this.title,
    required this.description,
    required this.type,
    required this.emoji,
    DateTime? date,
    this.actionLabel,
    this.onAction,
  }) : date = date ?? DateTime.now();

  Color get color {
    switch (type) {
      case InsightType.success:
        return const Color(0xFF22C55E);
      case InsightType.warning:
        return const Color(0xFFF59E0B);
      case InsightType.alert:
        return const Color(0xFFEF4444);
      case InsightType.info:
        return const Color(0xFF3B82F6);
      case InsightType.tip:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get icon {
    switch (type) {
      case InsightType.success:
        return Icons.emoji_events;
      case InsightType.warning:
        return Icons.warning_amber;
      case InsightType.alert:
        return Icons.error_outline;
      case InsightType.info:
        return Icons.info_outline;
      case InsightType.tip:
        return Icons.lightbulb_outline;
    }
  }
}

enum InsightType { warning, success, info, tip, alert }

// ============================================
// SERVICO DE INSIGHTS DE INVESTIMENTOS
// ============================================
class InvestmentInsightService {
  // ========== GERAR INSIGHTS DA CARTEIRA ==========
  List<InvestmentInsight> gerarInsights(List<Investimento> investimentos) {
    final insights = <InvestmentInsight>[];

    if (investimentos.isEmpty) {
      insights.add(InvestmentInsight(
        title: '💡 Comece a investir',
        description:
            'Sua carteira está vazia. Comece com investimentos de baixo risco como Tesouro Direto ou CDBs.',
        type: InsightType.info,
        emoji: '📈',
        actionLabel: 'Ver opções',
      ));
      return insights;
    }

    // 1. ANÁLISE DE DIVERSIFICAÇÃO
    _analisarDiversificacao(investimentos, insights);

    // 2. ANÁLISE DE CONCENTRAÇÃO
    _analisarConcentracao(investimentos, insights);

    // 3. ANÁLISE DE RENTABILIDADE
    _analisarRentabilidade(investimentos, insights);

    // 4. SUGESTÃO DE ALOCAÇÃO
    _sugerirAlocacao(investimentos, insights);

    // 5. ANÁLISE DE RISCO
    _analisarRisco(investimentos, insights);

    // 6. DICA DE MERCADO
    _dicaDeMercado(insights);

    // 7. CONSELHO PERSONALIZADO (sempre no final)
    _adicionarConselhoPersonalizado(investimentos, insights);

    // Ordenar por prioridade
    insights.sort((a, b) {
      final ordem = {
        InsightType.alert: 0,
        InsightType.warning: 1,
        InsightType.tip: 2,
        InsightType.info: 3,
        InsightType.success: 4,
      };
      return ordem[a.type]!.compareTo(ordem[b.type]!);
    });

    // Limitar a 5 insights
    if (insights.length > 5) {
      insights.removeRange(5, insights.length);
    }

    return insights;
  }

  // ========== ANÁLISE DE DIVERSIFICAÇÃO ==========
  void _analisarDiversificacao(
      List<Investimento> investimentos, List<InvestmentInsight> insights) {
    final tipos = <String, int>{};
    for (var inv in investimentos) {
      final tipo = inv.tipo.toUpperCase();
      tipos[tipo] = (tipos[tipo] ?? 0) + 1;
    }

    if (tipos.length < 2) {
      insights.add(InvestmentInsight(
        title: '⚠️ Carteira pouco diversificada',
        description:
            'Você tem apenas ${tipos.keys.first}. Considere diversificar entre Ações, FIIs e Renda Fixa para reduzir riscos.',
        type: InsightType.warning,
        emoji: '📊',
        actionLabel: 'Ver opções',
      ));
    } else if (tipos.length >= 3) {
      insights.add(InvestmentInsight(
        title: '✅ Boa diversificação',
        description:
            'Sua carteira está bem diversificada em ${tipos.length} tipos diferentes de ativos. Continue assim!',
        type: InsightType.success,
        emoji: '🌟',
      ));
    }
  }

  // ========== ANÁLISE DE CONCENTRAÇÃO ==========
  void _analisarConcentracao(
      List<Investimento> investimentos, List<InvestmentInsight> insights) {
    if (investimentos.isEmpty) return;

    double total = 0;
    for (var inv in investimentos) {
      total += inv.valorAtual;
    }

    if (total == 0) return;

    for (var inv in investimentos) {
      final percentual = (inv.valorAtual / total) * 100;
      if (percentual > 50) {
        insights.add(InvestmentInsight(
          title: '⚠️ Alta concentração em ${inv.ticker}',
          description:
              '${inv.ticker} representa ${percentual.toStringAsFixed(1)}% da sua carteira. Considere reduzir a exposição.',
          type: InsightType.alert,
          emoji: '🎯',
          actionLabel: 'Ver detalhes',
        ));
        break;
      }
    }
  }

  // ========== ANÁLISE DE RENTABILIDADE ==========
  void _analisarRentabilidade(
      List<Investimento> investimentos, List<InvestmentInsight> insights) {
    double totalInvestido = 0;
    double totalAtual = 0;
    int ativosPositivos = 0;
    int ativosNegativos = 0;

    for (var inv in investimentos) {
      totalInvestido += inv.valorInvestido;
      totalAtual += inv.valorAtual;
      if (inv.variacaoTotal >= 0) {
        ativosPositivos++;
      } else {
        ativosNegativos++;
      }
    }

    if (totalInvestido == 0) return;

    final rentabilidade =
        ((totalAtual - totalInvestido) / totalInvestido) * 100;

    if (rentabilidade > 20) {
      insights.add(InvestmentInsight(
        title: '🚀 Excelente rentabilidade!',
        description:
            'Sua carteira valorizou ${rentabilidade.toStringAsFixed(1)}%. Acima da média do mercado!',
        type: InsightType.success,
        emoji: '📈',
      ));
    } else if (rentabilidade < -10) {
      insights.add(InvestmentInsight(
        title: '📉 Rentabilidade negativa',
        description:
            'Sua carteira caiu ${(-rentabilidade).toStringAsFixed(1)}%. Avalie seus ativos ou considere diversificar.',
        type: InsightType.alert,
        emoji: '📉',
        actionLabel: 'Analisar ativos',
      ));
    } else if (rentabilidade >= 0 && rentabilidade < 5) {
      insights.add(InvestmentInsight(
        title: '📊 Rentabilidade estável',
        description:
            'Sua carteira está com rentabilidade de ${rentabilidade.toStringAsFixed(1)}%. Busque ativos com maior potencial.',
        type: InsightType.tip,
        emoji: '💡',
        actionLabel: 'Ver sugestões',
      ));
    }

    if (ativosNegativos > ativosPositivos) {
      insights.add(InvestmentInsight(
        title: '⚠️ Muitos ativos negativos',
        description:
            '${ativosNegativos} de ${investimentos.length} ativos estão com rentabilidade negativa. Revise sua estratégia.',
        type: InsightType.warning,
        emoji: '🔍',
      ));
    }
  }

  // ========== SUGESTÃO DE ALOCAÇÃO ==========
  void _sugerirAlocacao(
      List<Investimento> investimentos, List<InvestmentInsight> insights) {
    double total = 0;
    double emAcoes = 0;
    double emFIIs = 0;
    double emCripto = 0;

    for (var inv in investimentos) {
      total += inv.valorAtual;
      final tipo = inv.tipo.toUpperCase();
      if (tipo == 'ACAO')
        emAcoes += inv.valorAtual;
      else if (tipo == 'FII')
        emFIIs += inv.valorAtual;
      else if (tipo == 'CRIPTO') emCripto += inv.valorAtual;
    }

    if (total == 0) return;

    final percAcoes = (emAcoes / total) * 100;
    final percFIIs = (emFIIs / total) * 100;
    final percCripto = (emCripto / total) * 100;

    if (percAcoes > 70) {
      insights.add(InvestmentInsight(
        title: '💡 Carteira agressiva',
        description:
            'Sua carteira tem ${percAcoes.toStringAsFixed(0)}% em ações. Considere aumentar a exposição a FIIs para mais estabilidade.',
        type: InsightType.tip,
        emoji: '⚖️',
      ));
    } else if (percFIIs > 60) {
      insights.add(InvestmentInsight(
        title: '💡 Carteira conservadora',
        description:
            'Sua carteira tem ${percFIIs.toStringAsFixed(0)}% em FIIs. Considere ações para maior potencial de valorização.',
        type: InsightType.tip,
        emoji: '📊',
      ));
    }

    if (percCripto > 20) {
      insights.add(InvestmentInsight(
        title: '⚠️ Alta exposição a cripto',
        description:
            'Criptomoedas representam ${percCripto.toStringAsFixed(0)}% da sua carteira. Considere reduzir o risco.',
        type: InsightType.warning,
        emoji: '₿',
      ));
    }
  }

  // ========== ANÁLISE DE RISCO ==========
  void _analisarRisco(
      List<Investimento> investimentos, List<InvestmentInsight> insights) {
    int ativosVolateis = 0;
    for (var inv in investimentos) {
      final variacao = inv.variacaoPercentual.abs();
      if (variacao > 20) ativosVolateis++;
    }

    if (ativosVolateis > investimentos.length * 0.5 &&
        investimentos.length > 0) {
      insights.add(InvestmentInsight(
        title: '⚠️ Alta volatilidade',
        description:
            'Mais de 50% dos seus ativos têm alta volatilidade. Considere ativos menos voláteis para balancear.',
        type: InsightType.warning,
        emoji: '🌊',
      ));
    }
  }

  // ========== DICA DE MERCADO ==========
  void _dicaDeMercado(List<InvestmentInsight> insights) {
    final dicas = [
      '📈 O mercado está aquecido para ações de tecnologia. Avalie oportunidades!',
      '💰 FIIs de logística têm apresentado boa rentabilidade no último semestre.',
      '📊 Considere a estratégia de "Dollar Cost Averaging" para reduzir riscos.',
      '🏦 O CDI está em alta - ótimo momento para renda fixa!',
      '🌍 Diversifique com ETFs internacionais para proteção cambial.',
      '📉 Com a inflação controlada, setor de consumo pode se beneficiar.',
      '⚡ Energia renovável é um setor promissor para longo prazo.',
      '🏠 FIIs de shopping centers estão se recuperando pós-pandemia.',
      '📈 Small caps podem oferecer maior potencial de valorização.',
      '💰 Dividendos são uma ótima fonte de renda passiva.',
    ];

    final random = Random();
    final dica = dicas[random.nextInt(dicas.length)];

    insights.add(InvestmentInsight(
      title: '💡 Dica de Mercado',
      description: dica,
      type: InsightType.info,
      emoji: '📰',
    ));
  }

  // ========== CONSELHO PERSONALIZADO ==========
  void _adicionarConselhoPersonalizado(
      List<Investimento> investimentos, List<InvestmentInsight> insights) {
    final conselho = getConselhoPersonalizado(investimentos);
    if (conselho.isNotEmpty) {
      insights.add(InvestmentInsight(
        title: '🎯 Conselho Personalizado',
        description: conselho,
        type: InsightType.tip,
        emoji: '🤖',
      ));
    }
  }

  String getConselhoPersonalizado(List<Investimento> investimentos) {
    if (investimentos.isEmpty) {
      return 'Comece sua jornada de investimentos com ativos de baixo risco como CDBs e Tesouro Direto.';
    }

    double totalInvestido = 0;
    double totalAtual = 0;

    for (var inv in investimentos) {
      totalInvestido += inv.valorInvestido;
      totalAtual += inv.valorAtual;
    }

    if (totalInvestido == 0)
      return 'Sua carteira está zerada. Comece com pequenos aportes.';

    final rentabilidade =
        ((totalAtual - totalInvestido) / totalInvestido) * 100;

    if (rentabilidade > 15) {
      return '🎉 Excelente desempenho! Sua carteira está superando a inflação. Continue com a estratégia atual.';
    } else if (rentabilidade > 5) {
      return '📈 Bom desempenho. Sua carteira está no caminho certo. Considere aumentar os aportes.';
    } else if (rentabilidade > 0) {
      return '📊 Rentabilidade positiva, mas abaixo do esperado. Reveja a alocação dos ativos.';
    } else {
      return '📉 Rentabilidade negativa. É hora de revisar sua estratégia de investimentos.';
    }
  }

  // ========== MENSAGEM MOTIVACIONAL PARA INVESTIMENTOS ==========
  String getMensagemMotivacional() {
    final mensagens = [
      '📈 O melhor momento para investir foi ontem. O segundo melhor é hoje!',
      '💰 A paciência é a chave para o sucesso nos investimentos.',
      '📊 Diversificar é a única forma de reduzir riscos sem perder rentabilidade.',
      '🏦 Pequenos aportes consistentes constroem grandes patrimônios.',
      '🌱 Invista em conhecimento: é o investimento que nunca desvaloriza.',
      '📉 As crises são oportunidades disfarçadas para investidores de longo prazo.',
      '🎯 Foco no processo, não na volatilidade do dia a dia.',
      '💰 O dinheiro é um péssimo senhor, mas um excelente servo.',
    ];
    return mensagens[Random().nextInt(mensagens.length)];
  }

  // ========== PREVISÃO DE RETORNO (SIMULADA) ==========
  double preverRetornoAnual(List<Investimento> investimentos) {
    if (investimentos.isEmpty) return 0;

    double totalAtual = 0;
    for (var inv in investimentos) {
      totalAtual += inv.valorAtual;
    }

    // Simula uma previsão com base na composição da carteira
    double taxaMedia = 0.08; // 8% ao ano
    int countAcoes = 0;
    int countFIIs = 0;

    for (var inv in investimentos) {
      final tipo = inv.tipo.toUpperCase();
      if (tipo == 'ACAO')
        countAcoes++;
      else if (tipo == 'FII') countFIIs++;
    }

    if (countAcoes > countFIIs) {
      taxaMedia = 0.12; // Mais ações = maior risco/retorno
    } else if (countFIIs > countAcoes) {
      taxaMedia = 0.09; // Mais FIIs = retorno estável
    }

    // Adiciona uma pequena variação aleatória
    final variacao = 1 + (Random().nextDouble() * 0.04 - 0.02);
    return totalAtual * taxaMedia * variacao;
  }
}
