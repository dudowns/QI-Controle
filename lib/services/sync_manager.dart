// lib/services/sync_manager.dart - BLINDADO, OTIMIZADO E CORRIGIDO
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import '../database/db_helper.dart';
import '../services/logger_service.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final supabase = Supabase.instance.client;
  final DBHelper dbHelper = DBHelper();

  bool _isSyncing = false;

  Future<void> syncAll() async {
    if (_isSyncing) {
      LoggerService.info('Sincronização já em andamento');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      LoggerService.info('Usuário não logado, ignorando sincronização');
      return;
    }

    _isSyncing = true;
    LoggerService.info('🔄 Iniciando sincronização UNIFICADA e BLINDADA...');

    try {
      final db = await dbHelper.database;

      // PASSO 1: Sincronizar dados do servidor para o local
      await _fetchAllRemoteData(db, user.id);

      // PASSO 2: Enviar dados locais pendentes para o servidor
      await _syncAllPendingData(db, user.id);

      LoggerService.info('✅ Sincronização completa (sem duplicatas)!');
    } catch (e) {
      LoggerService.error('❌ Erro na sincronização: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ========== BUSCAR DADOS DO SERVIDOR ==========
  Future<void> _fetchAllRemoteData(Database db, String userId) async {
    LoggerService.info('☁️ Buscando TODOS os dados do servidor...');

    final remoteLancamentos =
        await supabase.from('lancamentos').select().eq('user_id', userId);
    final remoteMetas =
        await supabase.from('metas').select().eq('user_id', userId);
    final remoteProventos =
        await supabase.from('proventos').select().eq('user_id', userId);
    final remoteRendaFixa =
        await supabase.from('renda_fixa').select().eq('user_id', userId);
    final remoteContas =
        await supabase.from('contas').select().eq('user_id', userId);
    final remotePagamentos = await supabase
        .from('pagamentos_mensais')
        .select()
        .eq('user_id', userId);

    Future<void> upsertLocal(
        String table, List<dynamic> remoteList, String remoteIdKey) async {
      for (var remote in remoteList) {
        final remoteId = remote['id'].toString();
        final existing = await db.query(
          table,
          where: 'remote_id = ?',
          whereArgs: [remoteId],
        );

        if (existing.isNotEmpty) {
          final Map<String, dynamic> updateData = {...remote};
          updateData.remove('id');
          updateData['remote_id'] = remoteId;
          updateData['sync_status'] = 'synced';
          // ✅ Remove campos que não existem no SQLite
          updateData.remove('created_at');
          updateData.remove('updated_at');
          updateData.remove('criado_em');
          updateData.remove('atualizado_em');

          await db.update(
            table,
            updateData,
            where: 'remote_id = ?',
            whereArgs: [remoteId],
          );
        } else {
          final Map<String, dynamic> insertData = {...remote};
          insertData.remove('id');
          insertData['remote_id'] = remoteId;
          insertData['user_id'] = userId;
          insertData['sync_status'] = 'synced';
          // ✅ Remove campos que não existem no SQLite
          insertData.remove('created_at');
          insertData.remove('updated_at');
          insertData.remove('criado_em');
          insertData.remove('atualizado_em');

          await db.insert(table, insertData);
        }
      }
    }

    await upsertLocal(DBHelper.tabelaLancamentos, remoteLancamentos, 'id');
    await upsertLocal(DBHelper.tabelaMetas, remoteMetas, 'id');
    await upsertLocal(DBHelper.tabelaProventos, remoteProventos, 'id');
    await upsertLocal(DBHelper.tabelaRendaFixa, remoteRendaFixa, 'id');
    await upsertLocal(DBHelper.tabelaContas, remoteContas, 'id');
    await upsertLocal(DBHelper.tabelaPagamentos, remotePagamentos, 'id');

    LoggerService.info('✅ Dados remotos sincronizados localmente.');
  }

  // ========== ENVIAR DADOS PENDENTES PARA O SERVIDOR ==========
  Future<void> _syncAllPendingData(Database db, String userId) async {
    LoggerService.info('📤 Enviando dados locais pendentes para o servidor...');

    Future<void> syncPendingTable(
        String table, String supabaseTable, String remoteIdKey) async {
      final pending = await db.query(
        table,
        where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
        whereArgs: ['pending', 'deleted', userId],
      );

      if (pending.isEmpty) return;

      final remoteDataList =
          await supabase.from(supabaseTable).select().eq('user_id', userId);

      for (var localData in pending) {
        final syncStatus = localData['sync_status'] as String? ?? 'pending';
        final localId = localData['id'];
        final remoteId = localData['remote_id']?.toString();

        try {
          if (syncStatus == 'deleted') {
            if (remoteId != null && remoteId.isNotEmpty) {
              await supabase.from(supabaseTable).delete().eq('id', remoteId);
              LoggerService.info(
                  '🗑️ Deletado do servidor: $supabaseTable/$remoteId');
            }
            await db.delete(table, where: 'id = ?', whereArgs: [localId]);
            continue;
          }

          final Map<String, dynamic> remoteData = {...localData};
          remoteData.remove('id');
          remoteData.remove('sync_status');
          remoteData.remove('remote_id');
          remoteData.remove('local_id');
          remoteData['user_id'] = userId;

          // ✅ CORRIGIDO: Remove TODOS os campos que NÃO existem no Supabase
          remoteData.remove('created_at');
          remoteData.remove('updated_at');
          remoteData.remove('criado_em');
          remoteData.remove('atualizado_em');
          remoteData.remove('deleted_at');

          if (remoteId != null && remoteId.isNotEmpty) {
            // Atualiza no servidor
            await supabase
                .from(supabaseTable)
                .update(remoteData)
                .eq('id', remoteId);
            await db.update(table, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localId]);
          } else {
            // Verifica duplicata
            final potentialMatch = remoteDataList.firstWhereOrNull((item) {
              if (remoteData['nome'] != null &&
                  item['nome'] == remoteData['nome']) return true;
              if (remoteData['descricao'] != null &&
                  item['descricao'] == remoteData['descricao']) return true;
              if (remoteData['ticker'] != null &&
                  item['ticker'] == remoteData['ticker']) return true;
              return false;
            });

            if (potentialMatch != null) {
              // Já existe -> Atualiza
              await supabase
                  .from(supabaseTable)
                  .update(remoteData)
                  .eq('id', potentialMatch['id']);
              await db.update(table,
                  {'remote_id': potentialMatch['id'], 'sync_status': 'synced'},
                  where: 'id = ?', whereArgs: [localId]);
              LoggerService.info(
                  '🔄 Duplicata evitada! Atualizado registro existente.');
            } else {
              // Não existe -> Insere
              final response = await supabase
                  .from(supabaseTable)
                  .insert(remoteData)
                  .select()
                  .single();
              await db.update(
                  table, {'remote_id': response['id'], 'sync_status': 'synced'},
                  where: 'id = ?', whereArgs: [localId]);
            }
          }
        } catch (e) {
          LoggerService.error('❌ Erro ao sincronizar $supabaseTable: $e');
          await db.update(table, {'sync_status': 'failed'},
              where: 'id = ?', whereArgs: [localId]);
        }
      }
    }

    await syncPendingTable(DBHelper.tabelaLancamentos, 'lancamentos', 'id');
    await syncPendingTable(DBHelper.tabelaMetas, 'metas', 'id');
    await syncPendingTable(DBHelper.tabelaProventos, 'proventos', 'id');
    await syncPendingTable(DBHelper.tabelaRendaFixa, 'renda_fixa', 'id');
    await syncPendingTable(DBHelper.tabelaContas, 'contas', 'id');
    await syncPendingTable(
        DBHelper.tabelaPagamentos, 'pagamentos_mensais', 'id');

    LoggerService.info('✅ Todos os dados pendentes foram sincronizados.');
  }

  // ========== MÉTODOS AUXILIARES ==========
  Future<void> markAsPending(String table, dynamic localId) async {
    final db = await dbHelper.database;
    await db.update(
      table,
      {
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteAndSync(
      String table, dynamic localId, String remoteId) async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) {
      await db.delete(table, where: 'id = ?', whereArgs: [localId]);
      return;
    }
    await db.update(
      table,
      {
        'sync_status': 'deleted',
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
    LoggerService.info('📝 Registro marcado para deleção: $table/$localId');
  }

  Future<void> forcarEnvioTodosDados() async {
    await syncAll();
  }
}
