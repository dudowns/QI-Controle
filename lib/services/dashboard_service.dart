// lib/services/dashboard_service.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../services/logger_service.dart';

class DashboardService {
  final DBHelper _dbHelper = DBHelper();

  Future<Map<String, dynamic>> getMetricasRapidas() async {
    final db = await _dbHelper.database;

    try {
      final result = await db.rawQuery('''
        SELECT 
          (SELECT COALESCE(SUM(CASE WHEN tipo = 'receita' THEN valor ELSE 0 END), 0) 
           FROM lancamentos WHERE strftime('%Y-%m', data) = strftime('%Y-%m', 'now')) as receitas_mes,
          (SELECT COALESCE(SUM(CASE WHEN tipo = 'gasto' THEN valor ELSE 0 END), 0) 
           FROM lancamentos WHERE strftime('%Y-%m', data) = strftime('%Y-%m', 'now')) as despesas_mes,
          (SELECT COUNT(*) FROM metas WHERE concluida = 0) as metas_ativas
      ''').timeout(const Duration(seconds: 5));

      return {
        'receitas_mes': (result.first['receitas_mes'] as num?)?.toDouble() ?? 0,
        'despesas_mes': (result.first['despesas_mes'] as num?)?.toDouble() ?? 0,
        'metas_ativas': (result.first['metas_ativas'] as int?) ?? 0,
      };
    } catch (e) {
      LoggerService.error('Erro ao carregar métricas rápidas: $e');
      return {
        'receitas_mes': 0.0,
        'despesas_mes': 0.0,
        'metas_ativas': 0,
      };
    }
  }

  // ✅ NOVO MÉTODO: Buscar contas pendentes por mês específico
  Future<Map<String, dynamic>> getContasPendentesPorMes(
      int ano, int mes) async {
    final db = await _dbHelper.database;
    try {
      final anoMes = ano * 100 + mes;

      LoggerService.info(
          '🔍 Buscando contas pendentes para $ano/$mes (anoMes=$anoMes)');

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as quantidade,
          COALESCE(SUM(valor), 0) as valor_total
        FROM pagamentos_mensais 
        WHERE status = 0 AND ano_mes = ?
      ''', [anoMes]).timeout(const Duration(seconds: 5));

      final quantidade = (result.first['quantidade'] as int?) ?? 0;
      final valorTotal = (result.first['valor_total'] as num?)?.toDouble() ?? 0;

      LoggerService.info(
          '📊 Encontradas $quantidade contas pendentes (R\$ $valorTotal)');

      return {
        'quantidade': quantidade,
        'valor_total': valorTotal,
      };
    } catch (e) {
      LoggerService.error('Erro ao buscar contas pendentes: $e');
      return {
        'quantidade': 0,
        'valor_total': 0.0,
      };
    }
  }

  Future<double> getSaldoTotal() async {
    final db = await _dbHelper.database;
    try {
      final result = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(CASE WHEN tipo = 'receita' THEN valor ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN tipo = 'gasto' THEN valor ELSE 0 END), 0) as saldo
        FROM lancamentos
      ''').timeout(const Duration(seconds: 5));

      return (result.first['saldo'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      LoggerService.error('Erro ao calcular saldo total: $e');
      return 0;
    }
  }
}
