// lib/services/insight_service.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/logger_service.dart';

// ============================================
// CLASSE INSIGHT
// ============================================
class Insight {
  final String title;
  final String description;
  final InsightType type;
  final String emoji;
  final DateTime date;
  final String? actionLabel;
  final VoidCallback? onAction;

  Insight({
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

enum InsightType {
  warning,
  success,
  info,
  tip,
  alert,
}

// ============================================
// SERVICO DE INSIGHTS
// ============================================
class InsightService {
  final DBHelper _dbHelper = DBHelper();

  Future<List<Insight>> gerarInsights({
    required List<Map<String, dynamic>> lancamentos,
    required List<Map<String, dynamic>> metas,
    required double totalReceitas,
    required double totalDespesas,
    required DateTime mesSelecionado,
  }) async {
    final insights = <Insight>[];

    try {
      // 1. INSIGHT DE SALDO
      final saldo = totalReceitas - totalDespesas;
      if (saldo < 0) {
        insights.add(Insight(
          title: '⚠️ Gastos acima da renda',
          description:
              'Você gastou R\$ ${(-saldo).toStringAsFixed(2)} a mais do que ganhou este mês. Revise seus gastos!',
          type: InsightType.alert,
          emoji: '📉',
        ));
      } else if (saldo > 0 && saldo < totalReceitas * 0.1) {
        insights.add(Insight(
          title: '💡 Economia baixa',
          description:
              'Você economizou apenas ${(saldo / totalReceitas * 100).toStringAsFixed(1)}% da sua renda. Tente economizar mais!',
          type: InsightType.warning,
          emoji: '💡',
        ));
      } else if (saldo > totalReceitas * 0.3) {
        insights.add(Insight(
          title: '🎉 Excelente economia!',
          description:
              'Você economizou ${(saldo / totalReceitas * 100).toStringAsFixed(1)}% da sua renda. Continue assim!',
          type: InsightType.success,
          emoji: '🚀',
        ));
      }

      // 2. INSIGHT DE METAS
      final metasEmAndamento = metas.where((m) => m['concluida'] == 0).toList();
      final metasConcluidas = metas.where((m) => m['concluida'] == 1).toList();

      if (metasEmAndamento.isNotEmpty) {
        final metaMaisProxima = metasEmAndamento.reduce((a, b) {
          final progressA =
              (a['valor_atual'] ?? 0) / (a['valor_objetivo'] ?? 1);
          final progressB =
              (b['valor_atual'] ?? 0) / (b['valor_objetivo'] ?? 1);
          return progressA > progressB ? a : b;
        });

        final progresso = ((metaMaisProxima['valor_atual'] ?? 0) /
                (metaMaisProxima['valor_objetivo'] ?? 1) *
                100)
            .clamp(0, 100);
        if (progresso > 80) {
          insights.add(Insight(
            title: '🎯 Meta quase lá!',
            description:
                'A meta "${metaMaisProxima['titulo']}" está em ${progresso.toStringAsFixed(0)}% concluída. Continue firme!',
            type: InsightType.success,
            emoji: '🎯',
          ));
        }
      }

      if (metasConcluidas.isNotEmpty) {
        insights.add(Insight(
          title: '🏆 Parabéns!',
          description:
              'Você concluiu ${metasConcluidas.length} ${metasConcluidas.length == 1 ? 'meta' : 'metas'}! Que conquista!',
          type: InsightType.success,
          emoji: '🏆',
        ));
      }

      // 3. INSIGHT DE GASTOS POR CATEGORIA
      final gastosPorCategoria = <String, double>{};
      for (var l in lancamentos) {
        if (l['tipo'] != 'receita') {
          final categoria = l['categoria']?.toString() ?? 'Outros';
          final valor = (l['valor'] ?? 0).toDouble();
          gastosPorCategoria[categoria] =
              (gastosPorCategoria[categoria] ?? 0) + valor;
        }
      }

      if (gastosPorCategoria.isNotEmpty) {
        final maiorGasto = gastosPorCategoria.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        final percentual = (maiorGasto.value / totalDespesas * 100);
        if (percentual > 40) {
          insights.add(Insight(
            title: '⚠️ Gasto concentrado',
            description:
                '${maiorGasto.key} representa ${percentual.toStringAsFixed(0)}% dos seus gastos. Considere diversificar!',
            type: InsightType.warning,
            emoji: '📊',
          ));
        }

        final categoriasCaras =
            gastosPorCategoria.entries.where((e) => e.value > 200).toList();
        if (categoriasCaras.isNotEmpty) {
          final sugestao = categoriasCaras.first;
          insights.add(Insight(
            title: '💡 Dica de economia',
            description:
                'Gastos com ${sugestao.key} somam R\$ ${(sugestao.value).toStringAsFixed(2)}. Tente reduzir este mês!',
            type: InsightType.tip,
            emoji: '💰',
          ));
        }
      }

      // 4. INSIGHT DE TENDÊNCIA
      final mesAnterior =
          DateTime(mesSelecionado.year, mesSelecionado.month - 1);
      final lancamentosMesAnterior = await _dbHelper.query(
        DBHelper.tabelaLancamentos,
        where: "strftime('%Y-%m', data) = ?",
        whereArgs: [
          '${mesAnterior.year}-${mesAnterior.month.toString().padLeft(2, '0')}'
        ],
      );

      if (lancamentosMesAnterior.isNotEmpty) {
        double despesasAnterior = 0;
        for (var l in lancamentosMesAnterior) {
          if (l['tipo'] != 'receita') {
            despesasAnterior += (l['valor'] ?? 0).toDouble();
          }
        }

        if (despesasAnterior > 0) {
          final variacao =
              ((totalDespesas - despesasAnterior) / despesasAnterior * 100);
          if (variacao > 20) {
            insights.add(Insight(
              title: '📈 Gastos aumentaram',
              description:
                  'Seus gastos aumentaram ${variacao.toStringAsFixed(0)}% em relação ao mês passado. Atenção!',
              type: InsightType.alert,
              emoji: '📈',
            ));
          } else if (variacao < -20) {
            insights.add(Insight(
              title: '📉 Gastos diminuíram',
              description:
                  'Seus gastos diminuíram ${(-variacao).toStringAsFixed(0)}% em relação ao mês passado. Ótimo trabalho!',
              type: InsightType.success,
              emoji: '📉',
            ));
          }
        }
      }

      // 5. INSIGHT DE PROVENTOS
      final proventos = await _dbHelper.query(
        DBHelper.tabelaProventos,
        where: "strftime('%Y-%m', data_pagamento) = ?",
        whereArgs: [
          '${mesSelecionado.year}-${mesSelecionado.month.toString().padLeft(2, '0')}'
        ],
      );

      if (proventos.isNotEmpty) {
        double totalProventos = 0;
        for (var p in proventos) {
          totalProventos += (p['total_recebido'] ?? 0).toDouble();
        }
        if (totalProventos > 0) {
          insights.add(Insight(
            title: '💰 Proventos recebidos',
            description:
                'Você recebeu R\$ ${totalProventos.toStringAsFixed(2)} em proventos este mês!',
            type: InsightType.success,
            emoji: '💰',
          ));
        }
      }

      // 6. INSIGHT DE GASTO MÉDIO DIÁRIO
      final diasNoMes =
          DateTime(mesSelecionado.year, mesSelecionado.month + 1, 0).day;
      final gastoDiario = totalDespesas / diasNoMes;
      if (gastoDiario > 100) {
        insights.add(Insight(
          title: '📊 Gasto diário elevado',
          description:
              'Seu gasto médio diário é de R\$ ${gastoDiario.toStringAsFixed(2)}. Tente reduzir!',
          type: InsightType.warning,
          emoji: '📊',
        ));
      } else if (gastoDiario < 50 && totalReceitas > 0) {
        insights.add(Insight(
          title: '🌟 Gasto diário controlado',
          description:
              'Seu gasto médio diário é de R\$ ${gastoDiario.toStringAsFixed(2)}. Muito bem!',
          type: InsightType.success,
          emoji: '🌟',
        ));
      }

      if (insights.length > 5) {
        insights.removeRange(5, insights.length);
      }

      insights.sort((a, b) {
        final ordem = {
          InsightType.alert: 0,
          InsightType.warning: 1,
          InsightType.info: 2,
          InsightType.tip: 3,
          InsightType.success: 4,
        };
        return ordem[a.type]!.compareTo(ordem[b.type]!);
      });
    } catch (e) {
      LoggerService.error('Erro ao gerar insights: $e');
    }

    return insights;
  }

  String getMensagemMotivacional() {
    final mensagens = [
      '💪 Você está no controle das suas finanças!',
      '🌟 Cada real economizado é um passo para seus sonhos!',
      '🚀 Pequenas economias hoje, grandes conquistas amanhã!',
      '💰 O dinheiro é um ótimo servo, mas um péssimo senhor!',
      '🎯 Foco na meta, disciplina no processo!',
      '📈 Investir em conhecimento sempre rende os melhores juros!',
      '🏆 A riqueza vem de hábitos, não de heranças!',
      '🌟 Seu futuro financeiro começa com as escolhas de hoje!',
    ];
    return mensagens[Random().nextInt(mensagens.length)];
  }

  String getConselhoFinanceiro(double saldo, double renda, double despesas) {
    if (saldo < 0) {
      return '⚠️ Você está gastando mais do que ganha. Revise seus gastos fixos e corte o que for desnecessário.';
    } else if (saldo < renda * 0.1) {
      return '💡 Tente economizar pelo menos 10% da sua renda. Comece com pequenos cortes!';
    } else if (saldo > renda * 0.3) {
      return '🌟 Excelente! Você está economizando mais de 30%. Considere investir esse dinheiro.';
    } else {
      return '📊 Você está no caminho certo. Mantenha o controle dos seus gastos!';
    }
  }

  Future<double> preverGastosProximoMes() async {
    try {
      final lancamentos = await _dbHelper.query(
        DBHelper.tabelaLancamentos,
        orderBy: 'data DESC',
        limit: 100,
      );

      final hoje = DateTime.now();
      final meses = <String, double>{};

      for (var l in lancamentos) {
        if (l['tipo'] == 'receita') continue;
        final data = DateTime.parse(l['data'].toString());
        final mesKey = '${data.year}-${data.month.toString().padLeft(2, '0')}';
        final valor = (l['valor'] ?? 0).toDouble();

        if (data.isAfter(hoje.subtract(const Duration(days: 90)))) {
          meses[mesKey] = (meses[mesKey] ?? 0) + valor;
        }
      }

      if (meses.isEmpty) return 0;

      final valores = meses.values.toList();
      final soma = valores.fold(0.0, (a, b) => a + b);
      final media = soma / valores.length;

      final variacao = 1 + (Random().nextDouble() * 0.2 - 0.1);
      return media * variacao;
    } catch (e) {
      LoggerService.error('Erro ao prever gastos: $e');
      return 0;
    }
  }
}
