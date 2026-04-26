// lib/services/sync_manager.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
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
      LoggerService.info('Sincronizacao ja em andamento');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      LoggerService.info('Usuario nao logado, ignorando sincronizacao');
      return;
    }

    _isSyncing = true;
    LoggerService.info('Iniciando sincronizacao...');

    try {
      await syncPendingLancamentos();
      await syncPendingInvestimentos();
      await syncPendingTransacoes();
      await syncPendingMetas();
      await syncPendingProventos();
      await syncPendingRendaFixa();
      await syncPendingContas();
      await syncPendingPagamentos();

      await fetchRemoteLancamentos();
      await fetchRemoteInvestimentos();
      await fetchRemoteTransacoes();
      await fetchRemoteMetas();
      await fetchRemoteProventos();
      await fetchRemoteRendaFixa();
      await fetchRemoteContas();

      LoggerService.info('Sincronizacao completa!');
    } catch (e) {
      LoggerService.error('Erro na sincronizacao: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ========== SINCRONIZACAO DE TRANSACOES ==========

  Future<void> syncPendingTransacoes() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      'transacoes',
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    LoggerService.info('Processando ${pending.length} transacoes pendentes...');

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('transacoes').delete().eq('id', remoteId);
          }
          await db.delete('transacoes',
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final quantidade =
              (localData['quantidade'] as num?)?.toDouble() ?? 0.0;
          final precoUnitario =
              (localData['preco_unitario'] as num?)?.toDouble() ?? 0.0;
          final taxa = (localData['taxa'] as num?)?.toDouble() ?? 0.0;
          final total = (quantidade * precoUnitario) + taxa;

          final remoteData = {
            'ticker': localData['ticker']?.toString().toUpperCase() ?? '',
            'tipo_investimento':
                localData['tipo_investimento']?.toString() ?? 'ACAO',
            'tipo_transacao':
                localData['tipo_transacao']?.toString() ?? 'COMPRA',
            'quantidade': quantidade,
            'preco_unitario': precoUnitario,
            'taxa': taxa,
            'total': total,
            'data': localData['data']?.toString() ??
                DateTime.now().toIso8601String(),
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('transacoes')
                .update(remoteData)
                .eq('id', remoteId);
            await db.update('transacoes', {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('transacoes')
                .insert(remoteData)
                .select()
                .single();
            await db.update('transacoes',
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar transacao: $e');
      }
    }
  }

  Future<void> fetchRemoteTransacoes() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info('Buscando transacoes do servidor...');

    try {
      final remoteTransacoes = await supabase
          .from('transacoes')
          .select()
          .eq('user_id', user.id)
          .order('data', ascending: false);

      for (var remote in remoteTransacoes) {
        final existing = await db.query('transacoes',
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert('transacoes', {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'ticker': remote['ticker'],
            'tipo_investimento': remote['tipo_investimento'],
            'tipo_transacao': remote['tipo_transacao'],
            'quantidade': remote['quantidade'],
            'preco_unitario': remote['preco_unitario'],
            'taxa': remote['taxa'],
            'total': remote['total'],
            'data': remote['data'],
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              'transacoes',
              {
                'ticker': remote['ticker'],
                'tipo_investimento': remote['tipo_investimento'],
                'tipo_transacao': remote['tipo_transacao'],
                'quantidade': remote['quantidade'],
                'preco_unitario': remote['preco_unitario'],
                'taxa': remote['taxa'],
                'total': remote['total'],
                'data': remote['data'],
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar transacoes: $e');
    }
  }

  // ========== SINCRONIZACAO DE INVESTIMENTOS ==========

  Future<void> syncPendingInvestimentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaInvestimentos,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    LoggerService.info(
        'Processando ${pending.length} investimentos pendentes...');

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('investimentos').delete().eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaInvestimentos,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final remoteData = {
            'ticker': localData['ticker']?.toString().toUpperCase() ?? '',
            'tipo': localData['tipo']?.toString() ?? 'ACAO',
            'quantidade': (localData['quantidade'] as num?)?.toDouble() ?? 0.0,
            'preco_medio':
                (localData['preco_medio'] as num?)?.toDouble() ?? 0.0,
            'preco_atual':
                (localData['preco_atual'] as num?)?.toDouble() ?? 0.0,
            'data_compra': localData['data_compra']?.toString(),
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('investimentos')
                .update(remoteData)
                .eq('id', remoteId);
            await db.update(
                DBHelper.tabelaInvestimentos, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('investimentos')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaInvestimentos,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar investimento: $e');
      }
    }
  }

  Future<void> fetchRemoteInvestimentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteInvestimentos =
          await supabase.from('investimentos').select().eq('user_id', user.id);

      for (var remote in remoteInvestimentos) {
        final existing = await db.query(DBHelper.tabelaInvestimentos,
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert(DBHelper.tabelaInvestimentos, {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'ticker': remote['ticker'],
            'tipo': remote['tipo'],
            'quantidade': remote['quantidade'],
            'preco_medio': remote['preco_medio'],
            'preco_atual': remote['preco_atual'],
            'data_compra': remote['data_compra'],
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              DBHelper.tabelaInvestimentos,
              {
                'ticker': remote['ticker'],
                'tipo': remote['tipo'],
                'quantidade': remote['quantidade'],
                'preco_medio': remote['preco_medio'],
                'preco_atual': remote['preco_atual'],
                'data_compra': remote['data_compra'],
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar investimentos: $e');
    }
  }

  // ========== SINCRONIZACAO DE LANCAMENTOS ==========

  Future<void> syncPendingLancamentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaLancamentos,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('lancamentos').delete().eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaLancamentos,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          String dataStr = localData['data'].toString();
          if (dataStr.contains('T')) dataStr = dataStr.split('T')[0];

          String tipoOriginal = localData['tipo'].toString();
          String tipoCorreto = tipoOriginal == 'gasto'
              ? 'despesa'
              : (tipoOriginal == 'receita' ? 'receita' : 'despesa');

          final remoteData = {
            'descricao': localData['descricao'],
            'valor': localData['valor'],
            'tipo': tipoCorreto,
            'categoria': localData['categoria'],
            'data': dataStr,
            'user_id': user.id,
            'observacao': localData['observacao'] ?? '',
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('lancamentos')
                .update(remoteData)
                .eq('id', remoteId);
            await db.update(
                DBHelper.tabelaLancamentos, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('lancamentos')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaLancamentos,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar lancamento: $e');
        await db.update(DBHelper.tabelaLancamentos, {'sync_status': 'failed'},
            where: 'id = ?', whereArgs: [localData['id']]);
      }
    }
  }

  Future<void> fetchRemoteLancamentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteLancamentos = await supabase
          .from('lancamentos')
          .select()
          .eq('user_id', user.id)
          .order('criado_em', ascending: false);

      for (var remote in remoteLancamentos) {
        final existing = await db.query(DBHelper.tabelaLancamentos,
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert(DBHelper.tabelaLancamentos, {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'descricao': remote['descricao'],
            'valor': remote['valor'],
            'tipo': remote['tipo'],
            'categoria': remote['categoria'],
            'data': remote['data'],
            'observacao': remote['observacao'],
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              DBHelper.tabelaLancamentos,
              {
                'descricao': remote['descricao'],
                'valor': remote['valor'],
                'tipo': remote['tipo'],
                'categoria': remote['categoria'],
                'data': remote['data'],
                'observacao': remote['observacao'],
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar lancamentos: $e');
    }
  }

  // ========== SINCRONIZACAO DE METAS ==========

  Future<void> syncPendingMetas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaMetas,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('metas').delete().eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaMetas,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final remoteData = {
            'titulo': localData['titulo'],
            'descricao': localData['descricao'],
            'valor_objetivo': localData['valor_objetivo'],
            'valor_atual': localData['valor_atual'],
            'data_inicio': localData['data_inicio']?.toString().split('T')[0],
            'data_fim': localData['data_fim']?.toString().split('T')[0],
            'concluida': localData['concluida'] == 1,
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('metas').update(remoteData).eq('id', remoteId);
            await db.update(DBHelper.tabelaMetas, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('metas')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaMetas,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar meta: $e');
      }
    }
  }

  Future<void> fetchRemoteMetas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteMetas =
          await supabase.from('metas').select().eq('user_id', user.id);

      for (var remote in remoteMetas) {
        final existing = await db.query(DBHelper.tabelaMetas,
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert(DBHelper.tabelaMetas, {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'titulo': remote['titulo'],
            'descricao': remote['descricao'],
            'valor_objetivo': remote['valor_objetivo'],
            'valor_atual': remote['valor_atual'],
            'data_inicio': remote['data_inicio'],
            'data_fim': remote['data_fim'],
            'concluida': remote['concluida'] ? 1 : 0,
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              DBHelper.tabelaMetas,
              {
                'titulo': remote['titulo'],
                'descricao': remote['descricao'],
                'valor_objetivo': remote['valor_objetivo'],
                'valor_atual': remote['valor_atual'],
                'data_inicio': remote['data_inicio'],
                'data_fim': remote['data_fim'],
                'concluida': remote['concluida'] ? 1 : 0,
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar metas: $e');
    }
  }

  // ========== SINCRONIZACAO DE PROVENTOS ==========

  Future<void> syncPendingProventos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaProventos,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('proventos').delete().eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaProventos,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final remoteData = {
            'ticker': localData['ticker'],
            'tipo_provento': localData['tipo_provento'],
            'valor_por_cota': localData['valor_por_cota'],
            'quantidade': localData['quantidade'],
            'data_pagamento':
                localData['data_pagamento']?.toString().split('T')[0],
            'data_com': localData['data_com']?.toString().split('T')[0],
            'total_recebido': localData['total_recebido'],
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('proventos')
                .update(remoteData)
                .eq('id', remoteId);
            await db.update(DBHelper.tabelaProventos, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('proventos')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaProventos,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar provento: $e');
      }
    }
  }

  Future<void> fetchRemoteProventos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteProventos =
          await supabase.from('proventos').select().eq('user_id', user.id);

      for (var remote in remoteProventos) {
        final existing = await db.query(DBHelper.tabelaProventos,
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert(DBHelper.tabelaProventos, {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'ticker': remote['ticker'],
            'tipo_provento': remote['tipo_provento'],
            'valor_por_cota': remote['valor_por_cota'],
            'quantidade': remote['quantidade'],
            'data_pagamento': remote['data_pagamento'],
            'data_com': remote['data_com'],
            'total_recebido': remote['total_recebido'],
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              DBHelper.tabelaProventos,
              {
                'ticker': remote['ticker'],
                'tipo_provento': remote['tipo_provento'],
                'valor_por_cota': remote['valor_por_cota'],
                'quantidade': remote['quantidade'],
                'data_pagamento': remote['data_pagamento'],
                'data_com': remote['data_com'],
                'total_recebido': remote['total_recebido'],
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar proventos: $e');
    }
  }

  // ========== SINCRONIZACAO DE RENDA FIXA ==========

  Future<void> syncPendingRendaFixa() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaRendaFixa,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('renda_fixa').delete().eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaRendaFixa,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final remoteData = {
            'nome': localData['nome'],
            'tipo_renda': localData['tipo_renda'],
            'valor': localData['valor'],
            'taxa': localData['taxa'],
            'data_aplicacao':
                localData['data_aplicacao']?.toString().split('T')[0],
            'data_vencimento':
                localData['data_vencimento']?.toString().split('T')[0],
            'status': localData['status'],
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('renda_fixa')
                .update(remoteData)
                .eq('id', remoteId);
            await db.update(DBHelper.tabelaRendaFixa, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('renda_fixa')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaRendaFixa,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar renda fixa: $e');
      }
    }
  }

  Future<void> fetchRemoteRendaFixa() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteRendaFixa =
          await supabase.from('renda_fixa').select().eq('user_id', user.id);

      for (var remote in remoteRendaFixa) {
        final existing = await db.query(DBHelper.tabelaRendaFixa,
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert(DBHelper.tabelaRendaFixa, {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'nome': remote['nome'],
            'tipo_renda': remote['tipo_renda'],
            'valor': remote['valor'],
            'taxa': remote['taxa'],
            'data_aplicacao': remote['data_aplicacao'],
            'data_vencimento': remote['data_vencimento'],
            'status': remote['status'],
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              DBHelper.tabelaRendaFixa,
              {
                'nome': remote['nome'],
                'tipo_renda': remote['tipo_renda'],
                'valor': remote['valor'],
                'taxa': remote['taxa'],
                'data_aplicacao': remote['data_aplicacao'],
                'data_vencimento': remote['data_vencimento'],
                'status': remote['status'],
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar renda fixa: $e');
    }
  }

  // ========== SINCRONIZACAO DE CONTAS ==========

  Future<void> syncPendingContas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaContas,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('contas').delete().eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaContas,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final remoteData = {
            'nome': localData['nome'],
            'valor': localData['valor'],
            'dia_vencimento': localData['dia_vencimento'],
            'tipo': localData['tipo'],
            'categoria': localData['categoria'],
            'ativa': localData['ativa'],
            'parcelas_total': localData['parcelas_total'],
            'parcelas_pagas': localData['parcelas_pagas'],
            'data_inicio': localData['data_inicio']?.toString().split('T')[0],
            'data_fim': localData['data_fim']?.toString().split('T')[0],
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase.from('contas').update(remoteData).eq('id', remoteId);
            await db.update(DBHelper.tabelaContas, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('contas')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaContas,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar conta: $e');
      }
    }
  }

  Future<void> fetchRemoteContas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final remoteContas =
          await supabase.from('contas').select().eq('user_id', user.id);

      for (var remote in remoteContas) {
        final existing = await db.query(DBHelper.tabelaContas,
            where: 'remote_id = ?', whereArgs: [remote['id']]);

        if (existing.isEmpty) {
          await db.insert(DBHelper.tabelaContas, {
            'remote_id': remote['id'],
            'user_id': remote['user_id'],
            'nome': remote['nome'],
            'valor': remote['valor'],
            'dia_vencimento': remote['dia_vencimento'],
            'tipo': remote['tipo'],
            'categoria': remote['categoria'],
            'ativa': remote['ativa'],
            'parcelas_total': remote['parcelas_total'],
            'parcelas_pagas': remote['parcelas_pagas'],
            'data_inicio': remote['data_inicio'],
            'data_fim': remote['data_fim'],
            'sync_status': 'synced',
          });
        } else {
          await db.update(
              DBHelper.tabelaContas,
              {
                'nome': remote['nome'],
                'valor': remote['valor'],
                'dia_vencimento': remote['dia_vencimento'],
                'tipo': remote['tipo'],
                'categoria': remote['categoria'],
                'ativa': remote['ativa'],
                'parcelas_total': remote['parcelas_total'],
                'parcelas_pagas': remote['parcelas_pagas'],
                'data_inicio': remote['data_inicio'],
                'data_fim': remote['data_fim'],
                'sync_status': 'synced',
              },
              where: 'remote_id = ?',
              whereArgs: [remote['id']]);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao buscar contas: $e');
    }
  }

  // ========== SINCRONIZACAO DE PAGAMENTOS (CORRIGIDO) ==========

  Future<void> syncPendingPagamentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaPagamentos,
      where: '(sync_status = ? OR sync_status = ?) AND user_id = ?',
      whereArgs: ['pending', 'deleted', user.id],
    );

    if (pending.isEmpty) return;

    for (var localData in pending) {
      final syncStatus = localData['sync_status'] as String? ?? 'pending';
      final remoteId = localData['remote_id']?.toString();

      // ✅ CORRIGIDO: Pular pagamentos com conta_id que nao e UUID valido
      final contaIdRaw = localData['conta_id']?.toString() ?? '';
      if (contaIdRaw.isNotEmpty &&
          contaIdRaw.length < 10 &&
          !contaIdRaw.contains('-')) {
        await db.update(
          DBHelper.tabelaPagamentos,
          {'sync_status': 'skipped'},
          where: 'id = ?',
          whereArgs: [localData['id']],
        );
        continue;
      }

      try {
        if (syncStatus == 'deleted') {
          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('pagamentos_mensais')
                .delete()
                .eq('id', remoteId);
          }
          await db.delete(DBHelper.tabelaPagamentos,
              where: 'id = ?', whereArgs: [localData['id']]);
        } else {
          final conta = await db.query(DBHelper.tabelaContas,
              where: 'id = ?', whereArgs: [localData['conta_id']]);
          final contaRemoteId =
              conta.isNotEmpty ? conta.first['remote_id'] as String? : null;

          final remoteData = {
            'conta_id': contaRemoteId ?? localData['conta_id'],
            'ano_mes': localData['ano_mes'],
            'valor': localData['valor'],
            'data_pagamento': localData['data_pagamento'],
            'status': localData['status'],
            'user_id': user.id,
          };

          if (remoteId != null && remoteId.isNotEmpty) {
            await supabase
                .from('pagamentos_mensais')
                .update(remoteData)
                .eq('id', remoteId);
            await db.update(
                DBHelper.tabelaPagamentos, {'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          } else {
            final response = await supabase
                .from('pagamentos_mensais')
                .insert(remoteData)
                .select()
                .single();
            await db.update(DBHelper.tabelaPagamentos,
                {'remote_id': response['id'], 'sync_status': 'synced'},
                where: 'id = ?', whereArgs: [localData['id']]);
          }
        }
      } catch (e) {
        LoggerService.error('Erro ao sincronizar pagamento: $e');
      }
    }
  }

  // ========== METODOS AUXILIARES ==========

  Future<void> markAsPending(String table, dynamic localId) async {
    final db = await dbHelper.database;
    await db.update(
        table,
        {
          'sync_status': 'pending',
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [localId]);
  }

  Future<void> deleteAndSync(
      String table, dynamic localId, String remoteId) async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (remoteId.isNotEmpty && user != null) {
      try {
        await supabase.from(table).delete().eq('id', remoteId);
      } catch (e) {
        LoggerService.error('Erro ao deletar no servidor: $e');
      }
    }
    await db.delete(table, where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> forcarEnvioTodosDados() async {
    await syncAll();
  }
}
