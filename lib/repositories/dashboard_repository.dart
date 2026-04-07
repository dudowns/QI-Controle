import '../services/logger_service.dart';
// lib/repositories/dashboard_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class DashboardRepository {
  final supabase = Supabase.instance.client;

  /// Buscar resumo do mês usando a função SQL
  Future<Map<String, dynamic>> getResumoMes(DateTime data) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não logado');

    try {
      final response = await supabase.rpc('get_resumo_mes', params: {
        'p_user_id': userId,
        'p_data': data.toIso8601String().split('T')[0],
      });

      LoggerService.info('📊 Resumo do mês: $response');

      if (response == null) {
        return {
          'receitas': 0.0,
          'despesas': 0.0,
          'saldo': 0.0,
          'totalLancamentos': 0,
        };
      }

      // 🔥 VERIFICAR SE A RESPOSTA É UMA LISTA
      dynamic dados = response;
      if (response is List && response.isNotEmpty) {
        dados = response.first;
      }

      return {
        'receitas': _toDouble(dados['receitas']),
        'despesas': _toDouble(dados['despesas']),
        'saldo': _toDouble(dados['saldo']),
        'totalLancamentos': _toInt(dados['total_lancamentos']),
      };
    } catch (e) {
      LoggerService.info('❌ Erro getResumoMes: $e');
      return {
        'receitas': 0.0,
        'despesas': 0.0,
        'saldo': 0.0,
        'totalLancamentos': 0,
      };
    }
  }

  /// Buscar gastos por categoria
  Future<List<Map<String, dynamic>>> getGastosPorCategoria(
    DateTime inicio,
    DateTime fim,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase.rpc('get_gastos_categoria', params: {
        'p_user_id': userId,
        'p_data_inicio': inicio.toIso8601String().split('T')[0],
        'p_data_fim': fim.toIso8601String().split('T')[0],
      });

      if (response == null || response.isEmpty) return [];

      return response.map<Map<String, dynamic>>((item) {
        return {
          'categoria': item['categoria']?.toString() ?? 'Outros',
          'total': _toDouble(item['total']),
          'percentual': _toDouble(item['percentual']),
        };
      }).toList();
    } catch (e) {
      LoggerService.info('❌ Erro getGastosPorCategoria: $e');
      return [];
    }
  }

  /// Buscar evolução mensal do ano
  Future<List<Map<String, dynamic>>> getEvolucaoMensal(int ano) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase.rpc('get_evolucao_mensal', params: {
        'p_user_id': userId,
        'p_ano': ano,
      });

      if (response == null || response.isEmpty) return [];

      return response.map<Map<String, dynamic>>((item) {
        return {
          'mes': _toInt(item['mes']),
          'receitas': _toDouble(item['receitas']),
          'despesas': _toDouble(item['despesas']),
          'saldo': _toDouble(item['saldo']),
        };
      }).toList();
    } catch (e) {
      LoggerService.info('❌ Erro getEvolucaoMensal: $e');
      return [];
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  // lib/repositories/dashboard_repository.dart
// ADICIONAR ESTE MÉTODO

  /// Buscar todos os lançamentos (fallback local)
  Future<List<Map<String, dynamic>>> getAllLancamentos() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('lancamentos')
          .select()
          .eq('user_id', userId)
          .order('data', ascending: false);

      return response ;
    } catch (e) {
      LoggerService.info('❌ Erro getAllLancamentos: $e');
      return [];
    }
  }
}

