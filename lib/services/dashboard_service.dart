// lib/services/dashboard_service.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class DashboardService {
  final DBHelper _dbHelper = DBHelper();

  Future<Map<String, dynamic>> getMetricasRapidas() async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery('''
      SELECT 
        (SELECT COALESCE(SUM(CASE WHEN tipo = 'receita' THEN valor ELSE 0 END), 0) 
         FROM lancamentos WHERE strftime('%Y-%m', data) = strftime('%Y-%m', 'now')) as receitas_mes,
        (SELECT COALESCE(SUM(CASE WHEN tipo = 'gasto' THEN valor ELSE 0 END), 0) 
         FROM lancamentos WHERE strftime('%Y-%m', data) = strftime('%Y-%m', 'now')) as despesas_mes,
        (SELECT COUNT(*) FROM metas WHERE concluida = 0) as metas_ativas,
        (SELECT COUNT(*) FROM pagamentos_mensais WHERE status = 0 
         AND substr(ano_mes, 1, 4) = strftime('%Y', 'now') 
         AND substr(ano_mes, 5, 2) = strftime('%m', 'now')) as contas_pendentes
    ''');

    return {
      'receitas_mes': (result.first['receitas_mes'] as num?)?.toDouble() ?? 0,
      'despesas_mes': (result.first['despesas_mes'] as num?)?.toDouble() ?? 0,
      'metas_ativas': (result.first['metas_ativas'] as int?) ?? 0,
      'contas_pendentes': (result.first['contas_pendentes'] as int?) ?? 0,
    };
  }

  Future<double> getSaldoTotal() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN tipo = 'receita' THEN valor ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN tipo = 'gasto' THEN valor ELSE 0 END), 0) as saldo
      FROM lancamentos
    ''');
    return (result.first['saldo'] as num?)?.toDouble() ?? 0;
  }
}
