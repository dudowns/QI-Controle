// lib/repositories/conta_repository.dart
import '../database/db_helper.dart';
import '../models/conta_model.dart';
import '../services/sync_service.dart';
import '../utils/result.dart';
import '../utils/loading_mixin.dart';
import '../services/logger_service.dart';

class ContaRepository with LoadingMixin {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();

  static const String tabelaContas = DBHelper.tabelaContas;
  static const String tabelaPagamentos = DBHelper.tabelaPagamentos;

  // ========== MÉTODOS LEGADO ==========

  Future<int> adicionarConta(Map<String, dynamic> conta) async {
    conta['sync_status'] = 'pending';
    conta['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.adicionarContaComUserId(conta);
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

  Future<Conta?> getContaById(int id) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaContas,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultados.isEmpty) return null;
    return Conta.fromJson(resultados.first);
  }

  Future<List<Map<String, dynamic>>> getPagamentosDoMes(
      int ano, int mes) async {
    return await _dbHelper.getPagamentosDoMes(ano, mes);
  }

  Future<Map<String, dynamic>> getResumoContasDoMes(int ano, int mes) async {
    return await _dbHelper.getResumoContasDoMes(ano, mes);
  }

  Future<bool> pagarConta(int pagamentoId) async {
    return await _dbHelper.pagarConta(pagamentoId);
  }

  Future<int> deletarConta(int contaId) async {
    return await _dbHelper.deletarConta(contaId);
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

  // ========== MÉTODOS COM INTEGRAÇÃO COM LANÇAMENTOS ==========

  /// Paga uma conta e cria um lançamento automaticamente
  Future<Result<bool>> pagarContaComLancamento(int pagamentoId) async {
    return await withLoadingResult(() async {
      try {
        final db = await _dbHelper.database;

        final pagamento = await db.query(
          tabelaPagamentos,
          where: 'id = ?',
          whereArgs: [pagamentoId],
        );

        if (pagamento.isEmpty) {
          return Result.failure('Pagamento não encontrado');
        }

        final pagamentoData = pagamento.first;
        final contaId = pagamentoData['conta_id'] as int;

        final conta = await db.query(
          tabelaContas,
          where: 'id = ?',
          whereArgs: [contaId],
        );

        if (conta.isEmpty) {
          return Result.failure('Conta não encontrada');
        }

        final contaData = conta.first;
        final dataPagamento = DateTime.now();

        // Marcar a conta como paga
        final pagou = await _dbHelper.pagarConta(pagamentoId);

        if (pagou) {
          // Criar lançamento
          final lancamento = {
            'descricao': contaData['nome'],
            'valor': pagamentoData['valor'],
            'tipo': 'gasto',
            'categoria': contaData['categoria'] ?? 'Outros',
            'data': dataPagamento.toIso8601String(),
            'observacao': 'Pago automaticamente - Conta do Mês',
            'sync_status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          };

          // Inserir lançamento e pegar o ID
          final lancamentoId = await _dbHelper.insertLancamento(lancamento);

          // Salvar o ID do lançamento na tabela de pagamentos
          await db.update(
            tabelaPagamentos,
            {
              'lancamento_id': lancamentoId,
              'updated_at': DateTime.now().toIso8601String(),
              'sync_status': 'pending',
            },
            where: 'id = ?',
            whereArgs: [pagamentoId],
          );

          _syncService.syncNow();

          return Result.success(true);
        }

        return Result.success(false);
      } catch (e) {
        return Result.failure('❌ Erro ao pagar conta: $e');
      }
    });
  }

  /// Desfaz um pagamento (remove o lançamento e marca a conta como pendente)
  Future<Result<bool>> desfazerPagamento(int pagamentoId) async {
    return await withLoadingResult(() async {
      try {
        final db = await _dbHelper.database;

        // Buscar o pagamento
        final pagamento = await db.query(
          tabelaPagamentos,
          where: 'id = ?',
          whereArgs: [pagamentoId],
        );

        if (pagamento.isEmpty) {
          return Result.failure('Pagamento não encontrado');
        }

        final pagamentoData = pagamento.first;

        if (pagamentoData['status'] != 1) {
          return Result.failure('Este pagamento não está pago');
        }

        // Pegar o ID do lançamento diretamente
        final lancamentoId = pagamentoData['lancamento_id'] as int?;

        if (lancamentoId != null) {
          // Deletar o lançamento pelo ID
          await db.delete(
            DBHelper.tabelaLancamentos,
            where: 'id = ?',
            whereArgs: [lancamentoId],
          );
          LoggerService.info('🗑️ Lançamento deletado: ID $lancamentoId');
        } else {
          LoggerService.info(
              '⚠️ Nenhum lancamento_id encontrado para este pagamento');
        }

        // Marcar a conta como pendente
        await db.update(
          tabelaPagamentos,
          {
            'status': 0,
            'data_pagamento': null,
            'lancamento_id': null,
            'updated_at': DateTime.now().toIso8601String(),
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [pagamentoId],
        );

        _syncService.syncNow();

        return Result.success(true);
      } catch (e) {
        LoggerService.error('❌ Erro ao desfazer pagamento: $e');
        return Result.failure('❌ Erro ao desfazer pagamento: $e');
      }
    });
  }

  // ========== MÉTODOS COM RESULT ==========

  Future<Result<List<Conta>>> getContasAtivasResult() async {
    return await withLoadingResult(() async {
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
        return Result.failure('❌ Erro ao carregar contas: $e');
      }
    });
  }

  Future<Result<Conta?>> getContaByIdResult(int id) async {
    return await withLoadingResult(() async {
      try {
        final db = await _dbHelper.database;
        final resultados = await db.query(
          tabelaContas,
          where: 'id = ?',
          whereArgs: [id],
        );
        if (resultados.isEmpty) return Result.success(null);
        return Result.success(Conta.fromJson(resultados.first));
      } catch (e) {
        return Result.failure('❌ Erro ao buscar conta ID: $id\n$e');
      }
    });
  }

  Future<Result<int>> adicionarContaResult(Map<String, dynamic> conta) async {
    return await withLoadingResult(() async {
      try {
        conta['sync_status'] = 'pending';
        conta['updated_at'] = DateTime.now().toIso8601String();

        final id = await _dbHelper.adicionarContaComUserId(conta);
        _syncService.syncNow();
        return Result.success(id);
      } catch (e) {
        return Result.failure(
            '❌ Erro ao adicionar conta: ${conta['nome']}\n$e');
      }
    });
  }

  Future<Result<int>> atualizarContaResult(Map<String, dynamic> conta) async {
    return await withLoadingResult(() async {
      try {
        final id = conta['id'];
        conta.remove('id');
        conta['sync_status'] = 'pending';
        conta['updated_at'] = DateTime.now().toIso8601String();

        final result = await _dbHelper.update(tabelaContas, conta, id);
        _syncService.syncNow();
        return Result.success(result);
      } catch (e) {
        return Result.failure(
            '❌ Erro ao atualizar conta: ${conta['nome']}\n$e');
      }
    });
  }

  Future<Result<int>> deletarContaResult(int id) async {
    return await withLoadingResult(() async {
      try {
        final result = await _dbHelper.deletarConta(id);
        _syncService.syncNow();
        return Result.success(result);
      } catch (e) {
        return Result.failure('❌ Erro ao excluir conta ID: $id\n$e');
      }
    });
  }

  Future<Result<bool>> pagarContaResult(int pagamentoId) async {
    return await withLoadingResult(() async {
      try {
        final result = await _dbHelper.pagarConta(pagamentoId);
        _syncService.syncNow();
        return Result.success(result);
      } catch (e) {
        return Result.failure('❌ Erro ao pagar conta ID: $pagamentoId\n$e');
      }
    });
  }

  Future<Result<List<Map<String, dynamic>>>> getPagamentosDoMesResult(
    int ano,
    int mes,
  ) async {
    return await withLoadingResult(() async {
      try {
        final pagamentos = await _dbHelper.getPagamentosDoMes(ano, mes);
        return Result.success(pagamentos);
      } catch (e) {
        return Result.failure('❌ Erro ao carregar pagamentos: $e');
      }
    });
  }

  Future<Result<Map<String, dynamic>>> getResumoContasDoMesResult(
    int ano,
    int mes,
  ) async {
    return await withLoadingResult(() async {
      try {
        final resumo = await _dbHelper.getResumoContasDoMes(ano, mes);
        return Result.success(resumo);
      } catch (e) {
        return Result.failure('❌ Erro ao carregar resumo: $e');
      }
    });
  }

  // ========== MÉTODOS AUXILIARES ==========

  List<String> getCategorias() {
    return [
      'Transporte',
      'Alimentação',
      'Moradia',
      'Lazer',
      'Saúde',
      'Educação',
      'Cartão',
      'Investimentos',
      'Cuidados Pessoais',
      'Empréstimo',
      'Água',
      'Luz',
      'Internet',
      'Telefone',
      'IPVA',
      'IPTU',
      'Financiamento',
      'Cartão de Crédito',
      'Outros',
    ];
  }
}
