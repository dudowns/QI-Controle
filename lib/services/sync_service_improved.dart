// lib/services/sync_service_improved.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../services/logger_service.dart';

class SyncServiceImproved {
  static final SyncServiceImproved _instance = SyncServiceImproved._internal();
  factory SyncServiceImproved() => _instance;
  SyncServiceImproved._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DBHelper _dbHelper = DBHelper();

  bool _isSyncing = false;
  DateTime? _lastFullSync;

  // ✅ CACHE PARA EVITAR RECARREGAR TUDO
  Map<String, dynamic> _cache = {};
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 2);

  // ============================================================
  // ✅ SINCRONIZAÇÃO OTIMIZADA - SÓ BUSCA O QUE PRECISA
  // ============================================================
  Future<bool> syncAllData({bool force = false}) async {
    // 🔥 VERIFICA SE JÁ ESTÁ SINCRONIZANDO
    if (_isSyncing) {
      LoggerService.info('⏳ Sincronização já em andamento, ignorando...');
      return false;
    }

    // 🔥 USA CACHE SE FOR RECENTE
    if (!force && _cacheTime != null) {
      final diff = DateTime.now().difference(_cacheTime!);
      if (diff < _cacheDuration) {
        LoggerService.info(
            '📦 Usando cache da sincronização (${diff.inSeconds}s atrás)');
        return true;
      }
    }

    // 🔥 VERIFICA SE PASSOU TEMPO SUFICIENTE DESDE A ÚLTIMA SINC
    if (!force && _lastFullSync != null) {
      final diff = DateTime.now().difference(_lastFullSync!);
      if (diff.inMinutes < 2) {
        LoggerService.info(
            '⏱️ Sincronização recente (${diff.inMinutes}m atrás), ignorando...');
        return true;
      }
    }

    _isSyncing = true;
    LoggerService.info('🔄 Iniciando sincronização OTIMIZADA...');

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        LoggerService.warning('⚠️ Usuário não logado, ignorando sync');
        _isSyncing = false;
        return false;
      }

      final db = await _dbHelper.database;

      // 🔥 SÓ BUSCA DADOS QUE FORAM MODIFICADOS (usando updated_at)
      final lastSync =
          _lastFullSync ?? DateTime.now().subtract(const Duration(days: 7));
      final lastSyncStr = lastSync.toIso8601String();

      LoggerService.info(
          '📡 Buscando dados atualizados desde ${lastSyncStr.substring(0, 10)}...');

      // 🔥 BUSCA EM PARALELO, MAS APENAS OS DADOS NOVOS
      final futures = await Future.wait([
        _supabase
            .from('lancamentos')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
        _supabase
            .from('metas')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
        _supabase
            .from('proventos')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
        _supabase
            .from('renda_fixa')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
        _supabase
            .from('contas')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
        _supabase
            .from('pagamentos_mensais')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
        _supabase
            .from('investments')
            .select()
            .eq('user_id', user.id)
            .gt('updated_at', lastSyncStr),
      ]);

      final lancamentos = futures[0] as List;
      final metas = futures[1] as List;
      final proventos = futures[2] as List;
      final rendaFixa = futures[3] as List;
      final contas = futures[4] as List;
      final pagamentos = futures[5] as List;
      final investments = futures[6] as List;

      LoggerService.info(
          '📊 Dados atualizados: ${lancamentos.length} lançamentos, ${contas.length} contas');

      // 🔥 SE NÃO HOUVER DADOS NOVOS, NÃO FAZ NADA
      if (lancamentos.isEmpty &&
          metas.isEmpty &&
          proventos.isEmpty &&
          rendaFixa.isEmpty &&
          contas.isEmpty &&
          pagamentos.isEmpty &&
          investments.isEmpty) {
        LoggerService.info('✅ Nenhum dado novo para sincronizar');
        _cacheTime = DateTime.now();
        _isSyncing = false;
        return true;
      }

      // 🔥 PROCESSA EM LOTES PARA NÃO TRAVAR A UI
      await db.transaction((txn) async {
        // Processa lançamentos em lotes de 50
        const batchSize = 50;
        for (var i = 0; i < lancamentos.length; i += batchSize) {
          final end = i + batchSize > lancamentos.length
              ? lancamentos.length
              : i + batchSize;
          final batch = lancamentos.sublist(i, end);
          for (var item in batch) {
            await _upsertLancamento(txn, item, user.id);
          }
        }

        for (var item in metas) {
          await _upsertMeta(txn, item, user.id);
        }

        for (var item in proventos) {
          await _upsertProvento(txn, item, user.id);
        }

        for (var item in rendaFixa) {
          await _upsertRendaFixa(txn, item, user.id);
        }

        for (var item in contas) {
          await _upsertConta(txn, item, user.id);
        }

        for (var item in pagamentos) {
          await _upsertPagamento(txn, item, user.id);
        }

        for (var item in investments) {
          await _upsertInvestimento(txn, item, user.id);
        }
      });

      _lastFullSync = DateTime.now();
      _cacheTime = DateTime.now();
      LoggerService.success('✅ Sincronização otimizada finalizada!');
      _isSyncing = false;
      return true;
    } catch (e) {
      LoggerService.error('❌ Erro na sincronização: $e');
      _isSyncing = false;
      return false;
    }
  }

  // ============================================================
  // ✅ UPSERT CONTA - VERIFICA DUPLICATA
  // ============================================================
  Future<void> _upsertConta(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();

      final existing = await txn.query(
        DBHelper.tabelaContas,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      if (existing.isNotEmpty) {
        final Map<String, dynamic> data = {
          'remote_id': remoteId,
          'user_id': userId,
          'nome': item['nome'] ?? '',
          'valor': (item['valor_estimado'] ?? item['valor'] ?? 0.0) as double,
          'dia_vencimento': item['dia_vencimento'] as int? ?? 1,
          'tipo': item['tipo'] ?? 'mensal',
          'categoria': item['categoria'] ?? 'Outros',
          'ativa': item['ativa'] as int? ?? 1,
          'parcelas_total': item['parcelas_total'] as int?,
          'parcelas_pagas': item['parcelas_pagas'] as int? ?? 0,
          'data_inicio':
              item['data_inicio'] ?? DateTime.now().toIso8601String(),
          'sync_status': 'synced',
        };

        await txn.update(
          DBHelper.tabelaContas,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
        return;
      }

      final Map<String, dynamic> data = {
        'remote_id': remoteId,
        'user_id': userId,
        'nome': item['nome'] ?? '',
        'valor': (item['valor_estimado'] ?? item['valor'] ?? 0.0) as double,
        'dia_vencimento': item['dia_vencimento'] as int? ?? 1,
        'tipo': item['tipo'] ?? 'mensal',
        'categoria': item['categoria'] ?? 'Outros',
        'ativa': item['ativa'] as int? ?? 1,
        'parcelas_total': item['parcelas_total'] as int?,
        'parcelas_pagas': item['parcelas_pagas'] as int? ?? 0,
        'data_inicio': item['data_inicio'] ?? DateTime.now().toIso8601String(),
        'sync_status': 'synced',
      };

      await txn.insert(DBHelper.tabelaContas, data);
    } catch (e) {
      LoggerService.error('Erro ao upsert conta: $e');
    }
  }

  // ============================================================
  // ✅ UPSERT PAGAMENTO - VERIFICA DUPLICATA
  // ============================================================
  Future<void> _upsertPagamento(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();

      final existing = await txn.query(
        DBHelper.tabelaPagamentos,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      final Map<String, dynamic> data = {
        'id': remoteId,
        'remote_id': remoteId,
        'user_id': userId,
        'conta_id': item['conta_id']?.toString() ?? '',
        'ano_mes': item['ano_mes'] as int? ?? 0,
        'valor': (item['valor'] as num?)?.toDouble() ?? 0.0,
        'data_pagamento': item['data_pagamento'],
        'status': item['status'] as int? ?? 0,
        'lancamento_id': item['lancamento_id']?.toString(),
        'sync_status': 'synced',
      };

      if (existing.isNotEmpty) {
        await txn.update(
          DBHelper.tabelaPagamentos,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
      } else {
        await txn.insert(DBHelper.tabelaPagamentos, data);
      }
    } catch (e) {
      LoggerService.error('Erro ao upsert pagamento: $e');
    }
  }

  // ============================================================
  // ✅ UPSERT LANÇAMENTO
  // ============================================================
  Future<void> _upsertLancamento(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();
      final existing = await txn.query(
        DBHelper.tabelaLancamentos,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      final Map<String, dynamic> data = {
        'remote_id': remoteId,
        'user_id': userId,
        'descricao': item['descricao'] ?? '',
        'valor': (item['valor'] as num?)?.toDouble() ?? 0.0,
        'tipo': item['tipo'] ?? 'gasto',
        'categoria': item['categoria'] ?? 'Outros',
        'data': item['data'] ?? DateTime.now().toIso8601String(),
        'observacao': item['observacao'] ?? '',
        'sync_status': 'synced',
      };

      if (existing.isNotEmpty) {
        await txn.update(
          DBHelper.tabelaLancamentos,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
      } else {
        await txn.insert(DBHelper.tabelaLancamentos, data);
      }
    } catch (e) {
      LoggerService.error('Erro ao upsert lançamento: $e');
    }
  }

  // ============================================================
  // ✅ UPSERT META
  // ============================================================
  Future<void> _upsertMeta(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();
      final existing = await txn.query(
        DBHelper.tabelaMetas,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      final Map<String, dynamic> data = {
        'remote_id': remoteId,
        'user_id': userId,
        'titulo': item['titulo'] ?? '',
        'descricao': item['descricao'] ?? '',
        'valor_objetivo': (item['valor_objetivo'] as num?)?.toDouble() ?? 0.0,
        'valor_atual': (item['valor_atual'] as num?)?.toDouble() ?? 0.0,
        'data_inicio': item['data_inicio'] ?? DateTime.now().toIso8601String(),
        'data_fim': item['data_fim'] ?? DateTime.now().toIso8601String(),
        'cor': item['cor'] ?? 'geral',
        'icone': item['icone'] ?? 'flag',
        'concluida': item['concluida'] as int? ?? 0,
        'sync_status': 'synced',
      };

      if (existing.isNotEmpty) {
        await txn.update(
          DBHelper.tabelaMetas,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
      } else {
        await txn.insert(DBHelper.tabelaMetas, data);
      }
    } catch (e) {
      LoggerService.error('Erro ao upsert meta: $e');
    }
  }

  // ============================================================
  // ✅ UPSERT PROVENTO
  // ============================================================
  Future<void> _upsertProvento(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();
      final existing = await txn.query(
        DBHelper.tabelaProventos,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      final qtd = (item['quantidade'] as num?)?.toDouble() ?? 1.0;
      final valorPorCota = (item['valor_por_cota'] as num?)?.toDouble() ?? 0.0;

      final Map<String, dynamic> data = {
        'remote_id': remoteId,
        'user_id': userId,
        'ticker': item['ticker']?.toString().toUpperCase() ?? '',
        'tipo_provento': item['tipo_provento'] ?? 'DIVIDENDO',
        'valor_por_cota': valorPorCota,
        'quantidade': qtd,
        'total_recebido': item['total_recebido'] ?? (valorPorCota * qtd),
        'data_pagamento':
            item['data_pagamento'] ?? DateTime.now().toIso8601String(),
        'data_com': item['data_com'],
        'sync_status': 'synced',
      };

      if (existing.isNotEmpty) {
        await txn.update(
          DBHelper.tabelaProventos,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
      } else {
        await txn.insert(DBHelper.tabelaProventos, data);
      }
    } catch (e) {
      LoggerService.error('Erro ao upsert provento: $e');
    }
  }

  // ============================================================
  // ✅ UPSERT RENDA FIXA
  // ============================================================
  Future<void> _upsertRendaFixa(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();
      final existing = await txn.query(
        DBHelper.tabelaRendaFixa,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      final Map<String, dynamic> data = {
        'remote_id': remoteId,
        'user_id': userId,
        'nome': item['nome'] ?? '',
        'tipo_renda': item['tipo_renda'] ?? 'CDB',
        'valor': (item['valor_aplicado'] ?? item['valor'] ?? 0.0) as double,
        'taxa': (item['taxa'] as num?)?.toDouble() ?? 0.0,
        'data_aplicacao':
            item['data_aplicacao'] ?? DateTime.now().toIso8601String(),
        'data_vencimento':
            item['data_vencimento'] ?? DateTime.now().toIso8601String(),
        'indexador': item['indexador'] ?? 'preFixado',
        'liquidez':
            item['liquidez_diaria'] == true ? 'Diária' : 'No vencimento',
        'observacao': item['observacao'] ?? '',
        'sync_status': 'synced',
      };

      if (existing.isNotEmpty) {
        await txn.update(
          DBHelper.tabelaRendaFixa,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
      } else {
        await txn.insert(DBHelper.tabelaRendaFixa, data);
      }
    } catch (e) {
      LoggerService.error('Erro ao upsert renda fixa: $e');
    }
  }

  // ============================================================
  // ✅ UPSERT INVESTIMENTO
  // ============================================================
  Future<void> _upsertInvestimento(
      Transaction txn, Map<String, dynamic> item, String userId) async {
    try {
      final remoteId = item['id'].toString();
      final existing = await txn.query(
        DBHelper.tabelaInvestimentos,
        where: 'remote_id = ? OR id = ?',
        whereArgs: [remoteId, remoteId],
      );

      final Map<String, dynamic> data = {
        'remote_id': remoteId,
        'user_id': userId,
        'ticker': item['ticker']?.toString().toUpperCase() ?? '',
        'tipo': item['tipo'] ?? 'ACAO',
        'tipo_transacao': 'COMPRA',
        'quantidade': (item['quantidade'] as num?)?.toDouble() ?? 0.0,
        'preco_medio': (item['preco_medio'] as num?)?.toDouble() ?? 0.0,
        'preco_atual': (item['preco_atual'] as num?)?.toDouble() ?? 0.0,
        'data_compra': item['data_compra'] ?? DateTime.now().toIso8601String(),
        'sync_status': 'synced',
      };

      if (existing.isNotEmpty) {
        await txn.update(
          DBHelper.tabelaInvestimentos,
          data,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );
      } else {
        await txn.insert(DBHelper.tabelaInvestimentos, data);
      }
    } catch (e) {
      LoggerService.error('Erro ao upsert investimento: $e');
    }
  }

  // ============================================================
  // ✅ SINCRONIZAR CONTAS DO MÊS
  // ============================================================
  Future<bool> syncContasDoMes(int ano, int mes) async {
    if (_isSyncing) {
      LoggerService.info(
          '⏳ Sincronização já em andamento, ignorando syncContasDoMes...');
      return false;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final anoMes = ano * 100 + mes;
      LoggerService.info('🔄 Sincronizando contas do mês $ano/$mes...');

      final db = await _dbHelper.database;

      final remote = await _supabase
          .from('pagamentos_mensais')
          .select()
          .eq('user_id', user.id)
          .eq('ano_mes', anoMes);

      LoggerService.info('📊 Encontrados ${remote.length} pagamentos remotos');

      await db.transaction((txn) async {
        await txn.delete(
          DBHelper.tabelaPagamentos,
          where: 'ano_mes = ? AND user_id = ?',
          whereArgs: [anoMes, user.id],
        );

        for (var item in remote) {
          await _upsertPagamento(txn, item, user.id);
        }
      });

      await _syncContas(db, user.id);

      LoggerService.success('✅ Contas do mês sincronizadas!');
      return true;
    } catch (e) {
      LoggerService.error('❌ Erro ao sincronizar contas do mês: $e');
      return false;
    }
  }

  Future<void> _syncContas(Database db, String userId) async {
    try {
      final remote =
          await _supabase.from('contas').select().eq('user_id', userId);

      for (var item in remote) {
        final remoteId = item['id'].toString();

        final existing = await db.query(
          DBHelper.tabelaContas,
          where: 'remote_id = ? OR id = ?',
          whereArgs: [remoteId, remoteId],
        );

        final Map<String, dynamic> data = {
          'remote_id': remoteId,
          'user_id': userId,
          'nome': item['nome'] ?? '',
          'valor': (item['valor_estimado'] ?? item['valor'] ?? 0.0) as double,
          'dia_vencimento': item['dia_vencimento'] as int? ?? 1,
          'tipo': item['tipo'] ?? 'mensal',
          'categoria': item['categoria'] ?? 'Outros',
          'ativa': item['ativa'] as int? ?? 1,
          'parcelas_total': item['parcelas_total'] as int?,
          'parcelas_pagas': item['parcelas_pagas'] as int? ?? 0,
          'sync_status': 'synced',
        };

        if (existing.isNotEmpty) {
          await db.update(
            DBHelper.tabelaContas,
            data,
            where: 'remote_id = ? OR id = ?',
            whereArgs: [remoteId, remoteId],
          );
        } else {
          await db.insert(DBHelper.tabelaContas, data);
        }
      }
    } catch (e) {
      LoggerService.error('Erro ao sincronizar contas: $e');
    }
  }

  // ============================================================
  // ✅ SINCRONIZAR PROVENTOS
  // ============================================================
  Future<bool> syncProventos() async {
    if (_isSyncing) {
      LoggerService.info(
          '⏳ Sincronização já em andamento, ignorando syncProventos...');
      return false;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      LoggerService.info('🔄 Sincronizando proventos...');

      final db = await _dbHelper.database;
      final remote = await _supabase
          .from('proventos')
          .select()
          .eq('user_id', user.id)
          .order('data_pagamento', ascending: false);

      await db.transaction((txn) async {
        for (var item in remote) {
          await _upsertProvento(txn, item, user.id);
        }
      });

      LoggerService.success('✅ Proventos sincronizados!');
      return true;
    } catch (e) {
      LoggerService.error('❌ Erro ao sincronizar proventos: $e');
      return false;
    }
  }

  // ============================================================
  // ✅ FORÇAR SINCRONIZAÇÃO
  // ============================================================
  Future<void> forceFullSync() async {
    LoggerService.info('🚀 FORÇANDO sincronização completa...');
    await syncAllData(force: true);
  }

  // ============================================================
  // ✅ GETTERS
  // ============================================================
  bool get isSyncing => _isSyncing;

  DateTime? getLastSyncTime() => _lastFullSync;

  void clearCache() {
    _cache.clear();
    _cacheTime = null;
    LoggerService.info('🗑️ Cache limpo');
  }
}
