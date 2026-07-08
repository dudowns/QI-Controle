// lib/repositories/lancamento_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';
import '../models/lancamento_model.dart';
import '../services/sync_service.dart';
import '../constants/app_categories.dart';
import '../models/result_model.dart';
import '../services/logger_service.dart';

class LancamentoRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();
  final _supabase = Supabase.instance.client;

  static const String tabelaLancamentos = DBHelper.tabelaLancamentos;

  // ========== INSERIR (CORRIGIDO - Supabase primeiro) ==========
  Future<int> insertLancamento(Map<String, dynamic> lancamento) async {
    final user = _supabase.auth.currentUser;

    // 1. Salva no Supabase primeiro
    String? remoteId;
    if (user != null) {
      try {
        final dadosSupabase = {
          'user_id': user.id,
          'descricao': lancamento['descricao'],
          'valor': lancamento['valor'],
          'tipo': lancamento['tipo'],
          'categoria': lancamento['categoria'],
          'data': lancamento['data'],
          'observacao': lancamento['observacao'] ?? '',
          // ✅ CORRIGIDO: usa os nomes corretos das colunas
          'criado_em': DateTime.now().toIso8601String(),
          'atualizado_em': DateTime.now().toIso8601String(),
        };

        final response = await _supabase
            .from('lancamentos')
            .insert(dadosSupabase)
            .select('id')
            .single();

        remoteId = response['id']?.toString();
        LoggerService.success('✅ Lançamento salvo no Supabase: $remoteId');
      } catch (e) {
        LoggerService.error('❌ Erro ao salvar lançamento no Supabase: $e');
      }
    }

    // 2. Depois salva no banco local
    lancamento['remote_id'] = remoteId;
    lancamento['sync_status'] = remoteId != null ? 'synced' : 'pending';
    lancamento['user_id'] = user?.id;
    lancamento['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertLancamento(lancamento);
    _syncService.syncNow();
    return id;
  }

  Future<int> insertLancamentoModel(Lancamento lancamento) async {
    final json = lancamento.toJson();
    return await insertLancamento(json);
  }

  // ========== ATUALIZAR (CORRIGIDO) ==========
  Future<int> updateLancamento(Map<String, dynamic> lancamento) async {
    final user = _supabase.auth.currentUser;
    final remoteId = lancamento['remote_id']?.toString();

    // 1. Atualiza no Supabase
    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('lancamentos')
            .update({
              'descricao': lancamento['descricao'],
              'valor': lancamento['valor'],
              'tipo': lancamento['tipo'],
              'categoria': lancamento['categoria'],
              'data': lancamento['data'],
              'observacao': lancamento['observacao'] ?? '',
              // ✅ CORRIGIDO
              'atualizado_em': DateTime.now().toIso8601String(),
            })
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Lançamento atualizado no Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao atualizar no Supabase: $e');
      }
    }

    // 2. Atualiza no banco local
    lancamento['sync_status'] = 'pending';
    lancamento['updated_at'] = DateTime.now().toIso8601String();
    final result = await _dbHelper.updateLancamento(lancamento);
    _syncService.syncNow();
    return result;
  }

  // ========== DELETAR ==========
  Future<int> deleteLancamento(int id) async {
    final lancamento = await getLancamentoById(id);
    final remoteId = lancamento?['remote_id'] as String?;
    final user = _supabase.auth.currentUser;

    // 1. Deleta do Supabase
    if (user != null && remoteId != null && remoteId.isNotEmpty) {
      try {
        await _supabase
            .from('lancamentos')
            .delete()
            .eq('id', remoteId)
            .eq('user_id', user.id);
        LoggerService.success('✅ Lançamento deletado do Supabase');
      } catch (e) {
        LoggerService.error('❌ Erro ao deletar do Supabase: $e');
      }
    }

    // 2. Deleta do banco local
    final result = await _dbHelper.deleteLancamento(id);
    _syncService.syncNow();
    return result;
  }

  // ========== BUSCAR ==========
  Future<List<Map<String, dynamic>>> getAllLancamentos() async {
    return await _dbHelper.getAllLancamentos();
  }

  Future<List<Lancamento>> getAllLancamentosModel() async {
    final dados = await _dbHelper.getAllLancamentos();
    return dados.map((json) => Lancamento.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>?> getLancamentoById(int id) async {
    return await _dbHelper.getLancamentoById(id);
  }

  Future<Lancamento?> getLancamentoModelById(int id) async {
    final dados = await _dbHelper.getLancamentoById(id);
    if (dados == null) return null;
    return Lancamento.fromJson(dados);
  }

  Future<List<Lancamento>> getLancamentosByPeriodo(
      DateTime inicio, DateTime fim) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaLancamentos,
      where: 'date(data) BETWEEN date(?) AND date(?)',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'data DESC',
    );
    return resultados.map((json) => Lancamento.fromJson(json)).toList();
  }

  // ========== RESULT METHODS ==========
  Future<Result<int>> insertLancamentoResult(Lancamento lancamento) async {
    try {
      final id = await insertLancamentoModel(lancamento);
      return Result.success(id);
    } catch (e) {
      return Result.failure(
          'Erro ao adicionar lançamento: ${lancamento.descricao}\n$e');
    }
  }

  Future<Result<int>> updateLancamentoResult(Lancamento lancamento) async {
    try {
      if (lancamento.id == null) return Result.failure('ID não pode ser nulo');
      final result = await updateLancamento(lancamento.toJson());
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao atualizar: ${lancamento.descricao}\n$e');
    }
  }

  Future<Result<int>> deleteLancamentoResult(int id) async {
    try {
      final result = await deleteLancamento(id);
      return Result.success(result);
    } catch (e) {
      return Result.failure('Erro ao excluir ID: $id\n$e');
    }
  }

  Future<Result<List<Lancamento>>> getAllLancamentosModelResult() async {
    try {
      final dados = await _dbHelper.getAllLancamentos();
      final lancamentos =
          dados.map((json) => Lancamento.fromJson(json)).toList();
      return Result.success(lancamentos);
    } catch (e) {
      return Result.failure('Erro ao carregar: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> getResumoDoMesResult(
      DateTime mes) async {
    try {
      final primeiroDia = DateTime(mes.year, mes.month, 1);
      final ultimoDia = DateTime(mes.year, mes.month + 1, 0);
      final lancamentos = await getLancamentosByPeriodo(primeiroDia, ultimoDia);

      double receitas = 0, despesas = 0;
      final Map<String, double> gastosPorCategoria = {};

      for (var l in lancamentos) {
        if (l.tipo == TipoLancamento.receita) {
          receitas += l.valor;
        } else {
          despesas += l.valor;
          gastosPorCategoria[l.categoria] =
              (gastosPorCategoria[l.categoria] ?? 0) + l.valor;
        }
      }

      return Result.success({
        'receitas': receitas,
        'despesas': despesas,
        'saldo': receitas - despesas,
        'totalLancamentos': lancamentos.length,
        'gastosPorCategoria': Map.fromEntries(
            gastosPorCategoria.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value))),
      });
    } catch (e) {
      return Result.failure('Erro ao calcular resumo: $e');
    }
  }

  List<String> getCategoriasGastos() => AppCategories.gastos;
  List<String> getCategoriasReceitas() => AppCategories.receitas;
}
