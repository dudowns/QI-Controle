import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../services/performance_service.dart';
import '../utils/date_helper.dart';
import '../services/logger_service.dart';

// ========== ENUM PARA STATUS DE PAGAMENTO ==========
enum StatusPagamento {
  pendente,
  pago,
  atrasado,
}

// ========== CLASSE DE CACHE ==========
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);

  bool get isValid =>
      DateTime.now().difference(timestamp) < DBHelper.cacheValidity;
}

// ========== ENUM PARA ORDENAÇÃO ==========
enum OrdemLancamento {
  dataDesc,
  dataAsc,
  valorDesc,
  valorAsc,
}

// ========== DBHELPER PRINCIPAL ==========
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  // Cache para consultas frequentes
  static final Map<String, CacheEntry> _queryCache = {};

  static const Duration cacheValidity = Duration(minutes: 5);

  // Constantes para nomes de tabelas
  static const String tabelaLancamentos = 'lancamentos';
  static const String tabelaMetas = 'metas';
  static const String tabelaDepositosMeta = 'depositos_meta';
  static const String tabelaInvestimentos = 'investimentos';
  static const String tabelaProventos = 'proventos';
  static const String tabelaRendaFixa = 'renda_fixa';
  static const String tabelaContas = 'contas';
  static const String tabelaPagamentos = 'pagamentos_mensais';
  static const String tabelaContasFixas = 'contas_fixas';
  static const String tabelaParcelas = 'parcelas';

  Future<Database> get database async {
    if (_database != null) return _database!;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final appDir = await getApplicationSupportDirectory();
    final path = join(appDir.path, 'financeiro.db');

    LoggerService.info('📁 Banco de dados em: $path');

    return await openDatabase(
      path,
      version: 24, // 🔥 ATUALIZADO PARA VERSÃO 24
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    LoggerService.info('🔨 Criando tabelas versão $version');

    // Tabela de lançamentos (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaLancamentos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        valor REAL NOT NULL,
        descricao TEXT NOT NULL,
        tipo TEXT NOT NULL,
        categoria TEXT NOT NULL,
        data TEXT NOT NULL,
        observacao TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de metas (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaMetas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        titulo TEXT NOT NULL,
        descricao TEXT,
        valor_objetivo REAL NOT NULL,
        valor_atual REAL DEFAULT 0,
        data_inicio TEXT NOT NULL,
        data_fim TEXT NOT NULL,
        cor TEXT,
        icone TEXT,
        concluida INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de depósitos de metas
    await db.execute('''
      CREATE TABLE $tabelaDepositosMeta(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        meta_id INTEGER NOT NULL,
        valor REAL NOT NULL,
        data_deposito TEXT NOT NULL,
        observacao TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (meta_id) REFERENCES $tabelaMetas(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de investimentos (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaInvestimentos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        ticker TEXT NOT NULL,
        tipo TEXT NOT NULL,
        quantidade REAL NOT NULL,
        preco_medio REAL NOT NULL,
        preco_atual REAL,
        data_compra TEXT,
        corretora TEXT,
        setor TEXT,
        dividend_yield REAL,
        ultima_atualizacao TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de proventos (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaProventos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        ticker TEXT NOT NULL,
        tipo_provento TEXT,
        valor_por_cota REAL NOT NULL,
        quantidade REAL DEFAULT 1,
        data_pagamento TEXT NOT NULL,
        data_com TEXT,
        total_recebido REAL,
        sync_automatico INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de renda fixa (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaRendaFixa(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        nome TEXT NOT NULL,
        tipo_renda TEXT NOT NULL,
        valor REAL NOT NULL,
        taxa REAL NOT NULL,
        data_aplicacao TEXT NOT NULL,
        data_vencimento TEXT NOT NULL,
        dias INTEGER NOT NULL,
        rendimento_bruto REAL,
        iof REAL,
        ir REAL,
        rendimento_liquido REAL,
        valor_final REAL,
        indexador TEXT,
        liquidez TEXT DEFAULT 'Diária',
        is_lci INTEGER DEFAULT 0,
        status TEXT DEFAULT 'ativo',
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de contas (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaContas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        nome TEXT NOT NULL,
        valor REAL NOT NULL,
        dia_vencimento INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        categoria TEXT,
        ativa INTEGER DEFAULT 1,
        parcelas_total INTEGER,
        parcelas_pagas INTEGER DEFAULT 0,
        data_inicio TEXT,
        data_fim TEXT,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Tabela de pagamentos mensais (COM CAMPOS DE SINCRONIZAÇÃO)
    await db.execute('''
      CREATE TABLE $tabelaPagamentos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        remote_id TEXT,
        user_id TEXT,
        conta_id INTEGER NOT NULL,
        ano_mes INTEGER NOT NULL,
        valor REAL NOT NULL,
        data_pagamento TEXT,
        status INTEGER NOT NULL,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (conta_id) REFERENCES $tabelaContas(id) ON DELETE CASCADE
      )
    ''');

    // Tabelas antigas (mantidas por compatibilidade)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tabelaContasFixas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        valor_total REAL NOT NULL,
        total_parcelas INTEGER NOT NULL,
        data_inicio TEXT NOT NULL,
        categoria TEXT,
        observacao TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tabelaParcelas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conta_id INTEGER NOT NULL,
        numero INTEGER NOT NULL,
        data_vencimento TEXT NOT NULL,
        status INTEGER NOT NULL,
        data_pagamento TEXT,
        valor_pago REAL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (conta_id) REFERENCES $tabelaContasFixas(id) ON DELETE CASCADE
      )
    ''');

    // Tabela de logs de integridade
    await db.execute('''
      CREATE TABLE IF NOT EXISTS integridade_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        mensagem TEXT NOT NULL,
        detalhes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await _criarIndices(db);
    LoggerService.success('✅ Tabelas criadas com sucesso!');
  }

  Future<void> _criarIndices(Database db) async {
    final indicesExistentes =
        await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index'");

    final nomesIndices =
        indicesExistentes.map((e) => e['name'] as String).toList();

    // Índices existentes
    if (!nomesIndices.contains('idx_lancamentos_data')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_data ON $tabelaLancamentos(data)');
    }
    if (!nomesIndices.contains('idx_lancamentos_tipo')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_tipo ON $tabelaLancamentos(tipo)');
    }
    if (!nomesIndices.contains('idx_lancamentos_categoria')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_categoria ON $tabelaLancamentos(categoria)');
    }
    if (!nomesIndices.contains('idx_lancamentos_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_lancamentos_sync_status ON $tabelaLancamentos(sync_status)');
    }
    if (!nomesIndices.contains('idx_metas_concluida')) {
      await db.execute(
          'CREATE INDEX idx_metas_concluida ON $tabelaMetas(concluida)');
    }
    if (!nomesIndices.contains('idx_metas_data_fim')) {
      await db
          .execute('CREATE INDEX idx_metas_data_fim ON $tabelaMetas(data_fim)');
    }
    if (!nomesIndices.contains('idx_metas_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_metas_sync_status ON $tabelaMetas(sync_status)');
    }
    if (!nomesIndices.contains('idx_investimentos_ticker')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_ticker ON $tabelaInvestimentos(ticker)');
    }
    if (!nomesIndices.contains('idx_investimentos_tipo')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_tipo ON $tabelaInvestimentos(tipo)');
    }
    if (!nomesIndices.contains('idx_investimentos_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_investimentos_sync_status ON $tabelaInvestimentos(sync_status)');
    }
    if (!nomesIndices.contains('idx_proventos_data_pagamento')) {
      await db.execute(
          'CREATE INDEX idx_proventos_data_pagamento ON $tabelaProventos(data_pagamento)');
    }
    if (!nomesIndices.contains('idx_proventos_ticker')) {
      await db.execute(
          'CREATE INDEX idx_proventos_ticker ON $tabelaProventos(ticker)');
    }
    if (!nomesIndices.contains('idx_proventos_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_proventos_sync_status ON $tabelaProventos(sync_status)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_vencimento')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_vencimento ON $tabelaRendaFixa(data_vencimento)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_status')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_status ON $tabelaRendaFixa(status)');
    }
    if (!nomesIndices.contains('idx_renda_fixa_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_renda_fixa_sync_status ON $tabelaRendaFixa(sync_status)');
    }
    if (!nomesIndices.contains('idx_pagamentos_conta')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_conta ON $tabelaPagamentos(conta_id)');
    }
    if (!nomesIndices.contains('idx_pagamentos_mes')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_mes ON $tabelaPagamentos(ano_mes)');
    }
    if (!nomesIndices.contains('idx_pagamentos_status')) {
      await db.execute(
          'CREATE INDEX idx_pagamentos_status ON $tabelaPagamentos(status)');
    }
    if (!nomesIndices.contains('idx_contas_ativa')) {
      await db.execute('CREATE INDEX idx_contas_ativa ON $tabelaContas(ativa)');
    }
    if (!nomesIndices.contains('idx_contas_sync_status')) {
      await db.execute(
          'CREATE INDEX idx_contas_sync_status ON $tabelaContas(sync_status)');
    }

    // Índices antigos (mantidos)
    if (!nomesIndices.contains('idx_contas_fixas_data_inicio')) {
      await db.execute(
          'CREATE INDEX idx_contas_fixas_data_inicio ON $tabelaContasFixas(data_inicio)');
    }
    if (!nomesIndices.contains('idx_parcelas_conta_id')) {
      await db.execute(
          'CREATE INDEX idx_parcelas_conta_id ON $tabelaParcelas(conta_id)');
    }
    if (!nomesIndices.contains('idx_parcelas_status')) {
      await db.execute(
          'CREATE INDEX idx_parcelas_status ON $tabelaParcelas(status)');
    }
    if (!nomesIndices.contains('idx_parcelas_data_vencimento')) {
      await db.execute(
          'CREATE INDEX idx_parcelas_data_vencimento ON $tabelaParcelas(data_vencimento)');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    LoggerService.info('🔄 Atualizando banco: $oldVersion -> $newVersion');

    if (oldVersion < 17) {
      LoggerService.info('🔧 Recriando tabela proventos...');

      List<Map<String, dynamic>> proventosExistentes = [];
      try {
        proventosExistentes = await db.query('proventos');
      } catch (e) {
        LoggerService.warning('⚠️ Erro ao fazer backup: $e');
      }

      await db.execute('DROP TABLE IF EXISTS proventos');
      await db.execute('''
        CREATE TABLE proventos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ticker TEXT NOT NULL,
          tipo_provento TEXT,
          valor_por_cota REAL NOT NULL,
          quantidade REAL DEFAULT 1,
          data_pagamento TEXT NOT NULL,
          data_com TEXT,
          total_recebido REAL,
          sync_automatico INTEGER DEFAULT 0,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      for (var p in proventosExistentes) {
        try {
          p.remove('id');
          p.remove('created_at');
          p.remove('updated_at');
          await db.insert('proventos', p);
        } catch (e) {
          LoggerService.error('❌ Erro ao restaurar provento', e);
        }
      }
    }

    if (oldVersion < 18) {
      await db.execute('DROP INDEX IF EXISTS idx_lancamentos_data');
      await db.execute('DROP INDEX IF EXISTS idx_lancamentos_tipo');
      await db.execute('DROP INDEX IF EXISTS idx_lancamentos_categoria');
      await db.execute('DROP INDEX IF EXISTS idx_metas_concluida');
      await db.execute('DROP INDEX IF EXISTS idx_metas_data_fim');
      await db.execute('DROP INDEX IF EXISTS idx_investimentos_ticker');
      await db.execute('DROP INDEX IF EXISTS idx_investimentos_tipo');
      await db.execute('DROP INDEX IF EXISTS idx_proventos_data_pagamento');
      await db.execute('DROP INDEX IF EXISTS idx_proventos_ticker');
      await db.execute('DROP INDEX IF EXISTS idx_renda_fixa_vencimento');
      await db.execute('DROP INDEX IF EXISTS idx_renda_fixa_status');

      await _criarIndices(db);
    }

    if (oldVersion < 19) {
      final tableInfo = await db.rawQuery('PRAGMA table_info(renda_fixa)');
      final colunas = tableInfo.map((c) => c['name'] as String).toList();

      if (!colunas.contains('tipo_renda')) {
        await db.execute('ALTER TABLE renda_fixa ADD COLUMN tipo_renda TEXT');
      }
      if (!colunas.contains('indexador')) {
        await db.execute('ALTER TABLE renda_fixa ADD COLUMN indexador TEXT');
      }
      if (!colunas.contains('liquidez')) {
        await db.execute(
            'ALTER TABLE renda_fixa ADD COLUMN liquidez TEXT DEFAULT "Diária"');
      }
      if (!colunas.contains('is_lci')) {
        await db.execute(
            'ALTER TABLE renda_fixa ADD COLUMN is_lci INTEGER DEFAULT 0');
      }
    }

    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS contas_fixas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          valor_total REAL NOT NULL,
          total_parcelas INTEGER NOT NULL,
          data_inicio TEXT NOT NULL,
          categoria TEXT,
          observacao TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS parcelas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conta_id INTEGER NOT NULL,
          numero INTEGER NOT NULL,
          data_vencimento TEXT NOT NULL,
          status INTEGER NOT NULL,
          data_pagamento TEXT,
          valor_pago REAL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (conta_id) REFERENCES contas_fixas(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 21) {
      await _criarIndices(db);
    }

    if (oldVersion < 22) {
      LoggerService.info('🔧 Criando novas tabelas de contas do mês...');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tabelaContas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          valor REAL NOT NULL,
          dia_vencimento INTEGER NOT NULL,
          tipo TEXT NOT NULL,
          categoria TEXT,
          ativa INTEGER DEFAULT 1,
          parcelas_total INTEGER,
          parcelas_pagas INTEGER DEFAULT 0,
          data_inicio TEXT,
          data_fim TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tabelaPagamentos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conta_id INTEGER NOT NULL,
          ano_mes INTEGER NOT NULL,
          valor REAL NOT NULL,
          data_pagamento TEXT,
          status INTEGER NOT NULL,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (conta_id) REFERENCES $tabelaContas(id) ON DELETE CASCADE
        )
      ''');

      await _criarIndices(db);
    }

    if (oldVersion < 23) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS integridade_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            mensagem TEXT NOT NULL,
            detalhes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        LoggerService.success('✅ Tabela integridade_logs criada');
      } catch (e) {
        LoggerService.error('❌ Erro ao criar integridade_logs', e);
      }
    }

    // 🔥 NOVA MIGRAÇÃO PARA VERSÃO 24 - CAMPOS DE SINCRONIZAÇÃO
    if (oldVersion < 24) {
      LoggerService.info(
          '🔧 Adicionando campos de sincronização (versão 24)...');

      final tabelas = [
        tabelaLancamentos,
        tabelaMetas,
        tabelaDepositosMeta,
        tabelaInvestimentos,
        tabelaProventos,
        tabelaRendaFixa,
        tabelaContas,
        tabelaPagamentos,
      ];

      for (var tabela in tabelas) {
        try {
          final tableInfo = await db.rawQuery('PRAGMA table_info($tabela)');
          final colunas = tableInfo.map((c) => c['name'] as String).toList();

          if (!colunas.contains('remote_id')) {
            await db.execute('ALTER TABLE $tabela ADD COLUMN remote_id TEXT');
            LoggerService.info('  ✅ Adicionado remote_id em $tabela');
          }

          if (!colunas.contains('user_id')) {
            await db.execute('ALTER TABLE $tabela ADD COLUMN user_id TEXT');
            LoggerService.info('  ✅ Adicionado user_id em $tabela');
          }

          if (!colunas.contains('sync_status')) {
            await db.execute(
                'ALTER TABLE $tabela ADD COLUMN sync_status TEXT DEFAULT "synced"');
            LoggerService.info('  ✅ Adicionado sync_status em $tabela');
          } else {
            await db.execute(
                'UPDATE $tabela SET sync_status = "synced" WHERE sync_status IS NULL');
          }
        } catch (e) {
          LoggerService.warning('⚠️ Erro ao migrar tabela $tabela: $e');
        }
      }

      // Adicionar índices de sync_status
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_lancamentos_sync_status ON $tabelaLancamentos(sync_status)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_metas_sync_status ON $tabelaMetas(sync_status)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_investimentos_sync_status ON $tabelaInvestimentos(sync_status)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_proventos_sync_status ON $tabelaProventos(sync_status)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_renda_fixa_sync_status ON $tabelaRendaFixa(sync_status)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_contas_sync_status ON $tabelaContas(sync_status)');
        LoggerService.success('✅ Índices de sincronização criados');
      } catch (e) {
        LoggerService.warning('⚠️ Erro ao criar índices: $e');
      }

      LoggerService.success('✅ Migração para versão 24 concluída!');
    }

    await _criarIndices(db);
  }

  // ========== MÉTODOS GENÉRICOS ==========

  void _clearTableCache(String table) {
    _queryCache.removeWhere((key, _) => key.startsWith('${table}_'));
  }

  void _clearQueryCache() {
    _queryCache.clear();
  }

  String _agoraBrasil() {
    return DateHelper.agoraBrasilia().toIso8601String();
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    PerformanceService.start('db_insert_$table');

    final db = await database;
    try {
      data['created_at'] = _agoraBrasil();
      data['updated_at'] = _agoraBrasil();

      final result = await db.insert(table, data);

      _clearTableCache(table);
      LoggerService.info('Insert em $table');

      PerformanceService.stop('db_insert_$table');
      return result;
    } catch (e) {
      LoggerService.error('Erro ao inserir em $table', e);
      rethrow;
    }
  }

  Future<int> update(String table, Map<String, dynamic> data, int id) async {
    PerformanceService.start('db_update_$table');

    final db = await database;
    try {
      data['updated_at'] = _agoraBrasil();

      final result = await db.update(
        table,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      _clearTableCache(table);
      _clearQueryCache();

      PerformanceService.stop('db_update_$table');
      return result;
    } catch (e) {
      LoggerService.error('Erro ao atualizar $table', e);
      rethrow;
    }
  }

  Future<int> delete(String table, int id) async {
    PerformanceService.start('db_delete_$table');

    final db = await database;
    try {
      final result = await db.delete(
        table,
        where: 'id = ?',
        whereArgs: [id],
      );

      _clearTableCache(table);
      _clearQueryCache();

      PerformanceService.stop('db_delete_$table');
      return result;
    } catch (e) {
      LoggerService.error('Erro ao deletar em $table', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    bool useCache = true,
  }) async {
    PerformanceService.start('db_query_$table');

    final cacheKey = '${table}_${where}_${orderBy}_${limit}_$offset';

    if (useCache &&
        _queryCache.containsKey(cacheKey) &&
        _queryCache[cacheKey]!.isValid) {
      PerformanceService.stop('db_query_$table (cache)');
      return List<Map<String, dynamic>>.from(_queryCache[cacheKey]!.data);
    }

    final db = await database;
    final result = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    if (useCache) {
      _queryCache[cacheKey] = CacheEntry(result, DateTime.now());
    }

    PerformanceService.stop('db_query_$table');
    return result;
  }

  // ========== MÉTODOS DE LANÇAMENTOS ==========

  Future<int> insertLancamento(Map<String, dynamic> lancamento) async {
    return await insert(tabelaLancamentos, lancamento);
  }

  Future<List<Map<String, dynamic>>> getAllLancamentos() async {
    return await query(
      tabelaLancamentos,
      orderBy: 'data DESC, id DESC',
      useCache: true,
    );
  }

  Future<Map<String, dynamic>?> getLancamentoById(int id) async {
    final results = await query(
      tabelaLancamentos,
      where: 'id = ?',
      whereArgs: [id],
      useCache: true,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateLancamento(Map<String, dynamic> lancamento) async {
    final id = lancamento['id'];
    lancamento.remove('id');
    return await update(tabelaLancamentos, lancamento, id);
  }

  Future<int> deleteLancamento(int id) async {
    return await delete(tabelaLancamentos, id);
  }

  // ========== MÉTODOS DE PROVENTOS ==========

  Future<int> insertProvento(Map<String, dynamic> provento) async {
    if (provento['total_recebido'] == null) {
      final quantidade = (provento['quantidade'] as num?)?.toDouble() ?? 1;
      final valorPorCota = (provento['valor_por_cota'] as num).toDouble();
      provento['total_recebido'] = quantidade * valorPorCota;
    }

    if (provento['ticker'] != null) {
      provento['ticker'] = provento['ticker'].toString().toUpperCase();
    }

    final db = await database;
    try {
      final id = await db.insert(tabelaProventos, provento);

      _clearTableCache(tabelaProventos);
      return id;
    } catch (e) {
      LoggerService.error('Erro ao inserir provento', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllProventos() async {
    return await query(
      tabelaProventos,
      orderBy: 'data_pagamento DESC',
      useCache: true,
    );
  }

  Future<int> updateProvento(Map<String, dynamic> provento) async {
    final id = provento['id'];
    provento.remove('id');

    if (provento['ticker'] != null) {
      provento['ticker'] = provento['ticker'].toString().toUpperCase();
    }

    final db = await database;
    try {
      final result = await db.update(
        tabelaProventos,
        provento,
        where: 'id = ?',
        whereArgs: [id],
      );

      _clearTableCache(tabelaProventos);
      return result;
    } catch (e) {
      LoggerService.error('Erro ao atualizar provento', e);
      rethrow;
    }
  }

  Future<int> deleteProvento(int id) async {
    return await delete(tabelaProventos, id);
  }

  // ========== MÉTODOS DE INVESTIMENTOS ==========

  Future<int> insertInvestimento(Map<String, dynamic> investimento) async {
    investimento['ultima_atualizacao'] = _agoraBrasil();
    return await insert(tabelaInvestimentos, investimento);
  }

  Future<List<Map<String, dynamic>>> getAllInvestimentos() async {
    return await query(
      tabelaInvestimentos,
      orderBy: 'ticker ASC',
      useCache: true,
    );
  }

  Future<Map<String, dynamic>?> getInvestimentoById(int id) async {
    final results = await query(
      tabelaInvestimentos,
      where: 'id = ?',
      whereArgs: [id],
      useCache: true,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateInvestimento(Map<String, dynamic> investimento) async {
    final id = investimento['id'];
    investimento.remove('id');
    investimento['ultima_atualizacao'] = _agoraBrasil();
    return await update(tabelaInvestimentos, investimento, id);
  }

  Future<int> deleteInvestimento(int id) async {
    return await delete(tabelaInvestimentos, id);
  }

  // ========== MÉTODOS DE METAS ==========

  Future<int> insertMeta(Map<String, dynamic> meta) async {
    return await insert(tabelaMetas, meta);
  }

  Future<List<Map<String, dynamic>>> getAllMetas() async {
    return await query(
      tabelaMetas,
      orderBy: 'concluida ASC, data_fim ASC',
      useCache: true,
    );
  }

  Future<Map<String, dynamic>?> getMetaById(int id) async {
    final results = await query(
      tabelaMetas,
      where: 'id = ?',
      whereArgs: [id],
      useCache: true,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateMeta(Map<String, dynamic> meta) async {
    final id = meta['id'];
    meta.remove('id');
    return await update(tabelaMetas, meta, id);
  }

  Future<int> deleteMeta(int id) async {
    return await delete(tabelaMetas, id);
  }

  // ========== MÉTODOS DE DEPÓSITOS DE METAS ==========

  Future<int> insertDepositoMeta(Map<String, dynamic> deposito) async {
    return await insert(tabelaDepositosMeta, deposito);
  }

  Future<List<Map<String, dynamic>>> getDepositosByMetaId(int metaId) async {
    return await query(
      tabelaDepositosMeta,
      where: 'meta_id = ?',
      whereArgs: [metaId],
      orderBy: 'data_deposito DESC',
      useCache: true,
    );
  }

  Future<double> getTotalDepositosByMetaId(int metaId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(valor) as total FROM $tabelaDepositosMeta WHERE meta_id = ?',
      [metaId],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> deleteDeposito(int id) async {
    return await delete(tabelaDepositosMeta, id);
  }

  // ========== MÉTODOS DE RENDA FIXA ==========

  Future<int> insertRendaFixa(Map<String, dynamic> renda) async {
    return await insert(tabelaRendaFixa, renda);
  }

  Future<List<Map<String, dynamic>>> getAllRendaFixa() async {
    return await query(
      tabelaRendaFixa,
      orderBy: 'data_aplicacao DESC',
      useCache: true,
    );
  }

  Future<Map<String, dynamic>?> getRendaFixaById(int id) async {
    final results = await query(
      tabelaRendaFixa,
      where: 'id = ?',
      whereArgs: [id],
      useCache: true,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateRendaFixa(Map<String, dynamic> renda) async {
    final id = renda['id'];
    renda.remove('id');
    return await update(tabelaRendaFixa, renda, id);
  }

  Future<int> deleteRendaFixa(int id) async {
    return await delete(tabelaRendaFixa, id);
  }

  // ========== MÉTODOS PARA CONTAS DO MÊS ==========

  Future<int> adicionarConta(Map<String, dynamic> conta) async {
    final db = await database;

    return await db.transaction((txn) async {
      final contaId = await txn.insert(tabelaContas, conta);
      await _gerarPagamentosFuturos(txn, contaId, conta);
      return contaId;
    });
  }

  Future<void> _gerarPagamentosFuturos(
      Transaction txn, int contaId, Map<String, dynamic> conta) async {
    final dataInicio = DateTime.parse(conta['data_inicio'] as String);
    final tipo = conta['tipo'] as String;
    final valor = conta['valor'] as double;
    final diaVencimento = conta['dia_vencimento'] as int;

    if (tipo == 'parcelada') {
      final parcelasTotal = conta['parcelas_total'] as int;

      for (int i = 0; i < parcelasTotal; i++) {
        final mesReferencia = DateTime(
          dataInicio.year,
          dataInicio.month + i,
          diaVencimento,
        );
        final anoMes = mesReferencia.year * 100 + mesReferencia.month;

        await txn.insert(tabelaPagamentos, {
          'conta_id': contaId,
          'ano_mes': anoMes,
          'valor': valor,
          'status': StatusPagamento.pendente.index,
        });
      }
    } else {
      for (int i = 0; i < 60; i++) {
        final mesReferencia = DateTime(
          dataInicio.year,
          dataInicio.month + i,
          diaVencimento,
        );
        final anoMes = mesReferencia.year * 100 + mesReferencia.month;

        await txn.insert(tabelaPagamentos, {
          'conta_id': contaId,
          'ano_mes': anoMes,
          'valor': valor,
          'status': StatusPagamento.pendente.index,
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPagamentosDoMes(
      int ano, int mes) async {
    final db = await database;
    final anoMes = ano * 100 + mes;

    final resultados = await db.rawQuery('''
      SELECT 
        p.*,
        c.nome as conta_nome,
        c.dia_vencimento,
        c.categoria
      FROM $tabelaPagamentos p
      INNER JOIN $tabelaContas c ON p.conta_id = c.id
      WHERE p.ano_mes = ?
      ORDER BY 
        CASE 
          WHEN p.status = 0 THEN 1
          WHEN p.status = 2 THEN 2
          ELSE 3
        END,
        c.dia_vencimento ASC
    ''', [anoMes]);

    return resultados;
  }

  Future<bool> pagarConta(int pagamentoId, {DateTime? dataPagamento}) async {
    final db = await database;

    return await db.transaction((txn) async {
      final pagamento = await txn.query(
        tabelaPagamentos,
        where: 'id = ?',
        whereArgs: [pagamentoId],
      );

      if (pagamento.isEmpty) return false;

      final pagamentoJson = pagamento.first;
      final contaId = pagamentoJson['conta_id'] as int;

      await txn.update(
        tabelaPagamentos,
        {
          'status': StatusPagamento.pago.index,
          'data_pagamento': (dataPagamento ?? DateTime.now()).toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [pagamentoId],
      );

      final conta = await txn.query(
        tabelaContas,
        where: 'id = ?',
        whereArgs: [contaId],
      );

      if (conta.isNotEmpty) {
        final contaJson = conta.first;
        if (contaJson['tipo'] == 'parcelada') {
          final parcelasPagas = (contaJson['parcelas_pagas'] as int? ?? 0) + 1;
          final parcelasTotal = contaJson['parcelas_total'] as int? ?? 0;

          await txn.update(
            tabelaContas,
            {
              'parcelas_pagas': parcelasPagas,
              'ativa': parcelasPagas >= parcelasTotal ? 0 : 1,
            },
            where: 'id = ?',
            whereArgs: [contaId],
          );
        }
      }

      return true;
    });
  }

  Future<Map<String, dynamic>> getResumoContasDoMes(int ano, int mes) async {
    final pagamentos = await getPagamentosDoMes(ano, mes);

    double totalPendente = 0;
    double totalPago = 0;
    int qtdPendente = 0;
    int qtdPago = 0;
    int qtdAtrasado = 0;

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
        final anoParc = anoMes ~/ 100;
        final mesParc = anoMes % 100;
        final dia = p['dia_vencimento'] as int;
        final dataVencimento = DateTime(anoParc, mesParc, dia);

        if (dataVencimento.isBefore(DateTime.now())) {
          qtdAtrasado++;
        }
      }
    }

    return {
      'totalPendente': totalPendente,
      'totalPago': totalPago,
      'qtdPendente': qtdPendente,
      'qtdPago': qtdPago,
      'qtdAtrasado': qtdAtrasado,
      'totalContas': pagamentos.length,
    };
  }

  Future<int> deletarConta(int contaId) async {
    final db = await database;
    return await db.delete(
      tabelaContas,
      where: 'id = ?',
      whereArgs: [contaId],
    );
  }

  // ========== FUNÇÕES DE CÁLCULO PARA RENDA FIXA ==========

  double calcularRendimentoDiario(double valor, double percentualCDI) {
    const double taxaCDIAnual = 14.65;
    final double cdiDiario = pow(1 + (taxaCDIAnual / 100), 1 / 252) - 1;
    final double rendimentoDiario = valor * cdiDiario * (percentualCDI / 100);
    return rendimentoDiario;
  }

  int _calcularDiasUteis(DateTime inicio, DateTime fim) {
    int diasUteis = 0;
    DateTime atual = inicio;

    while (atual.isBefore(fim) || atual.isAtSameMomentAs(fim)) {
      if (atual.weekday != DateTime.saturday &&
          atual.weekday != DateTime.sunday) {
        diasUteis++;
      }
      atual = atual.add(const Duration(days: 1));
    }
    return diasUteis;
  }

  DateTime _proximoDiaUtil(DateTime inicio, int dias) {
    DateTime data = inicio.add(Duration(days: dias));
    while (
        data.weekday == DateTime.saturday || data.weekday == DateTime.sunday) {
      data = data.add(const Duration(days: 1));
    }
    return data;
  }

  List<Map<String, dynamic>> calcularEvolucaoDiaria(Map<String, dynamic> item) {
    List<Map<String, dynamic>> evolucao = [];

    try {
      final dataAplicacao = DateTime.parse(item['data_aplicacao']);
      final dataVencimento = DateTime.parse(item['data_vencimento']);
      final valorInicial = (item['valor'] as num).toDouble();
      final percentualCDI = (item['taxa'] as num).toDouble();
      final hoje = DateTime.now();

      final diasUteisTotal = _calcularDiasUteis(dataAplicacao, dataVencimento);
      double valorAtual = valorInicial;

      for (int i = 1; i <= diasUteisTotal; i++) {
        final data = _proximoDiaUtil(dataAplicacao, i);
        if (data.isAfter(hoje)) break;

        final rendimentoHoje =
            calcularRendimentoDiario(valorAtual, percentualCDI);
        valorAtual += rendimentoHoje;

        if (i % 7 == 0 || i == diasUteisTotal) {
          evolucao.add({
            'data': data.toIso8601String(),
            'valor': valorAtual,
            'rendimento': rendimentoHoje,
            'rendimentoAcumulado': valorAtual - valorInicial,
            'dia': i,
          });
        }
      }

      final diasUteisAteHoje = _calcularDiasUteis(dataAplicacao, hoje);
      double valorHoje = valorInicial;

      for (int i = 1; i <= diasUteisAteHoje; i++) {
        final rendimento = calcularRendimentoDiario(valorHoje, percentualCDI);
        valorHoje += rendimento;
      }

      evolucao.add({
        'data': hoje.toIso8601String(),
        'valor': valorHoje,
        'rendimento': 0,
        'rendimentoAcumulado': valorHoje - valorInicial,
        'dia': diasUteisAteHoje,
        'hoje': true,
      });

      evolucao.sort((a, b) => a['data'].compareTo(b['data']));
    } catch (e) {
      LoggerService.error('Erro ao calcular evolução diária', e);
    }

    return evolucao;
  }

  double calcularValorEmData(Map<String, dynamic> item, DateTime data) {
    try {
      final dataAplicacao = DateTime.parse(item['data_aplicacao']);
      final valorInicial = (item['valor'] as num).toDouble();
      final percentualCDI = (item['taxa'] as num).toDouble();

      if (data.isBefore(dataAplicacao)) return valorInicial;

      final diasUteis = _calcularDiasUteis(dataAplicacao, data);
      double valorAtual = valorInicial;

      for (int i = 1; i <= diasUteis; i++) {
        final rendimentoHoje =
            calcularRendimentoDiario(valorAtual, percentualCDI);
        valorAtual += rendimentoHoje;
      }

      return valorAtual;
    } catch (e) {
      LoggerService.error('Erro ao calcular valor em data', e);
      return (item['valor'] as num?)?.toDouble() ?? 0;
    }
  }

  double calcularIR(int diasInvestido, double rendimento) {
    if (diasInvestido <= 180) return rendimento * 0.225;
    if (diasInvestido <= 360) return rendimento * 0.20;
    if (diasInvestido <= 720) return rendimento * 0.175;
    return rendimento * 0.15;
  }

  double calcularIOF(int diasInvestido, double rendimento) {
    if (diasInvestido < 30) {
      final aliquota = (30 - diasInvestido) / 30 * 0.96;
      return rendimento * aliquota;
    }
    return 0;
  }

  Map<String, double> simularRendaFixa({
    required double valor,
    required double taxa,
    required int dias,
    required String tipo,
    bool isLCI = false,
  }) {
    final rendimentoBruto = valor * (taxa / 100) * (dias / 365);
    double iof = 0;
    double ir = 0;

    if (!isLCI) {
      iof = calcularIOF(dias, rendimentoBruto);
      ir = calcularIR(dias, rendimentoBruto - iof);
    }

    final rendimentoLiquido = rendimentoBruto - iof - ir;
    final valorFinal = valor + rendimentoLiquido;

    return {
      'rendimentoBruto': rendimentoBruto,
      'iof': iof,
      'ir': ir,
      'rendimentoLiquido': rendimentoLiquido,
      'valorFinal': valorFinal,
    };
  }

  // ========== MÉTODOS ADICIONAIS ==========

  Future<void> insertLancamentosEmLote(
      List<Map<String, dynamic>> lancamentos) async {
    final db = await database;

    await db.transaction((txn) async {
      for (var lancamento in lancamentos) {
        lancamento['created_at'] = _agoraBrasil();
        lancamento['updated_at'] = _agoraBrasil();
        await txn.insert(tabelaLancamentos, lancamento);
      }
    });

    _clearTableCache(tabelaLancamentos);
    _clearQueryCache();
  }

  Future<void> updateInvestimentosEmLote(
      List<Map<String, dynamic>> investimentos) async {
    final db = await database;

    await db.transaction((txn) async {
      for (var item in investimentos) {
        final id = item['id'];
        item.remove('id');
        item['updated_at'] = _agoraBrasil();
        await txn.update(
          tabelaInvestimentos,
          item,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    });

    _clearTableCache(tabelaInvestimentos);
    _clearQueryCache();
  }

  Future<void> deleteEmLote(String table, List<int> ids) async {
    if (ids.isEmpty) return;

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');

    await db.execute(
      'DELETE FROM $table WHERE id IN ($placeholders)',
      ids,
    );

    _clearTableCache(table);
    _clearQueryCache();
  }

  Future<List<Map<String, dynamic>>> getLancamentosPaginados({
    required int pagina,
    int porPagina = 20,
    String? tipo,
    String? categoria,
    DateTime? dataInicio,
    DateTime? dataFim,
    OrdemLancamento ordem = OrdemLancamento.dataDesc,
    bool useCache = true,
  }) async {
    final db = await database;

    String where = '1=1';
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

    final result = await db.query(
      tabelaLancamentos,
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderBy,
      limit: porPagina,
      offset: offset,
    );

    if (useCache) {
      _queryCache[cacheKey] = CacheEntry(result, DateTime.now());
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getProventosFuturos() async {
    final db = await database;
    return await db.query(
      tabelaProventos,
      where: 'data_pagamento > ?',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'data_pagamento ASC',
    );
  }

  Future<double> getTotalProventosMes({int? mes, int? ano}) async {
    final agora = DateTime.now();
    final mesAlvo = mes ?? agora.month;
    final anoAlvo = ano ?? agora.year;

    final primeiroDia = DateTime(anoAlvo, mesAlvo, 1);
    final ultimoDia = DateTime(anoAlvo, mesAlvo + 1, 0);

    final db = await database;
    final results = await db.query(
      tabelaProventos,
      where: 'date(data_pagamento) BETWEEN date(?) AND date(?)',
      whereArgs: [primeiroDia.toIso8601String(), ultimoDia.toIso8601String()],
    );

    return results.fold<double>(
      0,
      (sum, item) => sum + ((item['total_recebido'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<int> updatePrecoAtual(int id, double preco) async {
    final db = await database;
    final result = await db.update(
      tabelaInvestimentos,
      {
        'preco_atual': preco,
        'ultima_atualizacao': _agoraBrasil(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _clearTableCache(tabelaInvestimentos);
    return result;
  }

  Future<int> atualizarProgressoMeta(int id, double valorAtual) async {
    final db = await database;
    final result = await db.update(
      tabelaMetas,
      {
        'valor_atual': valorAtual,
        'updated_at': _agoraBrasil(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _clearTableCache(tabelaMetas);
    return result;
  }

  Future<int> concluirMeta(int id) async {
    final db = await database;
    final result = await db.update(
      tabelaMetas,
      {
        'concluida': 1,
        'updated_at': _agoraBrasil(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _clearTableCache(tabelaMetas);
    return result;
  }

  // ========== MÉTODOS DE INTEGRIDADE ==========

  Future<Map<String, dynamic>> validarIntegridade() async {
    final db = await database;
    final resultados = <String, dynamic>{
      'valido': true,
      'erros': <String>[],
      'tabelas': <String, int>{},
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
        tabelaPagamentos,
      ];

      for (final tabela in tabelas) {
        try {
          final result =
              await db.rawQuery('SELECT COUNT(*) as total FROM $tabela');
          final count = (result.first['total'] as int?) ?? 0;
          resultados['tabelas'][tabela] = count;
        } catch (e) {
          resultados['valido'] = false;
          resultados['erros'].add('Erro na tabela $tabela: $e');
          await _logIntegridade(
              'erro', 'Falha na tabela $tabela', e.toString());
        }
      }

      final fkErrors = await db.rawQuery('''
        SELECT 
          (SELECT COUNT(*) FROM $tabelaDepositosMeta dm 
           LEFT JOIN $tabelaMetas m ON dm.meta_id = m.id 
           WHERE m.id IS NULL) as depositos_orfãos,
          (SELECT COUNT(*) FROM $tabelaPagamentos p 
           LEFT JOIN $tabelaContas c ON p.conta_id = c.id 
           WHERE c.id IS NULL) as pagamentos_orfãos
      ''');

      if (fkErrors.isNotEmpty) {
        if ((fkErrors.first['depositos_orfãos'] as int) > 0) {
          resultados['valido'] = false;
          resultados['erros'].add('Depósitos sem meta associada');
        }
        if ((fkErrors.first['pagamentos_orfãos'] as int) > 0) {
          resultados['valido'] = false;
          resultados['erros'].add('Pagamentos sem conta associada');
        }
      }

      LoggerService.info('✅ Validação de integridade concluída');
    } catch (e) {
      LoggerService.error('Erro na validação de integridade', e);
      resultados['valido'] = false;
      resultados['erros'].add('Erro geral: $e');
    }

    return resultados;
  }

  Future<void> _logIntegridade(
      String tipo, String mensagem, String? detalhes) async {
    try {
      final db = await database;
      await db.insert('integridade_logs', {
        'tipo': tipo,
        'mensagem': mensagem,
        'detalhes': detalhes,
      });
    } catch (e) {
      // Não faz nada se não conseguir logar
    }
  }

  Future<Map<String, dynamic>> repararIntegridade() async {
    final db = await database;
    final reparos = <String, dynamic>{'removidos': 0, 'corrigidos': 0};

    try {
      await db.transaction((txn) async {
        final removidosDepositos = await txn.rawDelete('''
          DELETE FROM $tabelaDepositosMeta 
          WHERE meta_id NOT IN (SELECT id FROM $tabelaMetas)
        ''');
        reparos['removidos'] =
            (reparos['removidos'] as int) + removidosDepositos;

        final removidosPagamentos = await txn.rawDelete('''
          DELETE FROM $tabelaPagamentos 
          WHERE conta_id NOT IN (SELECT id FROM $tabelaContas)
        ''');
        reparos['removidos'] =
            (reparos['removidos'] as int) + removidosPagamentos;

        await _logIntegridade(
            'reparo', 'Reparo concluído', 'Removidos: ${reparos['removidos']}');
      });

      LoggerService.success(
          '✅ Reparo concluído: ${reparos['removidos']} registros removidos');
    } catch (e) {
      LoggerService.error('Erro no reparo de integridade', e);
      reparos['erro'] = e.toString();
    }

    return reparos;
  }
}
