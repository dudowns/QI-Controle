import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final supabase = Supabase.instance.client;

  /// Buscar resumo do mês usando a função SQL
  Future<Map<String, dynamic>> getResumoMes(DateTime data) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não logado');

    final response = await supabase.rpc('get_resumo_mes', params: {
      'p_user_id': userId,
      'p_data': data.toIso8601String().split('T')[0],
    });

    return {
      'receitas': (response['receitas'] as num).toDouble(),
      'despesas': (response['despesas'] as num).toDouble(),
      'saldo': (response['saldo'] as num).toDouble(),
      'totalLancamentos': response['total_lancamentos'],
    };
  }

  /// Buscar gastos por categoria
  Future<List<Map<String, dynamic>>> getGastosPorCategoria(
    DateTime inicio,
    DateTime fim,
  ) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não logado');

    final response = await supabase.rpc('get_gastos_categoria', params: {
      'p_user_id': userId,
      'p_data_inicio': inicio.toIso8601String().split('T')[0],
      'p_data_fim': fim.toIso8601String().split('T')[0],
    });

    return response
        .map<Map<String, dynamic>>((item) => {
              'categoria': item['categoria'],
              'total': (item['total'] as num).toDouble(),
              'percentual': (item['percentual'] as num).toDouble(),
            })
        .toList();
  }

  /// Buscar evolução mensal do ano
  Future<List<Map<String, dynamic>>> getEvolucaoMensal(int ano) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não logado');

    final response = await supabase.rpc('get_evolucao_mensal', params: {
      'p_user_id': userId,
      'p_ano': ano,
    });

    return response
        .map<Map<String, dynamic>>((item) => {
              'mes': item['mes'],
              'receitas': (item['receitas'] as num).toDouble(),
              'despesas': (item['despesas'] as num).toDouble(),
              'saldo': (item['saldo'] as num).toDouble(),
            })
        .toList();
  }
}
