// lib/repositories/conta_repository.dart
import '../database/db_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conta_model.dart';
import '../services/sync_service.dart';
import '../models/result_model.dart';
import '../services/logger_service.dart';

class ContaRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  static const String tabelaContas = DBHelper.tabelaContas;
  static const String tabelaPagamentos = DBHelper.tabelaPagamentos;

  // ✅ FLAG PARA EVITAR CHAMADAS SIMULTÂNEAS
  bool _isLoadingPagamentos = false;

  // ✅ CACHE EM MEMÓRIA PARA EVITAR BUSCAS REPETIDAS
  final Map<String, List<Map<String, dynamic>>> _cachePaginacao = {};
  List<Map<String, dynamic>> _cachedPagamentos = [];

  // ✅ CONTROLE DE TEMPO DO CACHE (5 minutos)
  static const Duration _cacheDuration = Duration(minutes: 5);
  DateTime? _lastCacheTime;

  // METODO PARA ACESSAR O DATABASE
  Future<Database> getDatabase() async {
    return await _dbHelper.database;
  }

  // METODO PARA BUSCAR ULTIMOS PAGAMENTOS
  Future<List<Map<String, dynamic>>> getUltimosPagamentos(
      {int limit = 5}) async {
    final db = await _dbHelper.database;
    return await db.query(
      tabelaPagamentos,
      where: 'status = 1',
      orderBy: 'data_pagamento DESC',
      limit: limit,
    );
  }

  // ========== METODOS LEGADO ==========

  Future<int> adicionarConta(Map<String, dynamic> conta) async {
    conta['sync_status'] = 'pending';
    conta['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.adicionarContaComUserId(conta);

    // ✅ LIMPA CACHE AO ADICIONAR NOVA CONTA
    _limparCache();

    _syncService.syncNow();
    return id;
  }

  Future<List<Conta>> getContasAtivas() async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaContas,
      where: 'ativa = ?',
      whereArgs: [1],
      orderBy: 'nome ASC',
    );
    return resultados.map((json) => Conta.fromJson(json)).toList();
  }

  // Buscar conta por ID (String - UUID)
  Future<Conta?> getContaByIdString(String id) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaContas,
      where: 'id = ? OR remote_id = ?',
      whereArgs: [id, id],
    );
    if (resultados.isEmpty) return null;
    return Conta.fromJson(resultados.first);
  }

  // Mantido para compatibilidade
  Future<Conta?> getContaById(int id) async {
    return await getContaByIdString(id.toString());
  }

  // ✅ MÉTODO PARA LIMPAR CACHE
  void _limparCache() {
    _cachePaginacao.clear();
    _cachedPagamentos.clear();
    _lastCacheTime = null;
    _dbHelper.limparCacheCompleto();
    LoggerService.info('🗑️ Cache limpo');
  }

  // ✅ CORRIGIDO: Com cache em memória e controle de concorrência
  Future<List<Map<String, dynamic>>> getPagamentosDoMes(
      int ano, int mes) async {
    // ✅ EVITA CHAMADAS SIMULTÂNEAS
    if (_isLoadingPagamentos) {
      LoggerService.info(
          '⚠️ Carregamento de pagamentos já em andamento, retornando cache...');
      return _cachedPagamentos;
    }

    _isLoadingPagamentos = true;

    try {
      final cacheKey = '${ano}_$mes';

      // ✅ VERIFICA CACHE EM MEMÓRIA (VÁLIDO POR 5 MINUTOS)
      if (_cachePaginacao.containsKey(cacheKey) &&
          _lastCacheTime != null &&
          DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
        LoggerService.info('✅ Usando cache em memória para $cacheKey');
        _cachedPagamentos = _cachePaginacao[cacheKey]!;
        return _cachedPagamentos;
      }

      // Primeiro tenta buscar do banco local
      final local = await _dbHelper.getPagamentosDoMes(ano, mes);

      // Se tiver dados locais, retorna eles
      if (local.isNotEmpty) {
        LoggerService.info('✅ Usando dados locais: ${local.length} pagamentos');
        _cachePaginacao[cacheKey] = local;
        _cachedPagamentos = local;
        _lastCacheTime = DateTime.now();
        return local;
      }

      // Se nao tiver dados locais, busca do Supabase
      LoggerService.info('☁️ Banco local vazio, buscando do Supabase...');
      final supabaseData = await _getPagamentosDoMesSupabase(ano, mes);

      // Salvar no banco local para proximas vezes
      if (supabaseData.isNotEmpty) {
        final db = await _dbHelper.database;
        final userId = _supabase.auth.currentUser?.id;

        for (var p in supabaseData) {
          try {
            await db.insert(
              tabelaPagamentos,
              {
                'id': p['id'],
                'remote_id': p['remote_id'],
                'conta_id': p['conta_id'],
                'user_id': userId,
                'ano_mes': p['ano_mes'],
                'valor': p['valor'],
                'data_pagamento': p['data_pagamento'],
                'status': p['status'],
                'lancamento_id': p['lancamento_id'],
                'sync_status': 'synced',
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          } catch (e) {
            LoggerService.error('Erro ao inserir pagamento: $e');
          }
        }
        LoggerService.info(
            '💾 ${supabaseData.length} pagamentos salvos localmente');

        // ✅ FORÇA LIMPEZA DO CACHE DO DB HELPER PARA VER OS NOVOS DADOS
        _dbHelper.limparCacheCompleto();
      }

      // ✅ SALVA NO CACHE EM MEMÓRIA
      _cachePaginacao[cacheKey] = supabaseData;
      _cachedPagamentos = supabaseData;
      _lastCacheTime = DateTime.now();

      return supabaseData;
    } finally {
      // ✅ GARANTE QUE A FLAG SEJA LIBERADA MESMO EM CASO DE ERRO
      _isLoadingPagamentos = false;
    }
  }

  // CORRIGIDO: Buscar pagamentos diretamente do Supabase (IDs como String)
  Future<List<Map<String, dynamic>>> _getPagamentosDoMesSupabase(
      int ano, int mes) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final anoMes = ano * 100 + mes;

      // Buscar pagamentos com JOIN nas contas
      final response = await _supabase
          .from('pagamentos_mensais')
          .select(
              '*, contas!inner(nome, dia_vencimento, categoria, tipo, parcelas_total, parcelas_pagas)')
          .eq('user_id', user.id)
          .eq('ano_mes', anoMes)
          .order('status', ascending: true);

      LoggerService.info('Supabase retornou ${response.length} pagamentos');

      // Mapear os resultados (IDs como String)
      final List<Map<String, dynamic>> resultados = response.map((p) {
        final conta = p['contas'] as Map<String, dynamic>? ?? {};
        return {
          'id': p['id']?.toString() ?? '',
          'remote_id': p['remote_id']?.toString(),
          'conta_id': p['conta_id']?.toString() ?? '',
          'ano_mes': p['ano_mes'] as int? ?? 0,
          'valor': (p['valor'] as num?)?.toDouble() ?? 0.0,
          'data_pagamento': p['data_pagamento'],
          'status': p['status'] as int? ?? 0,
          'lancamento_id': p['lancamento_id']?.toString(),
          'conta_nome': conta['nome'] ?? 'Conta Removida',
          'dia_vencimento': conta['dia_vencimento'] as int? ?? 1,
          'categoria': conta['categoria'] ?? 'Outros',
          'conta_tipo': conta['tipo'] ?? 'mensal',
          'parcelas_total': conta['parcelas_total'] as int?,
          'parcelas_pagas': conta['parcelas_pagas'] as int?,
        };
      }).toList();

      // Ordenar manualmente: pendentes primeiro, depois por dia_vencimento
      resultados.sort((a, b) {
        final statusA = a['status'] as int? ?? 0;
        final statusB = b['status'] as int? ?? 0;

        if (statusA != statusB) {
          return statusA.compareTo(statusB);
        }

        final diaA = a['dia_vencimento'] as int? ?? 1;
        final diaB = b['dia_vencimento'] as int? ?? 1;
        return diaA.compareTo(diaB);
      });

      return resultados;
    } catch (e) {
      LoggerService.error('Erro ao buscar pagamentos do Supabase: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getResumoContasDoMes(int ano, int mes) async {
    // Primeiro tenta do banco local
    final local = await _dbHelper.getResumoContasDoMes(ano, mes);

    // Se tiver dados, retorna
    if (local['totalContas'] > 0) {
      return local;
    }

    // Se nao tiver, calcula a partir dos pagamentos buscados do Supabase
    final pagamentos = await getPagamentosDoMes(ano, mes);

    double totalPendente = 0;
    double totalPago = 0;
    int qtdPendente = 0;
    int qtdPago = 0;
    int qtdAtrasado = 0;

    final hoje = DateTime.now();

    for (var p in pagamentos) {
      final status = p['status'] as int? ?? 0;
      final valor = (p['valor'] as num?)?.toDouble() ?? 0.0;

      if (status == 1) {
        totalPago += valor;
        qtdPago++;
      } else {
        totalPendente += valor;
        qtdPendente++;

        // Verificar se esta atrasado
        final anoMes = p['ano_mes'] as int? ?? 0;
        if (anoMes > 0) {
          final anoParc = anoMes ~/ 100;
          final mesParc = anoMes % 100;
          final dia = p['dia_vencimento'] as int? ?? 1;
          final dataVencimento = DateTime(anoParc, mesParc, dia);

          if (dataVencimento.isBefore(hoje)) {
            qtdAtrasado++;
          }
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

  Future<bool> pagarConta(int pagamentoId) async {
    final result = await _dbHelper.pagarConta(pagamentoId);
    // ✅ LIMPA CACHE AO PAGAR CONTA
    _limparCache();
    return result;
  }

  Future<int> deletarConta(int contaId) async {
    final result = await _dbHelper.deletarConta(contaId);
    // ✅ LIMPA CACHE AO DELETAR CONTA
    _limparCache();
    return result;
  }

  Future<int> atualizarConta(Map<String, dynamic> conta) async {
    final id = conta['id'];
    conta.remove('id');
    conta['sync_status'] = 'pending';
    conta['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.update(tabelaContas, conta, id);
    // ✅ LIMPA CACHE AO ATUALIZAR CONTA
    _limparCache();
    _syncService.syncNow();
    return result;
  }

  // ========== METODOS COM INTEGRACAO COM LANCAMENTOS ==========

  Future<Result<bool>> pagarContaComLancamento(int pagamentoId) async {
    return await pagarContaComLancamentoString(pagamentoId.toString());
  }

  // NOVO: Pagar conta com ID String
  Future<Result<bool>> pagarContaComLancamentoString(String pagamentoId) async {
    try {
      final db = await _dbHelper.database;

      final pagamento = await db.query(
        tabelaPagamentos,
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );

      if (pagamento.isEmpty) {
        return Result.failure('Pagamento nao encontrado');
      }

      final pagamentoData = pagamento.first;
      final contaId = pagamentoData['conta_id']?.toString() ?? '';

      final conta = await db.query(
        tabelaContas,
        where: 'id = ? OR remote_id = ?',
        whereArgs: [contaId, contaId],
      );

      if (conta.isEmpty) {
        return Result.failure('Conta nao encontrada');
      }

      final contaData = conta.first;
      final dataPagamento = DateTime.now();

      // Atualizar status para pago (1)
      await db.update(
        tabelaPagamentos,
        {
          'status': 1,
          'data_pagamento': dataPagamento.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending',
        },
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );

      // Criar lancamento
      final lancamento = {
        'descricao': contaData['nome'],
        'valor': pagamentoData['valor'],
        'tipo': 'gasto',
        'categoria': contaData['categoria'] ?? 'Outros',
        'data': dataPagamento.toIso8601String(),
        'observacao': 'Pago automaticamente - Conta do Mes',
        'sync_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      };

      final lancamentoId = await _dbHelper.insertLancamento(lancamento);

      await db.update(
        tabelaPagamentos,
        {
          'lancamento_id': lancamentoId.toString(),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending',
        },
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );

      // ✅ LIMPA CACHE APÓS PAGAR
      _limparCache();

      _syncService.syncNow();

      return Result.success(true);
    } catch (e) {
      return Result.failure('Erro ao pagar conta: $e');
    }
  }

  Future<Result<bool>> desfazerPagamento(int pagamentoId) async {
    return await desfazerPagamentoString(pagamentoId.toString());
  }

  // NOVO: Desfazer pagamento com ID String
  Future<Result<bool>> desfazerPagamentoString(String pagamentoId) async {
    try {
      final db = await _dbHelper.database;

      final pagamento = await db.query(
        tabelaPagamentos,
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );

      if (pagamento.isEmpty) {
        return Result.failure('Pagamento nao encontrado');
      }

      final pagamentoData = pagamento.first;

      if (pagamentoData['status'] != 1) {
        return Result.failure('Este pagamento nao esta pago');
      }

      final lancamentoId = pagamentoData['lancamento_id']?.toString();

      if (lancamentoId != null && lancamentoId.isNotEmpty) {
        await db.delete(
          DBHelper.tabelaLancamentos,
          where: 'id = ? OR remote_id = ?',
          whereArgs: [lancamentoId, lancamentoId],
        );
        LoggerService.info('Lancamento deletado: $lancamentoId');
      }

      await db.update(
        tabelaPagamentos,
        {
          'status': 0,
          'data_pagamento': null,
          'lancamento_id': null,
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending',
        },
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );

      // ✅ LIMPA CACHE APÓS DESFAZER
      _limparCache();

      _syncService.syncNow();

      return Result.success(true);
    } catch (e) {
      LoggerService.error('Erro ao desfazer pagamento: $e');
      return Result.failure('Erro ao desfazer pagamento: $e');
    }
  }

  // NOVO: Deletar conta com ID String
  Future<void> deletarContaString(String contaId) async {
    final db = await _dbHelper.database;

    // Primeiro deletar pagamentos associados
    await db.delete(
      tabelaPagamentos,
      where: 'conta_id = ?',
      whereArgs: [contaId],
    );

    // Depois deletar a conta
    await db.delete(
      tabelaContas,
      where: 'id = ? OR remote_id = ?',
      whereArgs: [contaId, contaId],
    );

    // ✅ LIMPA CACHE APÓS DELETAR
    _limparCache();

    _syncService.syncNow();
  }

  // ========== METODOS COM RESULT ==========

  Future<Result<List<Conta>>> getContasAtivasResult() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        tabelaContas,
        where: 'ativa = ?',
        whereArgs: [1],
        orderBy: 'nome ASC',
      );
      final contas = resultados.map((json) => Conta.fromJson(json)).toList();
      return Result.success(contas);
    } catch (e) {
      return Result.failure('Erro ao carregar contas: $e');
    }
  }

  Future<Result<Conta?>> getContaByIdResult(int id) async {
    try {
      final conta = await getContaByIdString(id.toString());
      return Result.success(conta);
    } catch (e) {
      return Result.failure('Erro ao buscar conta ID: $id\n$e');
    }
  }

  Future<Result<int>> adicionarContaResult(Map<String, dynamic> conta) async {
    try {
      conta['sync_status'] = 'pending';
      conta['updated_at'] = DateTime.now().toIso8601String();

      final id = await _dbHelper.adicionarContaComUserId(conta);
      _limparCache();
      _syncService.syncNow();
      return Result.success(id);
    } catch (e) {
      return Result.failure('Erro ao adicionar conta: ${conta['nome']}\n$e');
    }
  }

  Future<Result<int>> atualizarContaResult(Map<String, dynamic> conta) async {
    try {
      final id = conta['id'];
      conta.remove('id');
      conta['sync_status'] = 'pending';
      conta['updated_at'] = DateTime.now().toIso8601String();

      final result = await _dbHelper.update(tabelaContas, conta, id);
      _limparCache();
      _syncService.syncNow();
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao atualizar conta: ${conta['nome']}\n$e');
    }
  }

  Future<Result<int>> deletarContaResult(int id) async {
    try {
      await deletarContaString(id.toString());
      _syncService.syncNow();
      return Result.success(1);
    } catch (e) {
      return Result.failure('Erro ao excluir conta ID: $id\n$e');
    }
  }

  Future<Result<bool>> pagarContaResult(int pagamentoId) async {
    try {
      final result = await _dbHelper.pagarConta(pagamentoId);
      _limparCache();
      _syncService.syncNow();
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao pagar conta ID: $pagamentoId\n$e');
    }
  }

  Future<Result<List<Map<String, dynamic>>>> getPagamentosDoMesResult(
      int ano, int mes) async {
    try {
      final pagamentos = await getPagamentosDoMes(ano, mes);
      return Result.success(pagamentos);
    } catch (e) {
      return Result.failure('Erro ao carregar pagamentos: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> getResumoContasDoMesResult(
      int ano, int mes) async {
    try {
      final resumo = await getResumoContasDoMes(ano, mes);
      return Result.success(resumo);
    } catch (e) {
      return Result.failure('Erro ao carregar resumo: $e');
    }
  }

  // ========== METODOS AUXILIARES ==========

  List<String> getCategorias() {
    return [
      'Transporte',
      'Alimentacao',
      'Moradia',
      'Lazer',
      'Saude',
      'Educacao',
      'Cartao',
      'Investimentos',
      'Cuidados Pessoais',
      'Emprestimo',
      'Agua',
      'Luz',
      'Internet',
      'Telefone',
      'IPVA',
      'IPTU',
      'Financiamento',
      'Cartao de Credito',
      'Outros',
    ];
  }
}
