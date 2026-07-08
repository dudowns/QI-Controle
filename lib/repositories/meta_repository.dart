// lib/repositories/meta_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import '../services/sync_service.dart';
import '../models/result_model.dart';
import '../services/logger_service.dart';

class MetaRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  static const String tabelaMetas = DBHelper.tabelaMetas;
  static const String tabelaDepositosMeta = DBHelper.tabelaDepositosMeta;

  // ========== INSERIR META (CORRIGIDO) ==========
  Future<int> insertMeta(Map<String, dynamic> meta) async {
    final user = _supabase.auth.currentUser;

    String? remoteId;
    if (user != null) {
      try {
        final dadosSupabase = {
          'user_id': user.id,
          'titulo': meta['titulo'],
          'descricao': meta['descricao'] ?? '',
          'valor_objetivo': meta['valor_objetivo'],
          'valor_atual': meta['valor_atual'] ?? 0,
          'data_inicio':
              meta['data_inicio'] ?? DateTime.now().toIso8601String(),
          'data_fim': meta['data_fim'],
          'cor': meta['cor'] ?? 'geral',
          'concluida': meta['concluida'] ?? 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('metas')
            .insert(dadosSupabase)
            .select('id')
            .single();

        remoteId = response['id']?.toString();
        LoggerService.success('✅ Meta salva no Supabase: $remoteId');
      } catch (e) {
        LoggerService.error('❌ Erro ao salvar meta no Supabase: $e');
      }
    }

    meta['remote_id'] = remoteId;
    meta['sync_status'] = remoteId != null ? 'synced' : 'pending';
    meta['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertMeta(meta);
    _syncService.syncNow();
    return id;
  }

  // ========== ATUALIZAR META (CORRIGIDO) ==========
  Future<int> updateMeta(Map<String, dynamic> meta) async {
    final user = _supabase.auth.currentUser;
    final remoteId = meta['remote_id']?.toString();

    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('metas')
            .update({
              'titulo': meta['titulo'],
              'descricao': meta['descricao'] ?? '',
              'valor_objetivo': meta['valor_objetivo'],
              'valor_atual': meta['valor_atual'] ?? 0,
              'data_fim': meta['data_fim'],
              'cor': meta['cor'] ?? 'geral',
              'concluida': meta['concluida'] ?? 0,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Meta atualizada no Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao atualizar meta no Supabase: $e');
      }
    }

    meta['sync_status'] = 'pending';
    meta['updated_at'] = DateTime.now().toIso8601String();
    final result = await _dbHelper.updateMeta(meta);
    _syncService.syncNow();
    return result;
  }

  // ========== DELETAR META (CORRIGIDO) ==========
  Future<int> deleteMeta(int id) async {
    final meta = await getMetaById(id);
    final remoteId = meta?['remote_id'] as String?;
    final user = _supabase.auth.currentUser;

    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('metas')
            .delete()
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Meta deletada do Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao deletar meta do Supabase: $e');
      }
    }

    final result = await _dbHelper.deleteMeta(id);
    _syncService.syncNow();
    return result;
  }

  // ========== BUSCAR ==========
  Future<List<Map<String, dynamic>>> getAllMetas() async {
    return await _dbHelper.getAllMetas();
  }

  Future<Map<String, dynamic>?> getMetaById(int id) async {
    return await _dbHelper.getMetaById(id);
  }

  Future<Map<String, dynamic>> getResumoMetas() async {
    final metas = await getAllMetas();
    int total = metas.length;
    int concluidas = metas.where((m) => (m['concluida'] as int?) == 1).length;
    int emAndamento = total - concluidas;
    double progressoGeral = total > 0
        ? metas.fold<double>(0, (sum, m) {
              final obj = (m['valor_objetivo'] as num?)?.toDouble() ?? 0;
              final atual = (m['valor_atual'] as num?)?.toDouble() ?? 0;
              return sum + (obj > 0 ? (atual / obj) * 100 : 0);
            }) /
            total
        : 0;

    return {
      'total': total,
      'concluidas': concluidas,
      'emAndamento': emAndamento,
      'progressoGeral': progressoGeral,
    };
  }

  Future<int> atualizarProgressoMeta(int id, double valorAtual) async {
    return await _dbHelper.atualizarProgressoMeta(id, valorAtual);
  }

  Future<int> concluirMeta(int id) async {
    return await _dbHelper.concluirMeta(id);
  }

  Future<List<Map<String, dynamic>>> getDepositosByMetaId(int metaId) async {
    return await _dbHelper.getDepositosByMetaId(metaId);
  }

  // ========== RESULT METHODS ==========
  Future<Result<List<Map<String, dynamic>>>> getAllMetasResult() async {
    try {
      return Result.success(await getAllMetas());
    } catch (e) {
      return Result.failure('Erro ao carregar metas: $e');
    }
  }

  Future<Result<int>> insertMetaResult(Map<String, dynamic> meta) async {
    try {
      final id = await insertMeta(meta);
      return Result.success(id);
    } catch (e) {
      return Result.failure('Erro ao adicionar meta: $e');
    }
  }

  Future<Result<int>> updateMetaResult(Map<String, dynamic> meta) async {
    try {
      final result = await updateMeta(meta);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao atualizar meta: $e');
    }
  }

  Future<Result<int>> deleteMetaResult(int id) async {
    try {
      final result = await deleteMeta(id);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao excluir meta: $e');
    }
  }
}
