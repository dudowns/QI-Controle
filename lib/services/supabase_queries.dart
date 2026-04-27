// lib/services/supabase_queries.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger_service.dart';

class SupabaseQueries {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // VIEWS
  // ============================================

  /// Resumo do mes via VIEW
  Future<Map<String, dynamic>?> getResumoMensalView(DateTime data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final mes = '${data.year}-${data.month.toString().padLeft(2, '0')}';

      final result = await _supabase
          .from('view_resumo_mensal')
          .select()
          .eq('user_id', userId)
          .eq('mes', mes)
          .maybeSingle();

      return result;
    } catch (e) {
      LoggerService.info('Erro getResumoMensalView: $e');
      return null;
    }
  }

  /// Resumo da carteira por tipo
  Future<List<Map<String, dynamic>>> getResumoCarteira() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase
          .from('view_resumo_carteira')
          .select()
          .eq('user_id', userId);

      return result;
    } catch (e) {
      LoggerService.info('Erro getResumoCarteira: $e');
      return [];
    }
  }

  /// Proximos proventos
  Future<List<Map<String, dynamic>>> getProximosProventos() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase
          .from('view_proximos_proventos')
          .select()
          .eq('user_id', userId)
          .order('data_pagamento');

      return result;
    } catch (e) {
      LoggerService.info('Erro getProximosProventos: $e');
      return [];
    }
  }

  // ============================================
  // FUNCOES SQL
  // ============================================

  /// Rentabilidade da carteira
  Future<Map<String, dynamic>> getRentabilidadeCarteira() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final result = await _supabase.rpc(
        'get_rentabilidade_carteira',
        params: {'p_user_id': userId},
      );

      if (result == null) return {};
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result[0]);
      }
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      LoggerService.info('Erro getRentabilidadeCarteira: $e');
      return {};
    }
  }

  /// Saldo por periodo
  Future<List<Map<String, dynamic>>> getSaldoPeriodo({
    required DateTime dataInicio,
    required DateTime dataFim,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_saldo_periodo',
        params: {
          'p_user_id': userId,
          'p_data_inicio': dataInicio.toIso8601String().split('T')[0],
          'p_data_fim': dataFim.toIso8601String().split('T')[0],
        },
      );

      if (result == null) return [];
      if (result is List) return List<Map<String, dynamic>>.from(result);
      return [];
    } catch (e) {
      LoggerService.info('Erro getSaldoPeriodo: $e');
      return [];
    }
  }

  /// Total de proventos por periodo
  Future<List<Map<String, dynamic>>> getTotalProventos({
    required DateTime dataInicio,
    required DateTime dataFim,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_total_proventos',
        params: {
          'p_user_id': userId,
          'p_data_inicio': dataInicio.toIso8601String().split('T')[0],
          'p_data_fim': dataFim.toIso8601String().split('T')[0],
        },
      );

      if (result == null) return [];
      if (result is List) return List<Map<String, dynamic>>.from(result);
      return [];
    } catch (e) {
      LoggerService.info('Erro getTotalProventos: $e');
      return [];
    }
  }

  /// Evolucao do patrimonio
  Future<List<Map<String, dynamic>>> getEvolucaoPatrimonio(int ano) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_evolucao_patrimonio',
        params: {'p_user_id': userId, 'p_ano': ano},
      );

      if (result == null) return [];
      if (result is List) return List<Map<String, dynamic>>.from(result);
      return [];
    } catch (e) {
      LoggerService.info('Erro getEvolucaoPatrimonio: $e');
      return [];
    }
  }

  /// Evolucao mensal (receitas/despesas)
  Future<List<Map<String, dynamic>>> getEvolucaoMensal(int ano) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_evolucao_mensal',
        params: {'p_user_id': userId, 'p_ano': ano},
      );

      if (result == null) return [];
      if (result is List) return List<Map<String, dynamic>>.from(result);
      if (result is Map) return [Map<String, dynamic>.from(result)];
      return [];
    } catch (e) {
      LoggerService.info('Erro getEvolucaoMensal: $e');
      return [];
    }
  }

  /// Resumo do mes (funcao RPC)
  Future<Map<String, dynamic>> getResumoMes(DateTime data) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final result = await _supabase.rpc(
        'get_resumo_mes',
        params: {
          'p_user_id': userId,
          'p_data': data.toIso8601String().split('T')[0],
        },
      );

      if (result == null) return {};
      if (result is List && result.isNotEmpty)
        return Map<String, dynamic>.from(result[0]);
      if (result is Map) return Map<String, dynamic>.from(result);
      return {};
    } catch (e) {
      LoggerService.info('Erro getResumoMes: $e');
      return {};
    }
  }

  /// Gastos por categoria com percentual
  Future<List<Map<String, dynamic>>> getGastosCategoriaPeriodo({
    required DateTime dataInicio,
    required DateTime dataFim,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_gastos_categoria',
        params: {
          'p_user_id': userId,
          'p_data_inicio': dataInicio.toIso8601String().split('T')[0],
          'p_data_fim': dataFim.toIso8601String().split('T')[0],
        },
      );

      if (result == null) return [];
      if (result is List) return List<Map<String, dynamic>>.from(result);
      if (result is Map) return [Map<String, dynamic>.from(result)];
      return [];
    } catch (e) {
      LoggerService.info('Erro getGastosCategoriaPeriodo: $e');
      return [];
    }
  }
}
