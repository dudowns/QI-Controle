// lib/repositories/provento_repository.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import '../models/provento_model.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../models/result_model.dart';
import '../services/logger_service.dart';

class ProventoRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  static const String tabelaProventos = DBHelper.tabelaProventos;

  // ========== INSERIR (CORRIGIDO) ==========
  Future<int> insertProvento(Map<String, dynamic> provento) async {
    final user = _supabase.auth.currentUser;

    String? remoteId;
    if (user != null) {
      try {
        final dadosSupabase = {
          'user_id': user.id,
          'ticker': provento['ticker'],
          'tipo_provento': provento['tipo_provento'],
          'valor_por_cota': provento['valor_por_cota'],
          'quantidade': provento['quantidade'] ?? 1,
          'data_pagamento': provento['data_pagamento'],
          'data_com': provento['data_com'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('proventos')
            .insert(dadosSupabase)
            .select('id')
            .single();

        remoteId = response['id']?.toString();
        LoggerService.success('✅ Provento salvo no Supabase: $remoteId');
      } catch (e) {
        LoggerService.error('❌ Erro ao salvar provento no Supabase: $e');
      }
    }

    provento['remote_id'] = remoteId;
    provento['sync_status'] = remoteId != null ? 'synced' : 'pending';
    provento['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertProvento(provento);
    _syncService.syncNow();
    return id;
  }

  Future<int> insert(Provento provento) async {
    return await insertProvento(provento.toJson());
  }

  // ========== ATUALIZAR (CORRIGIDO) ==========
  Future<int> updateProvento(Map<String, dynamic> provento) async {
    final user = _supabase.auth.currentUser;
    final remoteId = provento['remote_id']?.toString();

    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('proventos')
            .update({
              'ticker': provento['ticker'],
              'tipo_provento': provento['tipo_provento'],
              'valor_por_cota': provento['valor_por_cota'],
              'quantidade': provento['quantidade'] ?? 1,
              'data_pagamento': provento['data_pagamento'],
              'data_com': provento['data_com'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Provento atualizado no Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao atualizar provento no Supabase: $e');
      }
    }

    provento['sync_status'] = 'pending';
    provento['updated_at'] = DateTime.now().toIso8601String();
    final result = await _dbHelper.updateProvento(provento);
    _syncService.syncNow();
    return result;
  }

  Future<int> update(Provento provento) async {
    if (provento.id == null) throw Exception('ID não pode ser nulo');
    return await updateProvento(provento.toJson());
  }

  // ========== DELETAR (CORRIGIDO) ==========
  Future<int> delete(int id) async {
    final provento = await getProventoById(id);
    final remoteId = provento?['remote_id'] as String?;
    final user = _supabase.auth.currentUser;

    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('proventos')
            .delete()
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Provento deletado do Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao deletar provento do Supabase: $e');
      }
    }

    final result = await _dbHelper.deleteProvento(id);
    _syncService.syncNow();
    return result;
  }

  // ========== BUSCAR ==========
  Future<List<Map<String, dynamic>>> getAllProventos() async {
    return await _dbHelper.getAllProventos();
  }

  Future<List<Provento>> getAll() async {
    final dados = await _dbHelper.getAllProventos();
    return dados.map((json) => Provento.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>?> getProventoById(int id) async {
    final db = await _dbHelper.database;
    final results =
        await db.query(tabelaProventos, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Provento?> getById(int id) async {
    final dados = await getProventoById(id);
    if (dados == null) return null;
    return Provento.fromJson(dados);
  }

  // ========== RESULT METHODS ==========
  Future<Result<List<Provento>>> getAllProventosResult() async {
    try {
      return Result.success(await getAll());
    } catch (e) {
      return Result.failure('Erro ao carregar proventos: $e');
    }
  }

  Future<Result<int>> insertProventoResult(Provento provento) async {
    try {
      final id = await insert(provento);
      return Result.success(id);
    } catch (e) {
      return Result.failure('Erro ao adicionar provento: $e');
    }
  }

  Future<Result<int>> updateProventoResult(Provento provento) async {
    try {
      final result = await update(provento);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao atualizar provento: $e');
    }
  }

  Future<Result<int>> deleteProventoResult(int id) async {
    try {
      final result = await delete(id);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao excluir provento: $e');
    }
  }
}
