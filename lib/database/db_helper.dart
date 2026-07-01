// lib/database/db_helper.dart
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;

// 🔥 CORREÇÃO DOS 6 ERROS: Importações diretas e seguras
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' as web_sqflite;

import 'package:path_provider/path_provider.dart';
import '../services/performance_service.dart';
import '../services/logger_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StatusPagamento {
  pendente,
  pago,
  atrasado,
}

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);

  bool get isValid =>
      DateTime.now().difference(timestamp) < DBHelper.cacheValidity;
}

enum OrdemLancamento {
  dataDesc,
  dataAsc,
  valorDesc,
  valorAsc,
}

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  static final Map<String, CacheEntry> _queryCache = {};

  static const Duration cacheValidity = Duration(minutes: 15);

  static const Duration dbTimeout = Duration(seconds: 30);

  static final Set<String> _pendingQueries = {};

  static const String tabelaLancamentos = 'lancamentos';
  static const String tabelaMetas = 'metas';
  static const String tabelaDepositosMeta = 'depositos_meta';
  static const String tabelaInvestimentos = 'investments';
  static const String tabelaProventos = 'proventos';
  static const String tabelaRendaFixa = 'renda_fixa';
  static const String tabelaContas = 'contas';
  static const String tabelaPagamentos = 'pagamentos_mensais';
  static const String tabelaContasFixas = 'contas_fixas';
  static const String tabelaParcelas = 'parcelas';

  Future<Database> get database async {
    if (_database != null) return _database!;

    String path;

    if (kIsWeb) {
      // 🌐 WEB: Configuração para Web
      LoggerService.info('🌐 Web detectado: Usando banco virtual.');
      databaseFactory = web_sqflite.databaseFactoryFfiWeb;
      path = 'financeiro.db';
    } else {
      // 🪟 DESKTOP: Configuração para Windows
      LoggerService.info('🖥️ Desktop detectado: Inicializando FFI.');
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;

      final appDir = await getApplicationSupportDirectory();
      path = p.join(appDir.path, 'financeiro.db');
    }

    LoggerService.info('📁 Banco de dados em: $path');

    _database = await _initDB(path).timeout(dbTimeout, onTimeout: () {
      LoggerService.error('⏱️ Timeout ao inicializar banco de dados');
      throw Exception(
          '⏱️ Timeout: Inicialização do banco de dados excedeu $dbTimeout');
    });
    return _database!;
  }

  Future<Database> _initDB(String path) async {
    return await openDatabase(
      path,
      version: 32,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
        await db.execute('PRAGMA cache_size = -50000');
        await db.execute('PRAGMA temp_store = MEMORY');
        await db.execute('PRAGMA mmap_size = 268435456');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    LoggerService.info('🔨 Criando tabelas versão $version');

    await db.execute("CREATE TABLE IF NOT EXISTS lancamentos ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "valor REAL NOT NULL, "
        "descricao TEXT NOT NULL, "
        "tipo TEXT NOT NULL, "
        "categoria TEXT NOT NULL, "
        "data TEXT NOT NULL, "
        "observacao TEXT, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS metas ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "titulo TEXT NOT NULL, "
        "descricao TEXT, "
        "valor_objetivo REAL NOT NULL, "
        "valor_atual REAL DEFAULT 0, "
        "data_inicio TEXT NOT NULL, "
        "data_fim TEXT NOT NULL, "
        "cor TEXT, "
        "icone TEXT, "
        "concluida INTEGER DEFAULT 0, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS depositos_meta ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "meta_id INTEGER NOT NULL, "
        "valor REAL NOT NULL, "
        "data_deposito TEXT NOT NULL, "
        "observacao TEXT, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT, "
        "FOREIGN KEY (meta_id) REFERENCES metas(id) ON DELETE CASCADE)");

    await db.execute("CREATE TABLE IF NOT EXISTS investments ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "ticker TEXT NOT NULL, "
        "tipo TEXT NOT NULL, "
        "tipo_transacao TEXT DEFAULT 'COMPRA', "
        "quantidade REAL NOT NULL, "
        "preco_medio REAL NOT NULL, "
        "preco_atual REAL, "
        "data_compra TEXT, "
        "corretora TEXT, "
        "setor TEXT, "
        "dividend_yield REAL, "
        "ultima_atualizacao TEXT, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS proventos ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "ticker TEXT NOT NULL, "
        "tipo_provento TEXT, "
        "valor_por_cota REAL NOT NULL, "
        "quantidade REAL DEFAULT 1, "
        "data_pagamento TEXT NOT NULL, "
        "data_com TEXT, "
        "total_recebido REAL, "
        "sync_automatico INTEGER DEFAULT 0, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS renda_fixa ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "nome TEXT NOT NULL, "
        "tipo_renda TEXT NOT NULL, "
        "valor REAL NOT NULL, "
        "taxa REAL NOT NULL, "
        "data_aplicacao TEXT NOT NULL, "
        "data_vencimento TEXT NOT NULL, "
        "dias INTEGER, "
        "rendimento_bruto REAL, "
        "iof REAL, "
        "ir REAL, "
        "rendimento_liquido REAL, "
        "valor_final REAL, "
        "indexador TEXT, "
        "liquidez TEXT DEFAULT 'Diária', "
        "is_lci INTEGER DEFAULT 0, "
        "status TEXT DEFAULT 'ativo', "
        "observacao TEXT, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS contas ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "nome TEXT NOT NULL, "
        "valor REAL NOT NULL, "
        "dia_vencimento INTEGER NOT NULL, "
        "tipo TEXT NOT NULL, "
        "categoria TEXT, "
        "ativa INTEGER DEFAULT 1, "
        "parcelas_total INTEGER, "
        "parcelas_pagas INTEGER DEFAULT 0, "
        "data_inicio TEXT, "
        "data_fim TEXT, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS pagamentos_mensais ("
        "id TEXT PRIMARY KEY, "
        "remote_id TEXT, "
        "user_id TEXT, "
        "conta_id TEXT NOT NULL, "
        "ano_mes INTEGER NOT NULL, "
        "valor REAL NOT NULL, "
        "data_pagamento TEXT, "
        "status INTEGER NOT NULL, "
        "lancamento_id TEXT, "
        "sync_status TEXT DEFAULT 'pending', "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS contas_fixas ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "nome TEXT NOT NULL, "
        "valor_total REAL NOT NULL, "
        "total_parcelas INTEGER NOT NULL, "
        "data_inicio TEXT NOT NULL, "
        "categoria TEXT, "
        "observacao TEXT, "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT)");

    await db.execute("CREATE TABLE IF NOT EXISTS parcelas ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "conta_id INTEGER NOT NULL, "
        "numero INTEGER NOT NULL, "
        "data_vencimento TEXT NOT NULL, "
        "status INTEGER NOT NULL, "
        "data_pagamento TEXT, "
        "valor_pago REAL, "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "updated_at TEXT DEFAULT CURRENT_TIMESTAMP, "
        "deleted_at TEXT, "
        "criado_em TEXT, "
        "atualizado_em TEXT, "
        "FOREIGN KEY (conta_id) REFERENCES contas_fixas(id) ON DELETE CASCADE)");

    await db.execute("CREATE TABLE IF NOT EXISTS integridade_logs ("
        "id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "tipo TEXT NOT NULL, "
        "mensagem TEXT NOT NULL, "
        "detalhes TEXT, "
        "created_at TEXT DEFAULT CURRENT_TIMESTAMP)");

    await _criarIndices(db);
    await _criarIndicesCompostos(db);
    LoggerService.success('✅ Tabelas criadas com sucesso!');
  }

  Future<void> _criarIndices(Database db) async {
    final indicesExistentes =
        await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index'");
    final nomesIndices =
        indicesExistentes.map((e) => e['name'] as String).toList();

    if (!nomesIndices.contains('idx_lancamentos_data')) {
      await db
          .execute('CREATE INDEX idx_lancamentos_data ON lancamentos(data)');
    }
    if (!nomesIndices.contains('idx_lancamentos_tipo')) {
      await db
          .execute('CREATE INDEX idx_lancamentos_tipo ON lancamentos(tipo)');
    }
    if (!nomesIndices.contains('idx_lancamentos_categoria')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_categoria ON lancamentos(categoria)');
    }
    if (!nomesIndices.contains('idx_lancamentos_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_sync_status ON lancamentos(sync_status)');
    }
    if (!nomesIndices.contains('idx_metas_concluida')) {
      await db.execute('CREATE INDEX idx_metas_concluida ON metas(concluida)');
    }
    if (!nomesIndices.contains('idx_metas_data_fim')) {
      await db.execute('CREATE INDEX idx_metas_data_fim ON metas(data_fim)');
    }
    if (!nomesIndices.contains('idx_metas_sync_status')) {
      await db
          .execute('CREATE INDEX idx_metas_sync_status ON metas(sync_status)');
    }
    if (!nomesIndices.contains('idx_investimentos_ticker')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_ticker ON investments(ticker)');
    }
    if (!nomesIndices.contains('idx_investimentos_tipo')) {
      await db
          .execute('CREATE INDEX idx_investimentos_tipo ON investments(tipo)');
    }
    if (!nomesIndices.contains('idx_investimentos_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_sync_status ON investments(sync_status)');
    }
    if (!nomesIndices.contains('idx_investimentos_user_id')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_user_id ON investments(user_id)');
    }
    if (!nomesIndices.contains('idx_investimentos_deleted_at')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_deleted_at ON investments(deleted_at)');
    }
    if (!nomesIndices.contains('idx_proventos_data_pagamento')) {
      await db.execute(
          'CREATE INDEX idx_proventos_data_pagamento ON proventos(data_pagamento)');
    }
    if (!nomesIndices.contains('idx_proventos_ticker')) {
      await db
          .execute('CREATE INDEX idx_proventos_ticker ON proventos(ticker)');
    }
    if (!nomesIndices.contains('idx_proventos_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_proventos_sync_status ON proventos(sync_status)');
    }
    if (!nomesIndices.contains('idx_proventos_deleted_at')) {
      await db.execute(
          'CREATE INDEX idx_proventos_deleted_at ON proventos(deleted_at)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_vencimento')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_vencimento ON renda_fixa(data_vencimento)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_status')) {
      await db
          .execute('CREATE INDEX idx_renda_fixa_status ON renda_fixa(status)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_sync_status ON renda_fixa(sync_status)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_user_id')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_user_id ON renda_fixa(user_id)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_deleted_at')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_deleted_at ON renda_fixa(deleted_at)');
    }
    if (!nomesIndices.contains('idx_pagamentos_conta')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_conta ON pagamentos_mensais(conta_id)');
    }
    if (!nomesIndices.contains('idx_pagamentos_mes')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_mes ON pagamentos_mensais(ano_mes)');
    }
    if (!nomesIndices.contains('idx_pagamentos_status')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_status ON pagamentos_mensais(status)');
    }
    if (!nomesIndices.contains('idx_pagamentos_user_id')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_user_id ON pagamentos_mensais(user_id)');
    }
    if (!nomesIndices.contains('idx_pagamentos_deleted_at')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_deleted_at ON pagamentos_mensais(deleted_at)');
    }
    if (!nomesIndices.contains('idx_contas_ativa')) {
      await db.execute('CREATE INDEX idx_contas_ativa ON contas(ativa)');
    }
    if (!nomesIndices.contains('idx_contas_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_contas_sync_status ON contas(sync_status)');
    }
    if (!nomesIndices.contains('idx_contas_user_id')) {
      await db.execute('CREATE INDEX idx_contas_user_id ON contas(user_id)');
    }
    if (!nomesIndices.contains('idx_contas_deleted_at')) {
      await db
          .execute('CREATE INDEX idx_contas_deleted_at ON contas(deleted_at)');
    }
    if (!nomesIndices.contains('idx_lancamentos_user_id')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_user_id ON lancamentos(user_id)');
    }
    if (!nomesIndices.contains('idx_lancamentos_deleted_at')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_deleted_at ON lancamentos(deleted_at)');
    }
    if (!nomesIndices.contains('idx_metas_deleted_at')) {
      await db
          .execute('CREATE INDEX idx_metas_deleted_at ON metas(deleted_at)');
    }
    if (!nomesIndices.contains('idx_contas_fixas_data_inicio')) {
      await db.execute(
          'CREATE INDEX idx_contas_fixas_data_inicio ON contas_fixas(data_inicio)');
    }
    if (!nomesIndices.contains('idx_parcelas_conta_id')) {
      await db
          .execute('CREATE INDEX idx_parcelas_conta_id ON parcelas(conta_id)');
    }
    if (!nomesIndices.contains('idx_parcelas_status')) {
      await db.execute('CREATE INDEX idx_parcelas_status ON parcelas(status)');
    }
    if (!nomesIndices.contains('idx_parcelas_data_vencimento')) {
      await db.execute(
          'CREATE INDEX idx_parcelas_data_vencimento ON parcelas(data_vencimento)');
    }
  }

  Future<void> _criarIndicesCompostos(Database db) async {
    LoggerService.info('🔧 Criando índices compostos para performance...');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lancamentos_data_tipo ON lancamentos(data, tipo)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lancamentos_data_categoria ON lancamentos(data, categoria)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lancamentos_tipo_categoria ON lancamentos(tipo, categoria)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_lancamentos_data_tipo_valor ON lancamentos(data, tipo, valor)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pagamentos_ano_mes_status ON pagamentos_mensais(ano_mes, status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_contas_ativa_tipo ON contas(ativa, tipo)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_metas_concluida_data_fim ON metas(concluida, data_fim)');
    LoggerService.success('✅ Índices compostos criados!');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    LoggerService.info('🔄 Atualizando banco: $oldVersion -> $newVersion');
    if (oldVersion < 31) {
      final tabelas = [
        tabelaLancamentos,
        tabelaMetas,
        tabelaDepositosMeta,
        tabelaInvestimentos,
        tabelaProventos,
        tabelaRendaFixa,
        tabelaContas,
        tabelaPagamentos,
        tabelaContasFixas,
        tabelaParcelas
      ];
      for (var tabela in tabelas) {
        try {
          final columns = await db.rawQuery("PRAGMA table_info($tabela)");
          if (!columns.any((col) => col['name'] == 'deleted_at')) {
            await db.execute('ALTER TABLE $tabela ADD COLUMN deleted_at TEXT');
          }
        } catch (e) {
          LoggerService.warning(
              '⚠️ Erro ao adicionar deleted_at em $tabela: $e');
        }
      }
    }
    if (oldVersion < 30) {
      final oldData = await db.query(tabelaPagamentos);
      await db.execute('DROP TABLE IF EXISTS pagamentos_mensais');
      await db.execute(
          'CREATE TABLE pagamentos_mensais(id TEXT PRIMARY KEY, remote_id TEXT, user_id TEXT, conta_id TEXT NOT NULL, ano_mes INTEGER NOT NULL, valor REAL NOT NULL, data_pagamento TEXT, status INTEGER NOT NULL, lancamento_id TEXT, sync_status TEXT DEFAULT \'pending\', created_at TEXT DEFAULT CURRENT_TIMESTAMP, updated_at TEXT DEFAULT CURRENT_TIMESTAMP, deleted_at TEXT, criado_em TEXT, atualizado_em TEXT)');
      for (var row in oldData) {
        try {
          await db.insert(tabelaPagamentos, {
            'id': row['id']?.toString() ?? _generateUUID(),
            'remote_id': row['remote_id']?.toString(),
            'user_id': row['user_id']?.toString(),
            'conta_id': row['conta_id']?.toString() ?? '',
            'ano_mes': row['ano_mes'],
            'valor': row['valor'],
            'data_pagamento': row['data_pagamento'],
            'status': row['status'],
            'lancamento_id': row['lancamento_id']?.toString(),
            'sync_status': row['sync_status'] ?? 'pending',
            'created_at': row['created_at'],
            'updated_at': row['updated_at'],
            'deleted_at': null
          });
        } catch (e) {
          LoggerService.error('Erro ao migrar pagamento: $e');
        }
      }
    }
    if (oldVersion < 29) {
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info(renda_fixa)');
        if (!tableInfo
            .map((c) => c['name'] as String)
            .toList()
            .contains('observacao')) {
          await db.execute('ALTER TABLE renda_fixa ADD COLUMN observacao TEXT');
        }
      } catch (e) {
        LoggerService.warning('⚠️ Erro ao atualizar tabela renda_fixa: $e');
      }
    }
    await _criarIndices(db);
    LoggerService.success('✅ Migração para versão $newVersion concluída!');
  }

  // ========== MÉTODOS GENÉRICOS ==========
  void _clearTableCache(String table) {
    _queryCache.removeWhere((key, _) => key.startsWith('${table}_'));
  }

  void _clearQueryCache() {
    if (_queryCache.length > 50) {
      final tamanhoAnterior = _queryCache.length;
      _queryCache.clear();
      LoggerService.info(
          '🗑️ Cache limpo ($tamanhoAnterior entradas removidas)');
    }
  }

  String _agoraBrasil() => DateTime.now().toIso8601String();
  String _generateUUID() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (DateTime.now().microsecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    return '$timestamp-$random-${Random().nextInt(9999)}';
  }

  Future<void> _adicionarUserId(Map<String, dynamic> data) async {
    if (!data.containsKey('user_id')) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        data['user_id'] = user.id;
      }
    }
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    PerformanceService.start('db_insert_$table');
    final db = await database;
    try {
      await _adicionarUserId(data);
      data['created_at'] = _agoraBrasil();
      data['updated_at'] = _agoraBrasil();
      if (!data.containsKey('sync_status')) data['sync_status'] = 'pending';
      data.remove('deleted_at');
      final result = await db.insert(table, data).timeout(dbTimeout);
      _clearTableCache(table);
      PerformanceService.stop('db_insert_$table');
      return result;
    } catch (e) {
      LoggerService.error('Erro ao inserir em $table', e);
      rethrow;
    }
  }

  Future<int> update(
      String table, Map<String, dynamic> data, dynamic id) async {
    PerformanceService.start('db_update_$table');
    final db = await database;
    try {
      final Map<String, dynamic> dataToUpdate = Map<String, dynamic>.from(data);
      dataToUpdate.remove('id');
      dataToUpdate.remove('user_id');
      dataToUpdate.remove('created_at');
      dataToUpdate.remove('deleted_at');
      dataToUpdate['updated_at'] = _agoraBrasil();
      dataToUpdate['sync_status'] = 'pending';
      final result = await db.update(
        table,
        dataToUpdate,
        where: 'id = ?',
        whereArgs: [id],
      ).timeout(dbTimeout);
      if (result == 0) {
        LoggerService.warning(
            '⚠️ UPDATE: Nenhuma linha alterada para o ID "$id" na tabela "$table".');
      } else {
        LoggerService.info(
            '💾 UPDATE SUCESSO: Tabela "$table", ID "$id" alterado.');
      }
      _clearTableCache(table);
      PerformanceService.stop('db_update_$table');
      return result;
    } catch (e) {
      LoggerService.error('Erro ao atualizar $table', e);
      rethrow;
    }
  }

  Future<int> softDelete(String table, dynamic id) async {
    final db = await database;
    final result = await db
        .update(
            table,
            {
              'deleted_at': _agoraBrasil(),
              'sync_status': 'deleted',
              'updated_at': _agoraBrasil()
            },
            where: 'id = ? OR remote_id = ?',
            whereArgs: [id, id])
        .timeout(dbTimeout);
    _clearTableCache(table);
    return result;
  }

  Future<int> hardDelete(String table, dynamic id) async {
    final db = await database;
    final result = await db.delete(table,
        where: 'id = ? OR remote_id = ?',
        whereArgs: [id, id]).timeout(dbTimeout);
    _clearTableCache(table);
    return result;
  }

  Future<int> delete(String table, dynamic id) async =>
      await hardDelete(table, id);

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where,
      List<dynamic>? whereArgs,
      String? orderBy,
      int? limit,
      int? offset,
      bool useCache = true,
      bool excludeDeleted = true}) async {
    String finalWhere = where ?? '1=1';
    List<dynamic> finalWhereArgs = whereArgs ?? [];
    if (excludeDeleted) {
      finalWhere += ' AND (deleted_at IS NULL)';
    }
    final cacheKey = '${table}_${finalWhere}_${orderBy}_${limit}_$offset';

    if (_pendingQueries.contains(cacheKey)) {
      PerformanceService.stop('db_query_$table (cache)');
      LoggerService.info('⏭️ Query já em andamento: $cacheKey');
      return [];
    }

    if (useCache &&
        _queryCache.containsKey(cacheKey) &&
        _queryCache[cacheKey]!.isValid) {
      PerformanceService.stop('db_query_$table (cache)');
      return List<Map<String, dynamic>>.from(_queryCache[cacheKey]!.data);
    }

    _pendingQueries.add(cacheKey);
    PerformanceService.start('db_query_$table');
    try {
      final db = await database;
      final result = await db
          .query(table,
              where: finalWhere,
              whereArgs: finalWhereArgs,
              orderBy: orderBy,
              limit: limit,
              offset: offset)
          .timeout(dbTimeout);
      if (useCache) _queryCache[cacheKey] = CacheEntry(result, DateTime.now());
      PerformanceService.stop('db_query_$table');
      return result;
    } finally {
      _pendingQueries.remove(cacheKey);
    }
  }

  // ========== MÉTODOS ESPECÍFICOS ==========
  Future<int> insertLancamento(Map<String, dynamic> l) async =>
      await insert(tabelaLancamentos, l);
  Future<List<Map<String, dynamic>>> getAllLancamentos() async =>
      await query(tabelaLancamentos,
          orderBy: 'data DESC, id DESC', useCache: true);
  Future<Map<String, dynamic>?> getLancamentoById(dynamic id) async {
    final r = await query(tabelaLancamentos,
        where: 'id = ? OR remote_id = ?', whereArgs: [id, id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> updateLancamento(Map<String, dynamic> l) async {
    final id = l['id'];
    return await update(tabelaLancamentos, l, id);
  }

  Future<int> deleteLancamento(dynamic id) async =>
      await softDelete(tabelaLancamentos, id);

  Future<int> insertProvento(Map<String, dynamic> p) async {
    if (p['total_recebido'] == null) {
      final q = (p['quantidade'] as num?)?.toDouble() ?? 1;
      p['total_recebido'] = q * (p['valor_por_cota'] as num).toDouble();
    }
    if (p['ticker'] != null) p['ticker'] = p['ticker'].toString().toUpperCase();
    return await insert(tabelaProventos, p);
  }

  Future<List<Map<String, dynamic>>> getAllProventos() async =>
      await query(tabelaProventos,
          orderBy: 'data_pagamento DESC', useCache: true);
  Future<int> updateProvento(Map<String, dynamic> p) async {
    final id = p['id'];
    if (p['ticker'] != null) p['ticker'] = p['ticker'].toString().toUpperCase();
    return await update(tabelaProventos, p, id);
  }

  Future<int> deleteProvento(dynamic id) async =>
      await softDelete(tabelaProventos, id);

  Future<int> insertInvestimento(Map<String, dynamic> i) async {
    i['ultima_atualizacao'] = _agoraBrasil();
    return await insert(tabelaInvestimentos, i);
  }

  Future<List<Map<String, dynamic>>> getAllInvestimentos() async =>
      await query(tabelaInvestimentos, orderBy: 'ticker ASC', useCache: true);
  Future<Map<String, dynamic>?> getInvestimentoById(dynamic id) async {
    final r = await query(tabelaInvestimentos,
        where: 'id = ? OR remote_id = ?', whereArgs: [id, id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> updateInvestimento(Map<String, dynamic> i) async {
    final id = i['id'];
    i['ultima_atualizacao'] = _agoraBrasil();
    return await update(tabelaInvestimentos, i, id);
  }

  Future<int> deleteInvestimento(dynamic id) async =>
      await softDelete(tabelaInvestimentos, id);

  Future<int> insertMeta(Map<String, dynamic> m) async =>
      await insert(tabelaMetas, m);
  Future<List<Map<String, dynamic>>> getAllMetas() async =>
      await query(tabelaMetas,
          orderBy: 'concluida ASC, data_fim ASC', useCache: true);
  Future<Map<String, dynamic>?> getMetaById(dynamic id) async {
    final r = await query(tabelaMetas,
        where: 'id = ? OR remote_id = ?', whereArgs: [id, id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> updateMeta(Map<String, dynamic> m) async {
    final id = m['id'];
    return await update(tabelaMetas, m, id);
  }

  Future<int> deleteMeta(dynamic id) async => await softDelete(tabelaMetas, id);

  Future<int> insertDepositoMeta(Map<String, dynamic> d) async =>
      await insert(tabelaDepositosMeta, d);
  Future<List<Map<String, dynamic>>> getDepositosByMetaId(
          dynamic metaId) async =>
      await query(tabelaDepositosMeta,
          where: 'meta_id = ?',
          whereArgs: [metaId],
          orderBy: 'data_deposito DESC',
          useCache: true);
  Future<double> getTotalDepositosByMetaId(dynamic metaId) async {
    final db = await database;
    final r = await db.rawQuery(
        'SELECT SUM(valor) as total FROM depositos_meta WHERE meta_id = ? AND (deleted_at IS NULL)',
        [metaId]).timeout(dbTimeout);
    return (r.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> deleteDeposito(dynamic id) async =>
      await softDelete(tabelaDepositosMeta, id);

  Future<int> insertRendaFixa(Map<String, dynamic> r) async =>
      await insert(tabelaRendaFixa, r);
  Future<List<Map<String, dynamic>>> getAllRendaFixa() async =>
      await query(tabelaRendaFixa,
          orderBy: 'data_aplicacao DESC', useCache: true);
  Future<Map<String, dynamic>?> getRendaFixaById(dynamic id) async {
    final r = await query(tabelaRendaFixa,
        where: 'id = ? OR remote_id = ?', whereArgs: [id, id]);
    return r.isNotEmpty ? r.first : null;
  }

  Future<int> updateRendaFixa(Map<String, dynamic> r) async {
    final id = r['id'];
    return await update(tabelaRendaFixa, r, id);
  }

  Future<int> deleteRendaFixa(dynamic id) async =>
      await softDelete(tabelaRendaFixa, id);

  // ========== CONTAS DO MÊS ==========
  Future<int> adicionarConta(Map<String, dynamic> conta) async {
    final db = await database;
    await _adicionarUserId(conta);
    final existing = await db.query(tabelaContas,
        where: 'nome = ? AND tipo = ? AND user_id = ? AND (deleted_at IS NULL)',
        whereArgs: [
          conta['nome'],
          conta['tipo'],
          conta['user_id']
        ]).timeout(dbTimeout);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return await db.transaction((txn) async {
      final contaId = await txn.insert(tabelaContas, conta);
      await _gerarPagamentosFuturos(txn, contaId, conta);
      _clearTableCache(tabelaPagamentos);
      return contaId;
    }).timeout(dbTimeout);
  }

  Future<int> adicionarContaComUserId(Map<String, dynamic> conta) async {
    final db = await database;
    if (!conta.containsKey('user_id')) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) conta['user_id'] = user.id;
    }
    conta['sync_status'] = 'pending';
    conta['created_at'] = _agoraBrasil();
    conta['updated_at'] = _agoraBrasil();
    conta.remove('deleted_at');
    final existing = await db.query(tabelaContas,
        where: 'nome = ? AND tipo = ? AND user_id = ? AND (deleted_at IS NULL)',
        whereArgs: [
          conta['nome'],
          conta['tipo'],
          conta['user_id']
        ]).timeout(dbTimeout);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return await db.transaction((txn) async {
      final contaId = await txn.insert(tabelaContas, conta);
      await _gerarPagamentosFuturos(txn, contaId, conta);
      _clearTableCache(tabelaPagamentos);
      return contaId;
    }).timeout(dbTimeout);
  }

  Future<void> _gerarPagamentosFuturos(
      Transaction txn, int contaId, Map<String, dynamic> conta) async {
    final existing = await txn.query(tabelaPagamentos,
        where: 'conta_id = ? AND (deleted_at IS NULL)',
        whereArgs: [contaId.toString()]);
    if (existing.isNotEmpty) return;
    final dataInicio = DateTime.parse(conta['data_inicio'] as String);
    final tipo = conta['tipo'] as String;
    final valor = conta['valor'] as double;
    final diaVencimento = conta['dia_vencimento'] as int;
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final limite = tipo == 'parcelada' ? (conta['parcelas_total'] as int) : 60;
    for (int i = 0; i < limite; i++) {
      final mesReferencia =
          DateTime(dataInicio.year, dataInicio.month + i, diaVencimento);
      final anoMes = mesReferencia.year * 100 + mesReferencia.month;
      await txn.insert(tabelaPagamentos, {
        'id': _generateUUID(),
        'conta_id': contaId.toString(),
        'user_id': userId,
        'ano_mes': anoMes,
        'valor': valor,
        'status': StatusPagamento.pendente.index,
        'sync_status': 'pending'
      });
    }
  }

  Future<List<Map<String, dynamic>>> getPagamentosDoMes(int ano, int mes,
      {bool useCache = true}) async {
    final cacheKey = 'pagamentos_${ano}_$mes';

    if (_pendingQueries.contains(cacheKey)) {
      PerformanceService.stop('db_query_pagamentos_mes (cache)');
      LoggerService.info('⏭️ Pagamentos do mês já em andamento: $ano/$mes');
      return [];
    }

    if (useCache &&
        _queryCache.containsKey(cacheKey) &&
        _queryCache[cacheKey]!.isValid) {
      PerformanceService.stop('db_query_pagamentos_mes (cache)');
      return List<Map<String, dynamic>>.from(_queryCache[cacheKey]!.data);
    }

    _pendingQueries.add(cacheKey);
    PerformanceService.start('db_query_pagamentos_mes');

    try {
      final db = await database;
      final anoMes = ano * 100 + mes;
      final resultados = await db.rawQuery(
          'SELECT p.id, p.conta_id, p.ano_mes, p.valor, p.data_pagamento, p.status, p.lancamento_id, c.nome as conta_nome, c.dia_vencimento, c.categoria, c.tipo as conta_tipo, c.parcelas_total, c.parcelas_pagas FROM pagamentos_mensais p INNER JOIN contas c ON p.conta_id = c.id WHERE p.ano_mes = ? AND (p.deleted_at IS NULL) AND (c.deleted_at IS NULL) ORDER BY CASE WHEN p.status = 0 THEN 1 WHEN p.status = 2 THEN 2 ELSE 3 END, c.dia_vencimento ASC LIMIT 500',
          [anoMes]).timeout(dbTimeout);
      if (useCache) {
        _queryCache[cacheKey] = CacheEntry(resultados, DateTime.now());
      }
      PerformanceService.stop('db_query_pagamentos_mes');
      return resultados;
    } finally {
      _pendingQueries.remove(cacheKey);
    }
  }

  Future<bool> pagarConta(dynamic pagamentoId,
      {DateTime? dataPagamento}) async {
    final db = await database;
    final result = await db.transaction((txn) async {
      final pagamento = await txn.query(tabelaPagamentos,
          where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
          whereArgs: [pagamentoId, pagamentoId]);
      if (pagamento.isEmpty) return false;
      final contaId = pagamento.first['conta_id'].toString();
      await txn.update(
          tabelaPagamentos,
          {
            'status': StatusPagamento.pago.index,
            'data_pagamento':
                (dataPagamento ?? DateTime.now()).toIso8601String(),
            'updated_at': _agoraBrasil(),
            'sync_status': 'pending'
          },
          where: 'id = ? OR remote_id = ?',
          whereArgs: [pagamentoId, pagamentoId]);
      final conta = await txn.query(tabelaContas,
          where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
          whereArgs: [contaId, contaId]);
      if (conta.isNotEmpty && conta.first['tipo'] == 'parcelada') {
        final parcelasPagas = (conta.first['parcelas_pagas'] as int? ?? 0) + 1;
        final parcelasTotal = conta.first['parcelas_total'] as int? ?? 0;
        await txn.update(
            tabelaContas,
            {
              'parcelas_pagas': parcelasPagas,
              'ativa': parcelasPagas >= parcelasTotal ? 0 : 1,
              'updated_at': _agoraBrasil(),
              'sync_status': 'pending'
            },
            where: 'id = ? OR remote_id = ?',
            whereArgs: [contaId, contaId]);
      }
      return true;
    }).timeout(dbTimeout);
    _clearTableCache(tabelaPagamentos);
    _clearTableCache(tabelaContas);
    return result;
  }

  Future<Map<String, dynamic>> getResumoContasDoMes(int ano, int mes) async {
    final cacheKey = 'resumo_contas_${ano}_$mes';
    if (_queryCache.containsKey(cacheKey) && _queryCache[cacheKey]!.isValid) {
      return Map<String, dynamic>.from(_queryCache[cacheKey]!.data);
    }
    final pagamentos = await getPagamentosDoMes(ano, mes, useCache: false);
    double totalPendente = 0, totalPago = 0;
    int qtdPendente = 0, qtdPago = 0, qtdAtrasado = 0;
    final hoje = DateTime.now();
    for (var p in pagamentos) {
      final status = p['status'] as int;
      final valor = p['valor'] as double;
      if (status == StatusPagamento.pago.index) {
        totalPago += valor;
        qtdPago++;
      } else if (status == StatusPagamento.pendente.index) {
        totalPendente += valor;
        qtdPendente++;
        final anoMes = p['ano_mes'] as int;
        final dia = p['dia_vencimento'] as int;
        if (DateTime(anoMes ~/ 100, anoMes % 100, dia).isBefore(hoje)) {
          qtdAtrasado++;
        }
      }
    }
    final result = {
      'totalPendente': totalPendente,
      'totalPago': totalPago,
      'qtdPendente': qtdPendente,
      'qtdPago': qtdPago,
      'qtdAtrasado': qtdAtrasado,
      'totalContas': pagamentos.length
    };
    _queryCache[cacheKey] = CacheEntry(result, DateTime.now());
    return result;
  }

  Future<int> deletarConta(dynamic contaId) async {
    final db = await database;
    final result = await db
        .update(
            tabelaContas,
            {
              'deleted_at': _agoraBrasil(),
              'sync_status': 'deleted',
              'updated_at': _agoraBrasil()
            },
            where: 'id = ? OR remote_id = ?',
            whereArgs: [contaId, contaId])
        .timeout(dbTimeout);
    await db
        .update(
            tabelaPagamentos,
            {
              'deleted_at': _agoraBrasil(),
              'sync_status': 'deleted',
              'updated_at': _agoraBrasil()
            },
            where: 'conta_id = ?',
            whereArgs: [contaId.toString()])
        .timeout(dbTimeout);
    _clearTableCache(tabelaContas);
    _clearTableCache(tabelaPagamentos);
    return result;
  }

  // ========== FUNÇÕES DE CÁLCULO ==========
  double calcularRendimentoDiario(double valor, double percentualCDI) {
    const double taxaCDIAnual = 14.65;
    final cdiDiario = pow(1 + (taxaCDIAnual / 100), 1 / 252) - 1;
    return valor * cdiDiario * (percentualCDI / 100);
  }

  int _calcularDiasUteis(DateTime inicio, DateTime fim) {
    int dias = 0;
    DateTime atual = inicio;
    while (atual.isBefore(fim) || atual.isAtSameMomentAs(fim)) {
      if (atual.weekday != DateTime.saturday &&
          atual.weekday != DateTime.sunday) {
        dias++;
      }
      atual = atual.add(const Duration(days: 1));
    }
    return dias;
  }

  DateTime _proximoDiaUtil(DateTime inicio, int dias) {
    DateTime data = inicio.add(Duration(days: dias));
    while (
        data.weekday == DateTime.saturday || data.weekday == DateTime.sunday) {
      data = data.add(const Duration(days: 1));
    }
    return data;
  }

  // ========== MÉTODOS ADICIONAIS ==========
  Future<void> insertLancamentosEmLote(
      List<Map<String, dynamic>> lancamentos) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var l in lancamentos) {
        await _adicionarUserId(l);
        l['created_at'] = _agoraBrasil();
        l['updated_at'] = _agoraBrasil();
        l['sync_status'] = 'pending';
        l.remove('deleted_at');
        await txn.insert(tabelaLancamentos, l);
      }
    }).timeout(dbTimeout);
    _clearTableCache(tabelaLancamentos);
  }

  Future<int> updatePrecoAtual(dynamic id, double preco) async {
    final db = await database;
    final result = await db
        .update(
            tabelaInvestimentos,
            {
              'preco_atual': preco,
              'ultima_atualizacao': _agoraBrasil(),
              'sync_status': 'pending'
            },
            where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
            whereArgs: [id, id])
        .timeout(dbTimeout);
    _clearTableCache(tabelaInvestimentos);
    return result;
  }

  Future<int> atualizarProgressoMeta(dynamic id, double valorAtual) async {
    final db = await database;
    final result = await db
        .update(
            tabelaMetas,
            {
              'valor_atual': valorAtual,
              'updated_at': _agoraBrasil(),
              'sync_status': 'pending'
            },
            where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
            whereArgs: [id, id])
        .timeout(dbTimeout);
    _clearTableCache(tabelaMetas);
    return result;
  }

  Future<int> concluirMeta(dynamic id) async {
    final db = await database;
    final result = await db
        .update(
            tabelaMetas,
            {
              'concluida': 1,
              'updated_at': _agoraBrasil(),
              'sync_status': 'pending'
            },
            where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
            whereArgs: [id, id])
        .timeout(dbTimeout);
    _clearTableCache(tabelaMetas);
    return result;
  }

  void limparCacheCompleto() {
    final tamanhoAnterior = _queryCache.length;
    _queryCache.clear();
    LoggerService.info(
        '🗑️ Cache completamente limpo ($tamanhoAnterior entradas removidas)');
  }

  Future<void> otimizarBanco() async {
    final db = await database;
    await db.execute('PRAGMA optimize');
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    await db.execute('PRAGMA analysis_limit=400');
    await db.execute('PRAGMA automatic_index=TRUE');
    LoggerService.success('✅ Banco de dados otimizado');
  }

  Future<Map<String, dynamic>> getResumoMensalOtimizado(
      int ano, int mes) async {
    final cacheKey = 'resumo_mensal_${ano}_$mes';
    if (_queryCache.containsKey(cacheKey) && _queryCache[cacheKey]!.isValid) {
      return Map<String, dynamic>.from(_queryCache[cacheKey]!.data);
    }
    final db = await database;
    final startDate = DateTime(ano, mes, 1);
    final endDate = DateTime(ano, mes + 1, 0);
    final result = await db.rawQuery(
        'SELECT COALESCE(SUM(CASE WHEN tipo = \'receita\' THEN valor ELSE 0 END), 0) as total_receitas, COALESCE(SUM(CASE WHEN tipo = \'gasto\' THEN valor ELSE 0 END), 0) as total_gastos, COALESCE(SUM(CASE WHEN tipo = \'investimento\' THEN valor ELSE 0 END), 0) as total_investimentos, COUNT(CASE WHEN tipo = \'receita\' THEN 1 END) as qtd_receitas, COUNT(CASE WHEN tipo = \'gasto\' THEN 1 END) as qtd_gastos, COUNT(CASE WHEN tipo = \'investimento\' THEN 1 END) as qtd_investimentos FROM lancamentos WHERE data BETWEEN ? AND ? AND (deleted_at IS NULL)',
        [
          startDate.toIso8601String(),
          endDate.toIso8601String()
        ]).timeout(dbTimeout);
    final resumo = result.first;
    final topCategorias = await db.rawQuery(
        'SELECT categoria, SUM(valor) as total FROM lancamentos WHERE data BETWEEN ? AND ? AND tipo = \'gasto\' AND (deleted_at IS NULL) GROUP BY categoria ORDER BY total DESC LIMIT 5',
        [
          startDate.toIso8601String(),
          endDate.toIso8601String()
        ]).timeout(dbTimeout);
    final resultMap = {
      'totalReceitas': (resumo['total_receitas'] as num?)?.toDouble() ?? 0,
      'totalGastos': (resumo['total_gastos'] as num?)?.toDouble() ?? 0,
      'totalInvestimentos':
          (resumo['total_investimentos'] as num?)?.toDouble() ?? 0,
      'saldo': ((resumo['total_receitas'] as num?)?.toDouble() ?? 0) -
          ((resumo['total_gastos'] as num?)?.toDouble() ?? 0) -
          ((resumo['total_investimentos'] as num?)?.toDouble() ?? 0),
      'qtdReceitas': (resumo['qtd_receitas'] as num?)?.toInt() ?? 0,
      'qtdGastos': (resumo['qtd_gastos'] as num?)?.toInt() ?? 0,
      'qtdInvestimentos': (resumo['qtd_investimentos'] as num?)?.toInt() ?? 0,
      'topCategorias': topCategorias
          .map((e) => {
                'categoria': e['categoria'],
                'total': (e['total'] as num?)?.toDouble() ?? 0
              })
          .toList()
    };
    _queryCache[cacheKey] = CacheEntry(resultMap, DateTime.now());
    return resultMap;
  }

  Future<List<Map<String, dynamic>>> getLancamentosPaginados(
      {required int pagina,
      int porPagina = 20,
      String? tipo,
      String? categoria,
      DateTime? dataInicio,
      DateTime? dataFim,
      OrdemLancamento ordem = OrdemLancamento.dataDesc,
      bool useCache = true}) async {
    final db = await database;
    String where = '(deleted_at IS NULL)';
    List<dynamic> whereArgs = [];
    if (tipo != null && tipo != 'Todos') {
      where += ' AND tipo = ?';
      whereArgs.add(tipo);
    }
    if (categoria != null && categoria != 'Todas') {
      where += ' AND categoria = ?';
      whereArgs.add(categoria);
    }
    if (dataInicio != null) {
      where += ' AND date(data) >= date(?)';
      whereArgs.add(dataInicio.toIso8601String());
    }
    if (dataFim != null) {
      where += ' AND date(data) <= date(?)';
      whereArgs.add(dataFim.toIso8601String());
    }
    String orderBy;
    switch (ordem) {
      case OrdemLancamento.dataDesc:
        orderBy = 'data DESC, id DESC';
        break;
      case OrdemLancamento.dataAsc:
        orderBy = 'data ASC, id ASC';
        break;
      case OrdemLancamento.valorDesc:
        orderBy = 'valor DESC, data DESC';
        break;
      case OrdemLancamento.valorAsc:
        orderBy = 'valor ASC, data ASC';
        break;
    }
    final offset = (pagina - 1) * porPagina;
    final cacheKey =
        'lancamentos_paginados_${pagina}_${tipo}_${categoria}_${dataInicio}_${dataFim}_$ordem';
    if (useCache &&
        _queryCache.containsKey(cacheKey) &&
        _queryCache[cacheKey]!.isValid) {
      return List<Map<String, dynamic>>.from(_queryCache[cacheKey]!.data);
    }
    final result = await db
        .query(tabelaLancamentos,
            where: where,
            whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
            orderBy: orderBy,
            limit: porPagina,
            offset: offset)
        .timeout(dbTimeout);
    if (useCache) _queryCache[cacheKey] = CacheEntry(result, DateTime.now());
    return result;
  }

  Future<List<Map<String, dynamic>>> getProventosFuturos() async {
    final db = await database;
    return await db
        .query(tabelaProventos,
            where: 'data_pagamento > ? AND (deleted_at IS NULL)',
            whereArgs: [DateTime.now().toIso8601String()],
            orderBy: 'data_pagamento ASC')
        .timeout(dbTimeout);
  }

  Future<double> getTotalProventosMes({int? mes, int? ano}) async {
    final agora = DateTime.now();
    final mesAlvo = mes ?? agora.month;
    final anoAlvo = ano ?? agora.year;
    final db = await database;
    final results = await db.query(tabelaProventos,
        where:
            'date(data_pagamento) BETWEEN date(?) AND date(?) AND (deleted_at IS NULL)',
        whereArgs: [
          DateTime(anoAlvo, mesAlvo, 1).toIso8601String(),
          DateTime(anoAlvo, mesAlvo + 1, 0).toIso8601String()
        ]).timeout(dbTimeout);
    return results.fold<double>(
        0,
        (sum, item) =>
            sum + ((item['total_recebido'] as num?)?.toDouble() ?? 0));
  }

  Future<void> updateInvestimentosEmLote(
      List<Map<String, dynamic>> investimentos) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var item in investimentos) {
        final id = item['id'];
        item.remove('id');
        item['updated_at'] = _agoraBrasil();
        item['sync_status'] = 'pending';
        item.remove('deleted_at');
        await txn.update(tabelaInvestimentos, item,
            where: 'id = ? OR remote_id = ?', whereArgs: [id, id]);
      }
    }).timeout(dbTimeout);
    _clearTableCache(tabelaInvestimentos);
  }

  Future<void> deleteEmLote(String table, List<dynamic> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.execute(
        'UPDATE $table SET deleted_at = ?, sync_status = "deleted", updated_at = ? WHERE id IN ($placeholders) OR remote_id IN ($placeholders)',
        [_agoraBrasil(), _agoraBrasil(), ...ids, ...ids]);
    _clearTableCache(table);
  }

  Future<Map<String, dynamic>> validarIntegridade() async {
    final db = await database;
    final resultados = <String, dynamic>{
      'valido': true,
      'erros': <String>[],
      'tabelas': <String, int>{}
    };
    try {
      final tabelas = [
        tabelaLancamentos,
        tabelaMetas,
        tabelaDepositosMeta,
        tabelaInvestimentos,
        tabelaProventos,
        tabelaRendaFixa,
        tabelaContas,
        tabelaPagamentos
      ];
      for (final t in tabelas) {
        try {
          final r = await db
              .rawQuery(
                  'SELECT COUNT(*) as total FROM $t WHERE (deleted_at IS NULL)')
              .timeout(dbTimeout);
          resultados['tabelas'][t] = (r.first['total'] as int?) ?? 0;
        } catch (e) {
          resultados['valido'] = false;
          resultados['erros'].add('Erro na tabela $t: $e');
        }
      }
    } catch (e) {
      resultados['valido'] = false;
      resultados['erros'].add('Erro geral: $e');
    }
    return resultados;
  }

  Future<Map<String, dynamic>> getEstatisticasBanco() async {
    final db = await database;
    final tamanhoQuery = await db
        .rawQuery(
            'SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()')
        .timeout(dbTimeout);
    final tabelasInfo = <String, int>{};
    for (var t in [
      tabelaLancamentos,
      tabelaMetas,
      tabelaInvestimentos,
      tabelaProventos,
      tabelaRendaFixa,
      tabelaContas,
      tabelaPagamentos
    ]) {
      final c = await db
          .rawQuery(
              'SELECT COUNT(*) as total FROM $t WHERE (deleted_at IS NULL)')
          .timeout(dbTimeout);
      tabelasInfo[t] = (c.first['total'] as int?) ?? 0;
    }
    return {
      'tamanhoBytes': tamanhoQuery.first['size'] ?? 0,
      'tamanhoMB':
          ((tamanhoQuery.first['size'] as num?)?.toDouble() ?? 0) / 1024 / 1024,
      'cacheEntries': _queryCache.length,
      'tabelas': tabelasInfo
    };
  }
}
