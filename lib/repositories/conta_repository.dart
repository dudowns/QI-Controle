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

  Future<Database> getDatabase() async {
    return await _dbHelper.database;
  }

  Future<List<Map<String, dynamic>>> getUltimosPagamentos(
      {int limit = 5}) async {
    final db = await _dbHelper.database;
    return await db.query(tabelaPagamentos,
        where: 'status = 1', orderBy: 'data_pagamento DESC', limit: limit);
  }

  Future<int> adicionarConta(Map<String, dynamic> conta) async {
    conta['sync_status'] = 'pending';
    conta['updated_at'] = DateTime.now().toIso8601String();
    final id = await _dbHelper.adicionarContaComUserId(conta);
    _syncService.syncNow();
    return id;
  }

  Future<List<Conta>> getContasAtivas() async {
    final db = await _dbHelper.database;
    final resultados = await db.query(tabelaContas,
        where: 'ativa = ?', whereArgs: [1], orderBy: 'nome ASC');
    return resultados.map((json) => Conta.fromJson(json)).toList();
  }

  Future<Conta?> getContaByIdString(String id) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(tabelaContas,
        where: 'id = ? OR remote_id = ?', whereArgs: [id, id]);
    if (resultados.isEmpty) return null;
    return Conta.fromJson(resultados.first);
  }

  Future<Conta?> getContaById(int id) async {
    return await getContaByIdString(id.toString());
  }

  // ✅ BUSCA DIRETA da tabela pagamentos_mensais
  Future<List<Map<String, dynamic>>> getPagamentosDoMes(
      int ano, int mes) async {
    try {
      final db = await _dbHelper.database;
      final anoMes = ano * 100 + mes;

      // Busca direto da tabela, sem JOIN complexo
      final local = await db.query(
        tabelaPagamentos,
        where: 'ano_mes = ?',
        whereArgs: [anoMes],
        orderBy: 'status ASC',
      );

      if (local.isNotEmpty) {
        LoggerService.info('✅ Dados locais: ${local.length} pagamentos');

        // Enriquece com dados da conta
        final resultados = <Map<String, dynamic>>[];
        for (var p in local) {
          final contaId = p['conta_id']?.toString() ?? '';
          Map<String, dynamic>? conta;
          if (contaId.isNotEmpty) {
            final contas = await db.query(
              tabelaContas,
              where: 'id = ? OR remote_id = ?',
              whereArgs: [contaId, contaId],
              limit: 1,
            );
            if (contas.isNotEmpty) conta = contas.first;
          }

          resultados.add({
            'id': p['id']?.toString() ?? '',
            'remote_id': p['remote_id']?.toString(),
            'conta_id': contaId,
            'ano_mes': p['ano_mes'] as int? ?? 0,
            'valor': (p['valor'] as num?)?.toDouble() ?? 0.0,
            'data_pagamento': p['data_pagamento'],
            'status': p['status'] as int? ?? 0,
            'lancamento_id': p['lancamento_id']?.toString(),
            'conta_nome': conta?['nome'] ?? 'Conta Removida',
            'dia_vencimento': conta?['dia_vencimento'] as int? ?? 1,
            'categoria': conta?['categoria'] ?? 'Outros',
            'conta_tipo': conta?['tipo'] ?? 'mensal',
            'parcelas_total': conta?['parcelas_total'] as int?,
            'parcelas_pagas': conta?['parcelas_pagas'] as int?,
          });
        }
        return resultados;
      }

      // Se vazio, busca do Supabase
      LoggerService.info('☁️ Banco local vazio, buscando do Supabase...');
      return await _getPagamentosDoMesSupabase(ano, mes);
    } catch (e) {
      LoggerService.error('Erro: $e');
      return [];
    }
  }

  Future<void> sincronizarPagamentosDoMes(int ano, int mes) async {
    try {
      final supabaseData = await _getPagamentosDoMesSupabase(ano, mes);
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
            '💾 ${supabaseData.length} pagamentos sincronizados');
      }
    } catch (e) {
      LoggerService.error('Erro ao sincronizar: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getPagamentosDoMesSupabase(
      int ano, int mes) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];
      final anoMes = ano * 100 + mes;
      final response = await _supabase
          .from('pagamentos_mensais')
          .select(
              '*, contas!inner(nome, dia_vencimento, categoria, tipo, parcelas_total, parcelas_pagas)')
          .eq('user_id', user.id)
          .eq('ano_mes', anoMes)
          .order('status', ascending: true);
      LoggerService.info('Supabase retornou ${response.length} pagamentos');
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
      resultados.sort((a, b) {
        final sA = a['status'] as int? ?? 0;
        final sB = b['status'] as int? ?? 0;
        if (sA != sB) return sA.compareTo(sB);
        return (a['dia_vencimento'] as int? ?? 1)
            .compareTo(b['dia_vencimento'] as int? ?? 1);
      });
      return resultados;
    } catch (e) {
      LoggerService.error('Erro ao buscar pagamentos do Supabase: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getResumoContasDoMes(int ano, int mes) async {
    final pagamentos = await getPagamentosDoMes(ano, mes);
    double totalPendente = 0, totalPago = 0;
    int qtdPendente = 0, qtdPago = 0, qtdAtrasado = 0;
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
        final anoMes = p['ano_mes'] as int? ?? 0;
        if (anoMes > 0) {
          final dv = DateTime(
              anoMes ~/ 100, anoMes % 100, p['dia_vencimento'] as int? ?? 1);
          if (dv.isBefore(hoje)) qtdAtrasado++;
        }
      }
    }
    return {
      'totalPendente': totalPendente,
      'totalPago': totalPago,
      'qtdPendente': qtdPendente,
      'qtdPago': qtdPago,
      'qtdAtrasado': qtdAtrasado,
      'totalContas': pagamentos.length
    };
  }

  Future<bool> pagarConta(int pagamentoId) async {
    final result = await _dbHelper.pagarConta(pagamentoId);
    return result;
  }

  Future<int> deletarConta(int contaId) async {
    final result = await _dbHelper.deletarConta(contaId);
    return result;
  }

  Future<int> atualizarConta(Map<String, dynamic> conta) async {
    final id = conta['id'];
    conta.remove('id');
    conta['sync_status'] = 'pending';
    conta['updated_at'] = DateTime.now().toIso8601String();
    final result = await _dbHelper.update(tabelaContas, conta, id);
    _syncService.syncNow();
    return result;
  }

  Future<Result<bool>> pagarContaComLancamento(int pagamentoId) async {
    return await pagarContaComLancamentoString(pagamentoId.toString());
  }

  Future<Result<bool>> pagarContaComLancamentoString(String pagamentoId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        tabelaPagamentos,
        {
          'status': 1,
          'data_pagamento': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending'
        },
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );
      _syncService.syncNow();
      return Result.success(true);
    } catch (e) {
      return Result.failure('Erro ao pagar conta: $e');
    }
  }

  Future<Result<bool>> desfazerPagamento(int pagamentoId) async {
    return await desfazerPagamentoString(pagamentoId.toString());
  }

  Future<Result<bool>> desfazerPagamentoString(String pagamentoId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        tabelaPagamentos,
        {
          'status': 0,
          'data_pagamento': null,
          'lancamento_id': null,
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending'
        },
        where: 'id = ? OR remote_id = ?',
        whereArgs: [pagamentoId, pagamentoId],
      );
      _syncService.syncNow();
      return Result.success(true);
    } catch (e) {
      return Result.failure('Erro ao desfazer pagamento: $e');
    }
  }

  Future<void> deletarContaString(String contaId) async {
    final db = await _dbHelper.database;
    await db
        .delete(tabelaPagamentos, where: 'conta_id = ?', whereArgs: [contaId]);
    await db.delete(tabelaContas,
        where: 'id = ? OR remote_id = ?', whereArgs: [contaId, contaId]);
    _syncService.syncNow();
  }

  Future<Result<List<Conta>>> getContasAtivasResult() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(tabelaContas,
          where: 'ativa = ?', whereArgs: [1], orderBy: 'nome ASC');
      return Result.success(
          resultados.map((json) => Conta.fromJson(json)).toList());
    } catch (e) {
      return Result.failure('Erro ao carregar contas: $e');
    }
  }

  Future<Result<Conta?>> getContaByIdResult(int id) async {
    try {
      return Result.success(await getContaByIdString(id.toString()));
    } catch (e) {
      return Result.failure('Erro ao buscar conta ID: $id\n$e');
    }
  }

  Future<Result<int>> adicionarContaResult(Map<String, dynamic> conta) async {
    try {
      conta['sync_status'] = 'pending';
      conta['updated_at'] = DateTime.now().toIso8601String();
      final id = await _dbHelper.adicionarContaComUserId(conta);
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
      _syncService.syncNow();
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao pagar conta ID: $pagamentoId\n$e');
    }
  }

  Future<Result<List<Map<String, dynamic>>>> getPagamentosDoMesResult(
      int ano, int mes) async {
    try {
      return Result.success(await getPagamentosDoMes(ano, mes));
    } catch (e) {
      return Result.failure('Erro ao carregar pagamentos: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> getResumoContasDoMesResult(
      int ano, int mes) async {
    try {
      return Result.success(await getResumoContasDoMes(ano, mes));
    } catch (e) {
      return Result.failure('Erro ao carregar resumo: $e');
    }
  }

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
      'Outros'
    ];
  }
}
