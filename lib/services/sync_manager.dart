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
      LoggerService.info('⚠️ Sincronização já em andamento');
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      LoggerService.info('⚠️ Usuário não logado, ignorando sincronização');
      return;
    }

    _isSyncing = true;
    LoggerService.info('🔄 Iniciando sincronização...');

    try {
      // Enviar pendentes
      await syncPendingLancamentos();
      await syncPendingInvestimentos();
      await syncPendingMetas();
      await syncPendingProventos();
      await syncPendingRendaFixa();
      await syncPendingContas();
      await syncPendingPagamentos();

      // Buscar remotos
      await fetchRemoteLancamentos();
      await fetchRemoteInvestimentos();
      await fetchRemoteMetas();
      await fetchRemoteProventos();
      await fetchRemoteRendaFixa();
      await fetchRemoteContas();

      LoggerService.info('✅ Sincronização completa!');
    } catch (e) {
      LoggerService.error('❌ Erro na sincronização: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ========== SINCRONIZAÇÃO DE LANÇAMENTOS ==========

  Future<void> syncPendingLancamentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info(
        '🔍 Buscando lançamentos pendentes para user: ${user.id}');

    final pending = await db.query(
      DBHelper.tabelaLancamentos,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) {
      LoggerService.info('📤 Nenhum lançamento pendente encontrado');
      return;
    }

    LoggerService.info(
        '📤 Enviando ${pending.length} lançamentos pendentes...');

    for (var localData in pending) {
      LoggerService.info(
          '  📝 Processando: ${localData['descricao']} (ID: ${localData['id']})');

      try {
        String dataStr = localData['data'].toString();
        if (dataStr.contains('T')) {
          dataStr = dataStr.split('T')[0];
        }

        String tipoOriginal = localData['tipo'].toString();
        String tipoCorreto;

        if (tipoOriginal == 'gasto') {
          tipoCorreto = 'despesa';
          LoggerService.info(
              '  🔄 Convertendo tipo "$tipoOriginal" para "$tipoCorreto"');
        } else if (tipoOriginal == 'receita') {
          tipoCorreto = 'receita';
        } else {
          tipoCorreto = 'despesa';
          LoggerService.info(
              '  ⚠️ Tipo desconhecido "$tipoOriginal", usando "despesa"');
        }

        final remoteData = {
          'descricao': localData['descricao'],
          'valor': localData['valor'],
          'tipo': tipoCorreto,
          'categoria': localData['categoria'],
          'data': dataStr,
          'user_id': user.id,
          'observacao': localData['observacao'] ?? '',
        };

        LoggerService.info('  📤 Enviando: $remoteData');

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase
              .from('lancamentos')
              .update(remoteData)
              .eq('id', remoteId);

          await db.update(
            DBHelper.tabelaLancamentos,
            {
              'sync_status': 'synced',
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
          LoggerService.info(
              '  ✅ Lançamento atualizado: ${localData['descricao']}');
        } else {
          final response = await supabase
              .from('lancamentos')
              .insert(remoteData)
              .select()
              .single();

          await db.update(
            DBHelper.tabelaLancamentos,
            {
              'remote_id': response['id'],
              'sync_status': 'synced',
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
          LoggerService.info(
              '  ✅ Lançamento inserido: ${localData['descricao']} (remote_id: ${response['id']})');
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar lançamento: $e');
        await db.update(
          DBHelper.tabelaLancamentos,
          {
            'sync_status': 'failed',
            'updated_at': DateTime.now().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [localData['id']],
        );
      }
    }
  }

  Future<void> fetchRemoteLancamentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info('📥 Buscando lançamentos do servidor...');

    try {
      final remoteLancamentos = await supabase
          .from('lancamentos')
          .select()
          .eq('user_id', user.id)
          .order('criado_em', ascending: false);

      LoggerService.info(
          '  📥 Encontrados ${remoteLancamentos.length} lançamentos remotos');

      for (var remote in remoteLancamentos) {
        final localExists = await db.query(
          DBHelper.tabelaLancamentos,
          where: 'remote_id = ?',
          whereArgs: [remote['id']],
        );

        if (localExists.isEmpty) {
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
            'created_at': remote['criado_em'],
            'updated_at': remote['atualizado_em'],
          });
          LoggerService.info(
              '  📥 Novo lançamento importado: ${remote['descricao']}');
        }
      }
    } catch (e) {
      LoggerService.error('  ❌ Erro ao buscar lançamentos: $e');
    }
  }

  // ========== SINCRONIZAÇÃO DE INVESTIMENTOS ==========

  Future<void> syncPendingInvestimentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaInvestimentos,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) return;
    LoggerService.info(
        '📤 Enviando ${pending.length} investimentos pendentes...');

    for (var localData in pending) {
      try {
        final remoteData = {
          'ticker': localData['ticker'],
          'tipo': localData['tipo'],
          'quantidade': localData['quantidade'],
          'preco_medio': localData['preco_medio'],
          'preco_atual': localData['preco_atual'] ?? localData['preco_medio'],
          'data_compra': localData['data_compra']?.toString().split('T')[0],
          'user_id': user.id,
        };

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase
              .from('investimentos')
              .update(remoteData)
              .eq('id', remoteId);

          await db.update(
            DBHelper.tabelaInvestimentos,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        } else {
          final response = await supabase
              .from('investimentos')
              .insert(remoteData)
              .select()
              .single();

          await db.update(
            DBHelper.tabelaInvestimentos,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar investimento: $e');
      }
    }
  }

  Future<void> fetchRemoteInvestimentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info('📥 Buscando investimentos do servidor...');

    try {
      final remoteInvestimentos =
          await supabase.from('investimentos').select().eq('user_id', user.id);

      for (var remote in remoteInvestimentos) {
        final localExists = await db.query(
          DBHelper.tabelaInvestimentos,
          where: 'remote_id = ?',
          whereArgs: [remote['id']],
        );

        if (localExists.isEmpty) {
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
          LoggerService.info('  📥 Novo investimento: ${remote['ticker']}');
        }
      }
    } catch (e) {
      LoggerService.error('  ❌ Erro ao buscar investimentos: $e');
    }
  }

  // ========== SINCRONIZAÇÃO DE METAS ==========

  Future<void> syncPendingMetas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaMetas,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) return;
    LoggerService.info('📤 Enviando ${pending.length} metas pendentes...');

    for (var localData in pending) {
      try {
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

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase.from('metas').update(remoteData).eq('id', remoteId);
          await db.update(
            DBHelper.tabelaMetas,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        } else {
          final response =
              await supabase.from('metas').insert(remoteData).select().single();

          await db.update(
            DBHelper.tabelaMetas,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar meta: $e');
      }
    }
  }

  Future<void> fetchRemoteMetas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info('📥 Buscando metas do servidor...');

    try {
      final remoteMetas =
          await supabase.from('metas').select().eq('user_id', user.id);

      for (var remote in remoteMetas) {
        final localExists = await db.query(
          DBHelper.tabelaMetas,
          where: 'remote_id = ?',
          whereArgs: [remote['id']],
        );

        if (localExists.isEmpty) {
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
          LoggerService.info('  📥 Nova meta: ${remote['titulo']}');
        }
      }
    } catch (e) {
      LoggerService.error('  ❌ Erro ao buscar metas: $e');
    }
  }

  // ========== SINCRONIZAÇÃO DE PROVENTOS ==========

  Future<void> syncPendingProventos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaProventos,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) return;
    LoggerService.info('📤 Enviando ${pending.length} proventos pendentes...');

    for (var localData in pending) {
      try {
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

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase
              .from('proventos')
              .update(remoteData)
              .eq('id', remoteId);
          await db.update(
            DBHelper.tabelaProventos,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        } else {
          final response = await supabase
              .from('proventos')
              .insert(remoteData)
              .select()
              .single();

          await db.update(
            DBHelper.tabelaProventos,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar provento: $e');
      }
    }
  }

  Future<void> fetchRemoteProventos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info('📥 Buscando proventos do servidor...');

    try {
      final remoteProventos =
          await supabase.from('proventos').select().eq('user_id', user.id);

      for (var remote in remoteProventos) {
        final localExists = await db.query(
          DBHelper.tabelaProventos,
          where: 'remote_id = ?',
          whereArgs: [remote['id']],
        );

        if (localExists.isEmpty) {
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
          LoggerService.info('  📥 Novo provento: ${remote['ticker']}');
        }
      }
    } catch (e) {
      LoggerService.error('  ❌ Erro ao buscar proventos: $e');
    }
  }

  // ========== SINCRONIZAÇÃO DE RENDA FIXA ==========

  Future<void> syncPendingRendaFixa() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaRendaFixa,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) return;
    LoggerService.info(
        '📤 Enviando ${pending.length} investimentos de renda fixa pendentes...');

    for (var localData in pending) {
      try {
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

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase
              .from('renda_fixa')
              .update(remoteData)
              .eq('id', remoteId);
          await db.update(
            DBHelper.tabelaRendaFixa,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        } else {
          final response = await supabase
              .from('renda_fixa')
              .insert(remoteData)
              .select()
              .single();

          await db.update(
            DBHelper.tabelaRendaFixa,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar renda fixa: $e');
      }
    }
  }

  Future<void> fetchRemoteRendaFixa() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info(
        '📥 Buscando investimentos de renda fixa do servidor...');

    try {
      final remoteRendaFixa =
          await supabase.from('renda_fixa').select().eq('user_id', user.id);

      for (var remote in remoteRendaFixa) {
        final localExists = await db.query(
          DBHelper.tabelaRendaFixa,
          where: 'remote_id = ?',
          whereArgs: [remote['id']],
        );

        if (localExists.isEmpty) {
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
          LoggerService.info('  📥 Nova renda fixa: ${remote['nome']}');
        }
      }
    } catch (e) {
      LoggerService.error('  ❌ Erro ao buscar renda fixa: $e');
    }
  }

  // ========== SINCRONIZAÇÃO DE CONTAS ==========

  Future<void> syncPendingContas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaContas,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) return;
    LoggerService.info('📤 Enviando ${pending.length} contas pendentes...');

    for (var localData in pending) {
      try {
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

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase.from('contas').update(remoteData).eq('id', remoteId);
          await db.update(
            DBHelper.tabelaContas,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
          LoggerService.info('  ✅ Conta atualizada: ${localData['nome']}');
        } else {
          final response = await supabase
              .from('contas')
              .insert(remoteData)
              .select()
              .single();
          await db.update(
            DBHelper.tabelaContas,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
          LoggerService.info(
              '  ✅ Conta inserida: ${localData['nome']} (remote_id: ${response['id']})');
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar conta: $e');
      }
    }
  }

  Future<void> fetchRemoteContas() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    LoggerService.info('📥 Buscando contas do servidor...');

    try {
      final remoteContas =
          await supabase.from('contas').select().eq('user_id', user.id);

      for (var remote in remoteContas) {
        final localExists = await db.query(
          DBHelper.tabelaContas,
          where: 'remote_id = ?',
          whereArgs: [remote['id']],
        );

        if (localExists.isEmpty) {
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
          LoggerService.info('  📥 Nova conta: ${remote['nome']}');
        }
      }
    } catch (e) {
      LoggerService.error('  ❌ Erro ao buscar contas: $e');
    }
  }

  // ========== SINCRONIZAÇÃO DE PAGAMENTOS ==========

  Future<void> syncPendingPagamentos() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pending = await db.query(
      DBHelper.tabelaPagamentos,
      where: 'sync_status = ? AND user_id = ?',
      whereArgs: ['pending', user.id],
    );

    if (pending.isEmpty) return;
    LoggerService.info('📤 Enviando ${pending.length} pagamentos pendentes...');

    for (var localData in pending) {
      try {
        // Buscar remote_id da conta associada
        final conta = await db.query(
          DBHelper.tabelaContas,
          where: 'id = ?',
          whereArgs: [localData['conta_id']],
        );
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

        final remoteId = localData['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase
              .from('pagamentos_mensais')
              .update(remoteData)
              .eq('id', remoteId);
          await db.update(
            DBHelper.tabelaPagamentos,
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        } else {
          final response = await supabase
              .from('pagamentos_mensais')
              .insert(remoteData)
              .select()
              .single();
          await db.update(
            DBHelper.tabelaPagamentos,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [localData['id']],
          );
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro ao sincronizar pagamento: $e');
      }
    }
  }

  // ========== MÉTODOS AUXILIARES ==========

  Future<void> markAsPending(String table, int localId) async {
    final db = await dbHelper.database;
    await db.update(
      table,
      {
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String()
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteAndSync(String table, int localId, String remoteId) async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;

    if (remoteId.isNotEmpty && user != null) {
      try {
        await supabase.from(table).delete().eq('id', remoteId);
        LoggerService.info('🗑️ Deletado no servidor: $table/$remoteId');
      } catch (e) {
        LoggerService.error('❌ Erro ao deletar no servidor: $e');
      }
    }

    await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [localId],
    );
    LoggerService.info('🗑️ Deletado localmente: $table/$localId');
  }

  // ========== MÉTODO PARA FORÇAR ENVIO DE TODOS OS DADOS ==========

  Future<void> forcarEnvioTodosDados() async {
    final db = await dbHelper.database;
    final user = supabase.auth.currentUser;
    if (user == null) {
      LoggerService.info('⚠️ Usuário não logado!');
      return;
    }

    LoggerService.info(
        '📤 FORÇANDO ENVIO DE TODOS OS DADOS PARA O SUPABASE...');
    LoggerService.info('🔍 User ID: ${user.id}');

    // ========== LANÇAMENTOS ==========
    final lancamentos = await db.query(
      DBHelper.tabelaLancamentos,
      where: 'user_id = ?',
      whereArgs: [user.id],
    );
    LoggerService.info('📊 LANÇAMENTOS: ${lancamentos.length} encontrados');

    for (var local in lancamentos) {
      try {
        String dataStr = local['data'].toString();
        if (dataStr.contains('T')) {
          dataStr = dataStr.split('T')[0];
        }

        String tipoOriginal = local['tipo'].toString();
        String tipoCorreto;

        if (tipoOriginal == 'gasto') {
          tipoCorreto = 'despesa';
        } else if (tipoOriginal == 'receita') {
          tipoCorreto = 'receita';
        } else {
          tipoCorreto = 'despesa';
        }

        final remoteData = {
          'user_id': user.id,
          'descricao': local['descricao'],
          'valor': local['valor'],
          'tipo': tipoCorreto,
          'categoria': local['categoria'],
          'data': dataStr,
          'observacao': local['observacao'] ?? '',
        };

        final remoteId = local['remote_id'] as String?;

        if (remoteId != null && remoteId.isNotEmpty) {
          await supabase
              .from('lancamentos')
              .update(remoteData)
              .eq('id', remoteId);
          LoggerService.info('  ✅ Atualizado: ${local['descricao']}');
        } else {
          final response = await supabase
              .from('lancamentos')
              .insert(remoteData)
              .select()
              .single();

          await db.update(
            DBHelper.tabelaLancamentos,
            {'remote_id': response['id'], 'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          LoggerService.info(
              '  ✅ Inserido: ${local['descricao']} (remote_id: ${response['id']})');
        }
      } catch (e) {
        LoggerService.error('  ❌ Erro: ${local['descricao']} - $e');
      }
    }

    LoggerService.info('✅ FORÇAMENTO DE ENVIO CONCLUÍDO!');
  }
}
