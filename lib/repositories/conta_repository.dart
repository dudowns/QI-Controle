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

  // ✅ CORRIGIDO: Salva no Supabase PRIMEIRO, depois no banco local, e gera pagamentos
  Future<int> adicionarConta(Map<String, dynamic> conta) async {
    final user = _supabase.auth.currentUser;

    // 1. PRIMEIRO SALVA NO SUPABASE
    String? remoteId;
    if (user != null) {
      try {
        final dadosSupabase = {
          'user_id': user.id,
          'nome': conta['nome'],
          'valor': conta['valor'] ?? conta['valor_estimado'] ?? 0,
          'dia_vencimento': conta['dia_vencimento'] as int? ?? 1,
          'categoria': conta['categoria'] ?? 'Outros',
          'tipo': conta['tipo'] ?? 'mensal',
          'parcelas_total': conta['parcelas_total'] as int? ?? 1,
          'parcelas_pagas': conta['parcelas_pagas'] as int? ?? 0,
          'ativa': 1,
          'data_inicio':
              conta['data_inicio'] ?? DateTime.now().toIso8601String(),
          'criado_em': DateTime.now().toIso8601String(),
          'atualizado_em': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('contas')
            .insert(dadosSupabase)
            .select('id')
            .single();

        remoteId = response['id']?.toString();
        LoggerService.success('✅ Conta salva no Supabase: $remoteId');

        // ✅ GERA OS PAGAMENTOS NO SUPABASE
        if (remoteId != null) {
          await _gerarPagamentosSupabase(user.id, remoteId, conta);
        }
      } catch (e) {
        LoggerService.error('❌ Erro ao salvar no Supabase: $e');
      }
    }

    // 2. DEPOIS SALVA NO BANCO LOCAL
    conta['remote_id'] = remoteId;
    conta['sync_status'] = remoteId != null ? 'synced' : 'pending';
    conta['user_id'] = user?.id;
    conta['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.adicionarContaComUserId(conta);

    // 3. DISPARA SINCRONIZAÇÃO
    _syncService.syncNow();

    return id;
  }

  // ✅ NOVO MÉTODO: Gerar pagamentos no Supabase
  Future<void> _gerarPagamentosSupabase(
      String userId, String contaId, Map<String, dynamic> conta) async {
    try {
      final dataInicioStr =
          conta['data_inicio']?.toString() ?? DateTime.now().toIso8601String();
      final dataInicio = DateTime.parse(dataInicioStr);
      final tipo = conta['tipo']?.toString() ?? 'mensal';
      final valor = (conta['valor'] as num?)?.toDouble() ?? 0.0;
      final diaVencimento = conta['dia_vencimento'] as int? ?? 1;
      final limite =
          tipo == 'parcelada' ? (conta['parcelas_total'] as int? ?? 1) : 60;

      final pagamentos = <Map<String, dynamic>>[];
      for (int i = 0; i < limite; i++) {
        final mesReferencia =
            DateTime(dataInicio.year, dataInicio.month + i, diaVencimento);
        final anoMes = mesReferencia.year * 100 + mesReferencia.month;
        pagamentos.add({
          'user_id': userId,
          'conta_id': contaId,
          'ano_mes': anoMes,
          'valor': valor,
          'status': 0,
          'criado_em': DateTime.now().toIso8601String(),
          'atualizado_em': DateTime.now().toIso8601String(),
        });
      }

      await _supabase.from('pagamentos_mensais').insert(pagamentos);
      LoggerService.success(
          '✅ ${pagamentos.length} pagamentos gerados no Supabase');
    } catch (e) {
      LoggerService.error('❌ Erro ao gerar pagamentos no Supabase: $e');
    }
  }

  Future<List<Conta>> getContasAtivas() async {
    final db = await _dbHelper.database;
    final resultados = await db.query(tabelaContas,
        where: 'ativa = ? AND (deleted_at IS NULL)',
        whereArgs: [1],
        orderBy: 'nome ASC');
    return resultados.map((json) => Conta.fromJson(json)).toList();
  }

  Future<Conta?> getContaByIdString(String id) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(tabelaContas,
        where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
        whereArgs: [id, id]);
    if (resultados.isEmpty) return null;
    return Conta.fromJson(resultados.first);
  }

  Future<Conta?> getContaById(int id) async {
    return await getContaByIdString(id.toString());
  }

  Future<List<Map<String, dynamic>>> getPagamentosDoMes(
      int ano, int mes) async {
    try {
      final db = await _dbHelper.database;
      final anoMes = ano * 100 + mes;

      final local = await db.query(
        tabelaPagamentos,
        where: 'ano_mes = ? AND (deleted_at IS NULL)',
        whereArgs: [anoMes],
        orderBy: 'status ASC',
      );

      if (local.isNotEmpty) {
        LoggerService.info('Base local: ${local.length} pagamentos');

        final resultados = <Map<String, dynamic>>[];
        for (var p in local) {
          final contaId = p['conta_id']?.toString() ?? '';
          Map<String, dynamic>? conta;

          if (contaId.isNotEmpty) {
            final contas = await db.query(
              tabelaContas,
              where: '(id = ? OR remote_id = ?) AND (deleted_at IS NULL)',
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

      LoggerService.info('Banco local vazio, buscando da nuvem...');
      return await _getPagamentosDoMesSupabase(ano, mes);
    } catch (e) {
      LoggerService.error('Erro ao processar pagamentos do mês local: $e');
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

      final List<Map<String, dynamic>> resultados = (response as List).map((p) {
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

  // ============================================================
  // 🔥 FUNÇÃO DELETAR CONTA - CORRIGIDA COM SUPABASE
  // ============================================================
  Future<void> deletarConta(String contaId) async {
    //DEBUG INICIO//
    print('🗑️ [DEBUG] deletarConta INICIADO');
    print('🗑️ [DEBUG] contaId = "$contaId"');
    //FINAL DEBUG//

    final db = await _dbHelper.database;
    final user = _supabase.auth.currentUser;

    // 🔥 1. PRIMEIRO, BUSCA O remote_id DA CONTA
    String? remoteId;
    try {
      final result = await db.query(
        tabelaContas,
        where: 'id = ? OR remote_id = ?',
        whereArgs: [contaId, contaId],
      );
      if (result.isNotEmpty) {
        remoteId = result.first['remote_id'] as String?;
        //DEBUG INICIO//
        print('🗑️ [DEBUG] remoteId encontrado = "$remoteId"');
        //FINAL DEBUG//
      }
    } catch (e) {
      //DEBUG INICIO//
      print('🔴 [DEBUG] Erro ao buscar remoteId: $e');
      //FINAL DEBUG//
    }

    // 🔥 2. EXCLUI DO SUPABASE (se tiver user e remoteId)
    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        //DEBUG INICIO//
        print('🗑️ [DEBUG] Excluindo do Supabase: remoteId="$remoteId"');
        //FINAL DEBUG//

        // Exclui os pagamentos associados
        await _supabase
            .from('pagamentos_mensais')
            .delete()
            .eq('conta_id', remoteId);

        // Exclui a conta
        await _supabase
            .from('contas')
            .delete()
            .eq('id', remoteId)
            .eq('user_id', user.id);

        //DEBUG INICIO//
        print('🗑️ [DEBUG] Supabase: exclusão concluída');
        //FINAL DEBUG//
      } catch (e) {
        //DEBUG INICIO//
        print('🔴 [DEBUG] Erro ao excluir do Supabase: $e');
        //FINAL DEBUG//
        LoggerService.error('Erro ao excluir do Supabase: $e');
      }
    }

    // 🔥 3. EXCLUI DO BANCO LOCAL
    try {
      //DEBUG INICIO//
      print('🗑️ [DEBUG] Excluindo do banco local');
      //FINAL DEBUG//

      // Exclui os pagamentos associados
      await db.delete(
        tabelaPagamentos,
        where: 'conta_id = ?',
        whereArgs: [contaId],
      );

      // Exclui a conta
      await db.delete(
        tabelaContas,
        where: 'id = ? OR remote_id = ?',
        whereArgs: [contaId, contaId],
      );

      //DEBUG INICIO//
      print('🗑️ [DEBUG] Banco local: exclusão concluída');
      //FINAL DEBUG//
    } catch (e) {
      //DEBUG INICIO//
      print('🔴 [DEBUG] Erro ao excluir do banco local: $e');
      //FINAL DEBUG//
      LoggerService.error('Erro ao excluir do banco local: $e');
      rethrow;
    }

    // 🔥 4. DISPARA SINCRONIZAÇÃO
    _syncService.syncNow();

    //DEBUG INICIO//
    print('🗑️ [DEBUG] deletarConta FINALIZADO');
    //FINAL DEBUG//
  }

  Future<String?> _getRemoteIdFromLocalId(String localId) async {
    final db = await _dbHelper.database;
    final result =
        await db.query(tabelaContas, where: 'id = ?', whereArgs: [localId]);
    if (result.isNotEmpty) {
      return result.first['remote_id'] as String?;
    }
    return null;
  }

  Future<void> deletarContaString(String contaId) async {
    //DEBUG INICIO//
    print('🗑️ [DEBUG] deletarContaString INICIADO');
    print('🗑️ [DEBUG] contaId = "$contaId"');
    //FINAL DEBUG//
    await deletarConta(contaId);
  }

  // ============================================================
  // 🔥 FUNÇÃO ATUALIZAR CONTA - CORRIGIDA COM SUPABASE
  // ============================================================
  Future<int> atualizarConta(Map<String, dynamic> conta) async {
    //DEBUG INICIO//
    print('✏️ [DEBUG] atualizarConta INICIADO');
    print('✏️ [DEBUG] conta = $conta');
    //FINAL DEBUG//

    final user = _supabase.auth.currentUser;
    final id = conta['id'];
    final remoteId = conta['remote_id']?.toString();

    // 🔥 1. ATUALIZA NO SUPABASE
    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        //DEBUG INICIO//
        print('✏️ [DEBUG] Atualizando no Supabase: remoteId="$remoteId"');
        //FINAL DEBUG//

        final dadosSupabase = {
          'nome': conta['nome'],
          'valor': conta['valor'],
          'dia_vencimento': conta['dia_vencimento'],
          'categoria': conta['categoria'],
          'tipo': conta['tipo'],
          'parcelas_total': conta['parcelas_total'],
          'parcelas_pagas': conta['parcelas_pagas'],
          'ativa': conta['ativa'],
          'data_inicio': conta['data_inicio'],
          'atualizado_em': DateTime.now().toIso8601String(),
        };

        await _supabase
            .from('contas')
            .update(dadosSupabase)
            .eq('id', remoteId)
            .eq('user_id', user.id);

        //DEBUG INICIO//
        print('✏️ [DEBUG] Supabase: atualização concluída');
        //FINAL DEBUG//
      } catch (e) {
        //DEBUG INICIO//
        print('🔴 [DEBUG] Erro ao atualizar no Supabase: $e');
        //FINAL DEBUG//
        LoggerService.error('Erro ao atualizar no Supabase: $e');
      }
    }

    // 🔥 2. ATUALIZA NO BANCO LOCAL
    try {
      //DEBUG INICIO//
      print('✏️ [DEBUG] Atualizando no banco local');
      //FINAL DEBUG//

      final mapaParaSalvar = Map<String, dynamic>.from(conta);
      mapaParaSalvar.remove('id');
      mapaParaSalvar['sync_status'] = 'pending';
      mapaParaSalvar['updated_at'] = DateTime.now().toIso8601String();

      final result = await _dbHelper.update(tabelaContas, mapaParaSalvar, id);

      //DEBUG INICIO//
      print('✏️ [DEBUG] Banco local: atualização concluída, result=$result');
      //FINAL DEBUG//

      return result;
    } catch (e) {
      //DEBUG INICIO//
      print('🔴 [DEBUG] Erro ao atualizar no banco local: $e');
      //FINAL DEBUG//
      LoggerService.error('Erro ao atualizar no banco local: $e');
      rethrow;
    }
  }

  // ============================================================
  // RESULT METHODS
  // ============================================================
  Future<Result<bool>> pagarConta(int pagamentoId) async {
    try {
      final res = await _dbHelper.pagarConta(pagamentoId);
      _syncService.syncNow();
      return Result.success(res);
    } catch (e) {
      return Result.failure(e.toString());
    }
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

  Future<Result<List<Conta>>> getContasAtivasResult() async {
    try {
      final result = await getContasAtivas();
      return Result.success(result);
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
      final id = await adicionarConta(conta);
      return Result.success(id);
    } catch (e) {
      return Result.failure('Erro ao adicionar conta: ${conta['nome']}\n$e');
    }
  }

  Future<Result<int>> atualizarContaResult(Map<String, dynamic> conta) async {
    try {
      final result = await atualizarConta(conta);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao atualizar conta: ${conta['nome']}\n$e');
    }
  }

  Future<Result<int>> deletarContaResult(int id) async {
    try {
      await deletarConta(id.toString());
      return Result.success(1);
    } catch (e) {
      return Result.failure('Erro ao excluir conta ID: $id\n$e');
    }
  }

  Future<Result<bool>> pagarContaResult(int pagamentoId) async {
    return await pagarConta(pagamentoId);
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
      'Alimentação',
      'Cartão de Crédito',
      'Cuidados Pessoais',
      'Educação',
      'Empréstimo',
      'Investimentos',
      'Lazer',
      'Moradia',
      'Saúde',
      'Transporte',
      'Outros'
    ];
  }
}
