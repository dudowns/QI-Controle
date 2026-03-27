// lib/repositories/meta_repository.dart

import 'package:flutter/foundation.dart'; // 🔥 IMPORT PARA debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import '../services/sync_service.dart';

class MetaRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();
  final supabase = Supabase.instance.client;

  // ========== CONSTANTES ==========
  static const String tabelaMetas = DBHelper.tabelaMetas;
  static const String tabelaDepositosMeta = DBHelper.tabelaDepositosMeta;

  // ========== 🔥 NOVOS MÉTODOS COM VIEWS ==========

  /// Buscar progresso das metas usando a VIEW do Supabase
  Future<List<Map<String, dynamic>>> getProgressoMetas() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('view_progresso_metas')
          .select()
          .eq('user_id', userId);

      return response;
    } catch (e) {
      debugPrint('❌ Erro ao buscar progresso metas: $e');
      return _getProgressoMetasLocal();
    }
  }

  /// Fallback local para progresso das metas
  Future<List<Map<String, dynamic>>> _getProgressoMetasLocal() async {
    final metas = await getAllMetas();
    final agora = DateTime.now();

    return metas.map((meta) {
      final valorObjetivo = (meta['valor_objetivo'] as num).toDouble();
      final valorAtual = (meta['valor_atual'] as num).toDouble();
      final concluida = (meta['concluida'] as int) == 1;
      final dataFim = DateTime.parse(meta['data_fim']);

      return {
        'meta_id': meta['id'],
        'titulo': meta['titulo'],
        'valor_objetivo': valorObjetivo,
        'valor_atual': valorAtual,
        'percentual':
            valorObjetivo > 0 ? (valorAtual / valorObjetivo) * 100 : 0,
        'status': concluida
            ? 'concluida'
            : (dataFim.isBefore(agora) ? 'atrasada' : 'em_andamento'),
      };
    }).toList();
  }

  /// Buscar metas por status (usando VIEW)
  Future<List<Map<String, dynamic>>> getMetasPorStatus(String status) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('view_progresso_metas')
          .select()
          .eq('user_id', userId)
          .eq('status', status);

      return response;
    } catch (e) {
      debugPrint('❌ Erro ao buscar metas por status: $e');
      final todas = await _getProgressoMetasLocal();
      return todas.where((meta) => meta['status'] == status).toList();
    }
  }

  /// Buscar resumo das metas (estatísticas)
  Future<Map<String, dynamic>> getResumoMetas() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final metas = await getProgressoMetas();

      int total = metas.length;
      int concluidas = metas.where((m) => m['status'] == 'concluida').length;
      int emAndamento =
          metas.where((m) => m['status'] == 'em_andamento').length;
      int atrasadas = metas.where((m) => m['status'] == 'atrasada').length;

      double progressoGeral = 0;
      if (total > 0) {
        progressoGeral = metas.fold<double>(
                0, (sum, m) => sum + (m['percentual'] as double)) /
            total;
      }

      return {
        'total': total,
        'concluidas': concluidas,
        'emAndamento': emAndamento,
        'atrasadas': atrasadas,
        'progressoGeral': progressoGeral,
      };
    } catch (e) {
      debugPrint('❌ Erro ao buscar resumo metas: $e');
      return await getEstatisticasMetas();
    }
  }

  // ========== MÉTODOS DE METAS COM SINCRONIZAÇÃO ==========

  /// Insere uma nova meta
  Future<int> insertMeta(Map<String, dynamic> meta) async {
    meta['sync_status'] = 'pending';
    meta['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertMeta(meta);
    _syncService.syncNow();
    return id;
  }

  /// Atualiza uma meta existente
  Future<int> updateMeta(Map<String, dynamic> meta) async {
    meta['sync_status'] = 'pending';
    meta['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.updateMeta(meta);
    _syncService.syncNow();
    return result;
  }

  /// Deleta uma meta
  Future<int> deleteMeta(int id) async {
    final meta = await getMetaById(id);
    final remoteId = meta?['remote_id'] as String?;

    final result = await _dbHelper.deleteMeta(id);

    if (remoteId != null && remoteId.isNotEmpty) {
      await _syncService.deleteAndSync('metas', id, remoteId);
    }

    return result;
  }

  /// Atualiza o progresso de uma meta
  Future<int> atualizarProgressoMeta(int id, double valorAtual) async {
    final result = await _dbHelper.atualizarProgressoMeta(id, valorAtual);
    await _syncService.markAsPending('metas', id);
    return result;
  }

  /// Conclui uma meta
  Future<int> concluirMeta(int id) async {
    final result = await _dbHelper.concluirMeta(id);
    await _syncService.markAsPending('metas', id);
    return result;
  }

  // ========== MÉTODOS DE DEPÓSITOS COM SINCRONIZAÇÃO ==========

  /// Insere um novo depósito
  Future<int> insertDepositoMeta(Map<String, dynamic> deposito) async {
    deposito['sync_status'] = 'pending';
    deposito['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertDepositoMeta(deposito);
    _syncService.syncNow();
    return id;
  }

  /// Deleta um depósito
  Future<int> deleteDeposito(int id) async {
    final result = await _dbHelper.deleteDeposito(id);
    _syncService.syncNow();
    return result;
  }

  // ========== MÉTODOS DE BUSCA (SQLite) ==========

  /// Busca todas as metas
  Future<List<Map<String, dynamic>>> getAllMetas() async {
    return await _dbHelper.getAllMetas();
  }

  /// Busca uma meta pelo ID
  Future<Map<String, dynamic>?> getMetaById(int id) async {
    return await _dbHelper.getMetaById(id);
  }

  /// Busca todos os depósitos de uma meta
  Future<List<Map<String, dynamic>>> getDepositosByMetaId(int metaId) async {
    return await _dbHelper.getDepositosByMetaId(metaId);
  }

  /// Calcula o total de depósitos de uma meta
  Future<double> getTotalDepositosByMetaId(int metaId) async {
    return await _dbHelper.getTotalDepositosByMetaId(metaId);
  }

  // ========== MÉTODOS COMBINADOS ==========

  /// Busca uma meta completa com seus depósitos
  Future<Map<String, dynamic>?> getMetaComDepositos(int id) async {
    final meta = await _dbHelper.getMetaById(id);
    if (meta == null) return null;

    final depositos = await _dbHelper.getDepositosByMetaId(id);
    meta['depositos'] = depositos;

    return meta;
  }

  /// Busca todas as metas completas com seus depósitos
  Future<List<Map<String, dynamic>>> getAllMetasComDepositos() async {
    final metas = await _dbHelper.getAllMetas();

    for (var meta in metas) {
      final depositos = await _dbHelper.getDepositosByMetaId(meta['id']);
      meta['depositos'] = depositos;
    }

    return metas;
  }

  /// Adiciona um depósito e atualiza o progresso da meta
  Future<bool> adicionarDepositoEAtualizarMeta({
    required int metaId,
    required double valor,
    required DateTime dataDeposito,
    String? observacao,
  }) async {
    try {
      await insertDepositoMeta({
        'meta_id': metaId,
        'valor': valor,
        'data_deposito': dataDeposito.toIso8601String(),
        'observacao': observacao,
      });

      final meta = await _dbHelper.getMetaById(metaId);
      if (meta == null) return false;

      final valorAtual = (meta['valor_atual'] as num).toDouble();
      final novoValor = valorAtual + valor;

      await atualizarProgressoMeta(metaId, novoValor);

      final valorObjetivo = (meta['valor_objetivo'] as num).toDouble();
      if (novoValor >= valorObjetivo) {
        await concluirMeta(metaId);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Erro ao adicionar depósito: $e');
      return false;
    }
  }

  /// Remove um depósito e atualiza o progresso da meta
  Future<bool> removerDepositoEAtualizarMeta(int depositoId) async {
    try {
      await deleteDeposito(depositoId);
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao remover depósito: $e');
      return false;
    }
  }

  // ========== MÉTODOS DE ESTATÍSTICAS ==========

  /// Retorna estatísticas das metas (local)
  Future<Map<String, dynamic>> getEstatisticasMetas() async {
    final metas = await _dbHelper.getAllMetas();

    int totalMetas = metas.length;
    int concluidas = 0;
    int emAndamento = 0;
    int atrasadas = 0;
    double valorTotalObjetivo = 0;
    double valorTotalAcumulado = 0;

    final agora = DateTime.now();

    for (var meta in metas) {
      final objetivo = (meta['valor_objetivo'] as num).toDouble();
      final atual = (meta['valor_atual'] as num).toDouble();
      final concluida = (meta['concluida'] as int) == 1;
      final dataFim = DateTime.parse(meta['data_fim']);

      valorTotalObjetivo += objetivo;
      valorTotalAcumulado += atual;

      if (concluida) {
        concluidas++;
      } else {
        emAndamento++;
        if (dataFim.isBefore(agora)) {
          atrasadas++;
        }
      }
    }

    return {
      'totalMetas': totalMetas,
      'concluidas': concluidas,
      'emAndamento': emAndamento,
      'atrasadas': atrasadas,
      'valorTotalObjetivo': valorTotalObjetivo,
      'valorTotalAcumulado': valorTotalAcumulado,
      'progressoGeral': valorTotalObjetivo > 0
          ? (valorTotalAcumulado / valorTotalObjetivo) * 100
          : 0,
    };
  }

  /// Retorna metas em andamento
  Future<List<Map<String, dynamic>>> getMetasEmAndamento() async {
    final metas = await _dbHelper.getAllMetas();
    return metas.where((meta) => (meta['concluida'] as int) == 0).toList();
  }

  /// Retorna metas concluídas
  Future<List<Map<String, dynamic>>> getMetasConcluidas() async {
    final metas = await _dbHelper.getAllMetas();
    return metas.where((meta) => (meta['concluida'] as int) == 1).toList();
  }

  /// Retorna metas atrasadas
  Future<List<Map<String, dynamic>>> getMetasAtrasadas() async {
    final metas = await _dbHelper.getAllMetas();
    final agora = DateTime.now();

    return metas.where((meta) {
      final concluida = (meta['concluida'] as int) == 1;
      if (concluida) return false;

      final dataFim = DateTime.parse(meta['data_fim']);
      return dataFim.isBefore(agora);
    }).toList();
  }
}
