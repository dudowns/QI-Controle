import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDatabaseService {
  final _supabase = Supabase.instance.client;

  // Busca o resumo do patrimônio da VIEW
  Future<Map<String, dynamic>> getResumoPatrimonio() async {
    final response =
        await _supabase.from('view_resumo_patrimonio').select().maybeSingle();
    return response ??
        {
          'total_investido': 0,
          'valor_atual': 0,
          'ganho_perda': 0,
          'total_ativos': 0
        };
  }

  // Chama a FUNÇÃO RPC para o resumo do mês
  Future<Map<String, dynamic>> getResumoMes(DateTime data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};

    final List<dynamic> response = await _supabase.rpc(
      'get_resumo_mes',
      params: {
        'p_user_id': userId,
        'p_data': "${data.year}-${data.month.toString().padLeft(2, '0')}-01",
      },
    );

    return response.isNotEmpty ? response.first : {};
  }
}
