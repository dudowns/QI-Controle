// lib/services/supabase_queries.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseQueries {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // VIEWS
  // ============================================

  /// Resumo do mês via VIEW
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
      debugPrint('Erro getResumoMensalView: $e');
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
      debugPrint('Erro getResumoCarteira: $e');
      return [];
    }
  }

  /// Próximos proventos
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
      debugPrint('Erro getProximosProventos: $e');
      return [];
    }
  }

  // ============================================
  // FUNÇÕES SQL (CORRIGIDAS)
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

      // 🔥 CORREÇÃO: verificar se é lista e pegar primeiro
      if (result == null) return {};
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result[0]);
      }
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      debugPrint('Erro getRentabilidadeCarteira: $e');
      return {};
    }
  }

  /// Saldo por período
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
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      debugPrint('Erro getSaldoPeriodo: $e');
      return [];
    }
  }

  /// Total de proventos por período
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
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      debugPrint('Erro getTotalProventos: $e');
      return [];
    }
  }

  /// Evolução do patrimônio
  Future<List<Map<String, dynamic>>> getEvolucaoPatrimonio(int ano) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_evolucao_patrimonio',
        params: {'p_user_id': userId, 'p_ano': ano},
      );

      if (result == null) return [];
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      debugPrint('Erro getEvolucaoPatrimonio: $e');
      return [];
    }
  }

  /// Evolução mensal (receitas/despesas) - CORRIGIDO
  Future<List<Map<String, dynamic>>> getEvolucaoMensal(int ano) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase.rpc(
        'get_evolucao_mensal',
        params: {'p_user_id': userId, 'p_ano': ano},
      );

      // 🔥 CORREÇÃO: resultado pode vir como List ou Map
      if (result == null) return [];
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      // Se for um único objeto, converte para lista
      if (result is Map) {
        return [Map<String, dynamic>.from(result)];
      }
      return [];
    } catch (e) {
      debugPrint('Erro getEvolucaoMensal: $e');
      return [];
    }
  }

  /// Resumo do mês (função RPC) - CORRIGIDO
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

      // 🔥 CORREÇÃO: resultado pode vir como List ou Map
      if (result == null) return {};
      if (result is List && result.isNotEmpty) {
        return Map<String, dynamic>.from(result[0]);
      }
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {};
    } catch (e) {
      debugPrint('Erro getResumoMes: $e');
      return {};
    }
  }

  /// Gastos por categoria com percentual - CORRIGIDO
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

      // 🔥 CORREÇÃO: tratar diferentes tipos de retorno
      if (result == null) return [];
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      if (result is Map) {
        return [Map<String, dynamic>.from(result)];
      }
      return [];
    } catch (e) {
      debugPrint('Erro getGastosCategoriaPeriodo: $e');
      return [];
    }
  }
}
