// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lancamento_model.dart';
import '../models/investimento_model.dart';
import '../models/meta_model.dart';
import '../models/provento_model.dart';
import '../models/renda_fixa_model.dart';
import '../models/transacao_model.dart';
import '../models/conta_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  String get currentUserId {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Usuário não logado');
    return user.id;
  }

  // ==================== LANÇAMENTOS ====================

  Future<List<Lancamento>> getLancamentos() async {
    try {
      final response = await client
          .from('lancamentos')
          .select()
          .eq('user_id', currentUserId)
          .order('data', ascending: false);

      return response.map((json) => Lancamento.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar lançamentos: $e');
      return [];
    }
  }

  Future<void> addLancamento(Lancamento lancamento) async {
    final json = lancamento.toJson();
    json['user_id'] = currentUserId;
    await client.from('lancamentos').insert(json);
  }

  Future<void> updateLancamento(Lancamento lancamento) async {
    if (lancamento.id == null) throw Exception('ID não pode ser nulo');
    final json = lancamento.toJson();
    json.remove('id');
    await client.from('lancamentos').update(json).eq('id', lancamento.id!);
  }

  Future<void> deleteLancamento(String id) async {
    await client.from('lancamentos').delete().eq('id', id);
  }

  // ==================== INVESTIMENTOS ====================

  Future<List<Investimento>> getInvestimentos() async {
    try {
      final response = await client
          .from('investimentos')
          .select()
          .eq('user_id', currentUserId)
          .order('ticker', ascending: true);

      return response.map((json) => Investimento.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar investimentos: $e');
      return [];
    }
  }

  Future<void> addInvestimento(Investimento investimento) async {
    final json = investimento.toJson();
    json['user_id'] = currentUserId;
    await client.from('investimentos').insert(json);
  }

  Future<void> updateInvestimento(Investimento investimento) async {
    if (investimento.id == null) throw Exception('ID não pode ser nulo');
    final json = investimento.toJson();
    json.remove('id');
    await client.from('investimentos').update(json).eq('id', investimento.id!);
  }

  Future<void> deleteInvestimento(String id) async {
    await client.from('investimentos').delete().eq('id', id);
  }

  // ==================== METAS ====================

  Future<List<Meta>> getMetas() async {
    try {
      final response = await client
          .from('metas')
          .select()
          .eq('user_id', currentUserId)
          .order('data_fim', ascending: true);

      return response.map((json) => Meta.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar metas: $e');
      return [];
    }
  }

  Future<void> addMeta(Meta meta) async {
    final json = meta.toJson();
    json['user_id'] = currentUserId;
    await client.from('metas').insert(json);
  }

  Future<void> updateMeta(Meta meta) async {
    if (meta.id == null) throw Exception('ID não pode ser nulo');
    final json = meta.toJson();
    json.remove('id');
    await client.from('metas').update(json).eq('id', meta.id!);
  }

  Future<void> deleteMeta(String id) async {
    await client.from('metas').delete().eq('id', id);
  }

  Future<void> addDeposito(
      String metaId, double valor, String? observacao) async {
    await client.from('depositos_meta').insert({
      'meta_id': metaId,
      'valor': valor,
      'data_deposito': DateTime.now().toIso8601String(),
      'observacao': observacao,
      'user_id': currentUserId,
    });

    // Atualizar valor da meta
    final meta = await client.from('metas').select().eq('id', metaId).single();
    final valorAtual = (meta['valor_atual'] as num).toDouble();
    final novoValor = valorAtual + valor;
    final valorObjetivo = (meta['valor_objetivo'] as num).toDouble();

    await client.from('metas').update({
      'valor_atual': novoValor,
      'concluida': novoValor >= valorObjetivo,
    }).eq('id', metaId);
  }

  // 🔥 ADICIONADO: Buscar depósitos de uma meta
  Future<List<DepositoMeta>> getDepositos(String metaId) async {
    try {
      final response = await client
          .from('depositos_meta')
          .select()
          .eq('meta_id', metaId)
          .eq('user_id', currentUserId)
          .order('data_deposito', ascending: false);

      return response.map((json) => DepositoMeta.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar depósitos: $e');
      return [];
    }
  }

  // 🔥 ADICIONADO: Deletar depósito
  Future<void> deleteDeposito(String id) async {
    try {
      await client.from('depositos_meta').delete().eq('id', id);
    } catch (e) {
      debugPrint('Erro ao deletar depósito: $e');
      rethrow;
    }
  }

  // ==================== PROVENTOS ====================

  Future<List<Provento>> getProventos() async {
    try {
      final response = await client
          .from('proventos')
          .select()
          .eq('user_id', currentUserId)
          .order('data_pagamento', ascending: false);

      return response.map((json) => Provento.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar proventos: $e');
      return [];
    }
  }

  Future<void> addProvento(Provento provento) async {
    final json = provento.toJson();
    json['user_id'] = currentUserId;
    await client.from('proventos').insert(json);
  }

  Future<void> deleteProvento(String id) async {
    await client.from('proventos').delete().eq('id', id);
  }

  // ==================== RENDA FIXA ====================

  Future<List<RendaFixaModel>> getRendaFixa() async {
    try {
      final response = await client
          .from('renda_fixa')
          .select()
          .eq('user_id', currentUserId)
          .order('data_aplicacao', ascending: false);

      return response.map((json) => RendaFixaModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar renda fixa: $e');
      return [];
    }
  }

  Future<void> addRendaFixa(RendaFixaModel investimento) async {
    final json = investimento.toJson();
    json['user_id'] = currentUserId;
    await client.from('renda_fixa').insert(json);
  }

  Future<void> updateRendaFixa(RendaFixaModel investimento) async {
    if (investimento.id == null) throw Exception('ID não pode ser nulo');
    final json = investimento.toJson();
    json.remove('id');
    await client.from('renda_fixa').update(json).eq('id', investimento.id!);
  }

  Future<void> deleteRendaFixa(String id) async {
    await client.from('renda_fixa').delete().eq('id', id);
  }

  // ==================== TRANSAÇÕES ====================

  Future<List<Transacao>> getTransacoes({String? ticker}) async {
    try {
      var query =
          client.from('transacoes').select().eq('user_id', currentUserId);

      if (ticker != null && ticker.trim().isNotEmpty) {
        query = query.eq('ticker', ticker.trim().toUpperCase());
      }

      final response = await query.order('data', ascending: false);
      return (response as List)
          .map((json) => Transacao.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar transações no Supabase: $e');
      return [];
    }
  }

  Future<void> addTransacao(Transacao transacao) async {
    final json = transacao.toJson();
    json['user_id'] = currentUserId;
    await client.from('transacoes').insert(json);
  }

  Future<void> deleteTransacao(String id) async {
    await client.from('transacoes').delete().eq('id', id);
  }

  // ==================== CONTAS DO MÊS ====================

  Future<List<Conta>> getContas() async {
    try {
      final response = await client
          .from('contas')
          .select()
          .eq('user_id', currentUserId)
          .eq('ativa', true)
          .order('nome', ascending: true);

      return response.map((json) => Conta.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar contas: $e');
      return [];
    }
  }

  Future<void> addConta(Conta conta) async {
    final json = conta.toJson();
    json['user_id'] = currentUserId;
    await client.from('contas').insert(json);
  }

  Future<void> updateConta(Conta conta) async {
    if (conta.id == null) throw Exception('ID não pode ser nulo');
    final json = conta.toJson();
    json.remove('id');
    await client.from('contas').update(json).eq('id', conta.id!);
  }

  Future<void> deleteConta(String id) async {
    await client.from('contas').delete().eq('id', id);
  }

  // ==================== DASHBOARD (VIEWS) ====================

  Future<Map<String, dynamic>> getResumoPatrimonio() async {
    try {
      final response = await client
          .from('view_resumo_patrimonio')
          .select()
          .eq('user_id', currentUserId)
          .maybeSingle();

      return response ??
          {
            'total_investido': 0,
            'valor_atual': 0,
            'ganho_perda': 0,
            'total_ativos': 0,
          };
    } catch (e) {
      debugPrint('Erro ao buscar resumo patrimônio: $e');
      return {
        'total_investido': 0,
        'valor_atual': 0,
        'ganho_perda': 0,
        'total_ativos': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getResumoMes(DateTime data) async {
    try {
      final List<dynamic> response = await client.rpc(
        'get_resumo_mes',
        params: {
          'p_user_id': currentUserId,
          'p_data': data.toIso8601String().split('T')[0],
        },
      );

      return response.isNotEmpty
          ? response.first
          : {
              'receitas': 0,
              'despesas': 0,
              'saldo': 0,
              'total_lancamentos': 0,
            };
    } catch (e) {
      debugPrint('Erro ao buscar resumo do mês: $e');
      return {
        'receitas': 0,
        'despesas': 0,
        'saldo': 0,
        'total_lancamentos': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> getUltimasTransacoes(
      {int limit = 5}) async {
    try {
      return await client
          .from('transacoes')
          .select()
          .eq('user_id', currentUserId)
          .order('data', ascending: false)
          .limit(limit);
    } catch (e) {
      debugPrint('Erro ao buscar últimas transações: $e');
      return [];
    }
  }
}
