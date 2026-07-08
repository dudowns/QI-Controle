// lib/repositories/renda_fixa_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import '../models/renda_fixa_model.dart';
import '../services/sync_service.dart';
import '../models/result_model.dart';
import '../services/logger_service.dart';

class RendaFixaRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  static const String tabelaRendaFixa = DBHelper.tabelaRendaFixa;

  Future<Database> getDatabase() async => await _dbHelper.database;

  // ========== INSERIR (CORRIGIDO) ==========
  Future<int> insert(RendaFixaModel investimento) async {
    final user = _supabase.auth.currentUser;
    final json = investimento.toJson();

    String? remoteId;
    if (user != null) {
      try {
        final dadosSupabase = {
          'user_id': user.id,
          'nome': investimento.nome,
          'tipo_renda': investimento.tipoRenda,
          'indexador': investimento.indexador.name,
          'taxa': investimento.taxa,
          'valor_aplicado': investimento.valorAplicado,
          'data_vencimento': investimento.dataVencimento.toIso8601String(),
          'liquidez_diaria': investimento.liquidezDiaria,
          'observacao': investimento.observacao ?? '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('renda_fixa')
            .insert(dadosSupabase)
            .select('id')
            .single();

        remoteId = response['id']?.toString();
        LoggerService.success('✅ Renda Fixa salva no Supabase: $remoteId');
      } catch (e) {
        LoggerService.error('❌ Erro ao salvar no Supabase: $e');
      }
    }

    json['remote_id'] = remoteId;
    json['sync_status'] = remoteId != null ? 'synced' : 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertRendaFixa(json);
    _syncService.syncNow();
    return id;
  }

  // ========== ATUALIZAR (CORRIGIDO) ==========
  Future<int> update(RendaFixaModel investimento) async {
    if (investimento.id == null) throw Exception('ID não pode ser nulo');

    final user = _supabase.auth.currentUser;
    final remoteId = investimento.id?.toString();

    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('renda_fixa')
            .update({
              'nome': investimento.nome,
              'tipo_renda': investimento.tipoRenda,
              'indexador': investimento.indexador.name,
              'taxa': investimento.taxa,
              'valor_aplicado': investimento.valorAplicado,
              'data_vencimento': investimento.dataVencimento.toIso8601String(),
              'liquidez_diaria': investimento.liquidezDiaria,
              'observacao': investimento.observacao ?? '',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Renda Fixa atualizada no Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao atualizar no Supabase: $e');
      }
    }

    final json = investimento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();
    final result = await _dbHelper.updateRendaFixa(json);
    _syncService.syncNow();
    return result;
  }

  // ========== DELETAR (CORRIGIDO) ==========
  Future<int> delete(int id) async {
    final user = _supabase.auth.currentUser;
    final investimento = await getById(id);
    final remoteId = investimento?.id?.toString();

    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('renda_fixa')
            .delete()
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Renda Fixa deletada do Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao deletar do Supabase: $e');
      }
    }

    final result = await _dbHelper.deleteRendaFixa(id);
    _syncService.syncNow();
    return result;
  }

  // ========== BUSCAR ==========
  Future<List<RendaFixaModel>> getAll() async {
    final dados = await _dbHelper.getAllRendaFixa();
    return dados.map((json) => RendaFixaModel.fromJson(json)).toList();
  }

  Future<RendaFixaModel?> getById(int id) async {
    final dados = await _dbHelper.getRendaFixaById(id);
    if (dados == null) return null;
    return RendaFixaModel.fromJson(dados);
  }

  // ========== RESULT METHODS ==========
  Future<Result<List<RendaFixaModel>>> getAllRendaFixaResult() async {
    try {
      return Result.success(await getAll());
    } catch (e) {
      return Result.failure('Erro ao carregar: $e');
    }
  }

  Future<Result<int>> insertRendaFixaResult(RendaFixaModel investimento) async {
    try {
      final id = await insert(investimento);
      return Result.success(id);
    } catch (e) {
      return Result.failure('Erro ao adicionar: $e');
    }
  }

  Future<Result<int>> updateRendaFixaResult(RendaFixaModel investimento) async {
    try {
      final result = await update(investimento);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao atualizar: $e');
    }
  }

  Future<Result<int>> deleteRendaFixaResult(int id) async {
    try {
      final result = await delete(id);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao excluir: $e');
    }
  }
}
