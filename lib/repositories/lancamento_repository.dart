// lib/repositories/lancamento_repository.dart
import '../database/db_helper.dart';
import '../models/lancamento_model.dart';
import '../services/sync_service.dart';
import '../constants/app_categories.dart';
import '../utils/result.dart';
import '../utils/loading_mixin.dart'; // 🔥 NOVO

class LancamentoRepository with LoadingMixin {
  // 🔥 ADICIONAR MIXIN
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();

  static const String tabelaLancamentos = DBHelper.tabelaLancamentos;

  // ========== MÉTODOS CRUD COM SINCRONIZAÇÃO (VERSÃO LEGADO) ==========

  /// Insere um novo lançamento (LEGADO - mantido para compatibilidade)
  Future<int> insertLancamento(Map<String, dynamic> lancamento) async {
    lancamento['sync_status'] = 'pending';
    lancamento['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertLancamento(lancamento);
    _syncService.syncNow();
    return id;
  }

  /// Insere um lançamento a partir do modelo (LEGADO)
  Future<int> insertLancamentoModel(Lancamento lancamento) async {
    final json = lancamento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertLancamento(json);
    _syncService.syncNow();
    return id;
  }

  // ========== NOVOS MÉTODOS COM RESULT E LOADING (USANDO MIXIN) ==========

  /// Insere um lançamento com Result e Loading
  Future<Result<int>> insertLancamentoResult(Lancamento lancamento) async {
    return await withLoadingResult(() async {
      try {
        final json = lancamento.toJson();
        json['sync_status'] = 'pending';
        json['updated_at'] = DateTime.now().toIso8601String();

        final id = await _dbHelper.insertLancamento(json);
        _syncService.syncNow();
        return Result.success(id);
      } catch (e) {
        return Result.failure(
            '❌ Erro ao adicionar lançamento: ${lancamento.descricao}\n$e');
      }
    });
  }

  /// Atualiza um lançamento com Result e Loading
  Future<Result<int>> updateLancamentoResult(Lancamento lancamento) async {
    return await withLoadingResult(() async {
      try {
        if (lancamento.id == null) {
          return Result.failure('ID do lançamento não pode ser nulo');
        }

        final json = lancamento.toJson();
        json['sync_status'] = 'pending';
        json['updated_at'] = DateTime.now().toIso8601String();

        final result = await _dbHelper.updateLancamento(json);
        _syncService.syncNow();
        return Result.success(result);
      } catch (e) {
        return Result.failure(
            '❌ Erro ao atualizar lançamento: ${lancamento.descricao}\n$e');
      }
    });
  }

  /// Deleta um lançamento com Result e Loading
  Future<Result<int>> deleteLancamentoResult(int id) async {
    return await withLoadingResult(() async {
      try {
        final lancamento = await getLancamentoById(id);
        final remoteId = lancamento?['remote_id'] as String?;

        final result = await _dbHelper.deleteLancamento(id);

        if (remoteId != null && remoteId.isNotEmpty) {
          await _syncService.deleteAndSync('lancamentos', id, remoteId);
        }

        return Result.success(result);
      } catch (e) {
        return Result.failure('❌ Erro ao excluir lançamento ID: $id\n$e');
      }
    });
  }

  /// Busca todos os lançamentos como modelos com Result e Loading
  Future<Result<List<Lancamento>>> getAllLancamentosModelResult() async {
    return await withLoadingResult(() async {
      try {
        final dados = await _dbHelper.getAllLancamentos();
        final lancamentos =
            dados.map((json) => Lancamento.fromJson(json)).toList();
        return Result.success(lancamentos);
      } catch (e) {
        return Result.failure('❌ Erro ao carregar lançamentos: $e');
      }
    });
  }

  /// Busca lançamentos por período com Result e Loading
  Future<Result<List<Lancamento>>> getLancamentosByPeriodoResult(
    DateTime inicio,
    DateTime fim,
  ) async {
    return await withLoadingResult(() async {
      try {
        final db = await _dbHelper.database;
        final resultados = await db.query(
          tabelaLancamentos,
          where: 'date(data) BETWEEN date(?) AND date(?)',
          whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
          orderBy: 'data DESC',
        );
        final lancamentos =
            resultados.map((json) => Lancamento.fromJson(json)).toList();
        return Result.success(lancamentos);
      } catch (e) {
        return Result.failure('❌ Erro ao buscar lançamentos do período: $e');
      }
    });
  }

  /// Busca resumo do mês com Result e Loading
  Future<Result<Map<String, dynamic>>> getResumoDoMesResult(
      DateTime mes) async {
    return await withLoadingResult(() async {
      try {
        final primeiroDia = DateTime(mes.year, mes.month, 1);
        final ultimoDia = DateTime(mes.year, mes.month + 1, 0);

        final result =
            await getLancamentosByPeriodoResult(primeiroDia, ultimoDia);

        if (result.isFailure) {
          return Result.failure(result.error);
        }

        final lancamentos = result.data;
        double receitas = 0;
        double despesas = 0;
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

        final categoriasOrdenadas = Map.fromEntries(
            gastosPorCategoria.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)));

        return Result.success({
          'receitas': receitas,
          'despesas': despesas,
          'saldo': receitas - despesas,
          'totalLancamentos': lancamentos.length,
          'gastosPorCategoria': categoriasOrdenadas,
        });
      } catch (e) {
        return Result.failure('❌ Erro ao calcular resumo do mês: $e');
      }
    });
  }

  // ========== MÉTODOS DE BUSCA (LEGADO - mantidos) ==========

  /// Busca todos os lançamentos (LEGADO)
  Future<List<Map<String, dynamic>>> getAllLancamentos() async {
    return await _dbHelper.getAllLancamentos();
  }

  /// Busca lançamentos como modelos (LEGADO)
  Future<List<Lancamento>> getAllLancamentosModel() async {
    final dados = await _dbHelper.getAllLancamentos();
    return dados.map((json) => Lancamento.fromJson(json)).toList();
  }

  /// Busca um lançamento pelo ID
  Future<Map<String, dynamic>?> getLancamentoById(int id) async {
    return await _dbHelper.getLancamentoById(id);
  }

  /// Busca um lançamento como modelo
  Future<Lancamento?> getLancamentoModelById(int id) async {
    final dados = await _dbHelper.getLancamentoById(id);
    if (dados == null) return null;
    return Lancamento.fromJson(dados);
  }

  /// Busca lançamentos por período (LEGADO)
  Future<List<Lancamento>> getLancamentosByPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaLancamentos,
      where: 'date(data) BETWEEN date(?) AND date(?)',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'data DESC',
    );
    return resultados.map((json) => Lancamento.fromJson(json)).toList();
  }

  /// Busca lançamentos por tipo
  Future<List<Lancamento>> getLancamentosByTipo(TipoLancamento tipo) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaLancamentos,
      where: 'tipo = ?',
      whereArgs: [tipo.nome],
      orderBy: 'data DESC',
    );
    return resultados.map((json) => Lancamento.fromJson(json)).toList();
  }

  /// Busca lançamentos por categoria
  Future<List<Lancamento>> getLancamentosByCategoria(String categoria) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaLancamentos,
      where: 'categoria = ?',
      whereArgs: [categoria],
      orderBy: 'data DESC',
    );
    return resultados.map((json) => Lancamento.fromJson(json)).toList();
  }

  /// Busca lançamentos paginados
  Future<List<Map<String, dynamic>>> getLancamentosPaginados({
    required int pagina,
    int porPagina = 20,
    String? tipo,
    String? categoria,
    DateTime? dataInicio,
    DateTime? dataFim,
    OrdemLancamento ordem = OrdemLancamento.dataDesc,
  }) async {
    return await _dbHelper.getLancamentosPaginados(
      pagina: pagina,
      porPagina: porPagina,
      tipo: tipo,
      categoria: categoria,
      dataInicio: dataInicio,
      dataFim: dataFim,
      ordem: ordem,
    );
  }

  // ========== MÉTODOS DE ESTATÍSTICAS (LEGADO) ==========

  /// Calcula resumo do mês (LEGADO)
  Future<Map<String, dynamic>> getResumoDoMes(DateTime mes) async {
    final primeiroDia = DateTime(mes.year, mes.month, 1);
    final ultimoDia = DateTime(mes.year, mes.month + 1, 0);

    final lancamentos = await getLancamentosByPeriodo(primeiroDia, ultimoDia);

    double receitas = 0;
    double despesas = 0;
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

    final categoriasOrdenadas = Map.fromEntries(
        gastosPorCategoria.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)));

    return {
      'receitas': receitas,
      'despesas': despesas,
      'saldo': receitas - despesas,
      'totalLancamentos': lancamentos.length,
      'gastosPorCategoria': categoriasOrdenadas,
    };
  }

  /// Calcula estatísticas gerais
  Future<Map<String, dynamic>> getEstatisticasGerais() async {
    final lancamentos = await getAllLancamentosModel();

    double totalReceitas = 0;
    double totalDespesas = 0;
    final Map<String, double> gastosPorCategoria = {};
    final Map<String, double> receitasPorCategoria = {};

    for (var l in lancamentos) {
      if (l.tipo == TipoLancamento.receita) {
        totalReceitas += l.valor;
        receitasPorCategoria[l.categoria] =
            (receitasPorCategoria[l.categoria] ?? 0) + l.valor;
      } else {
        totalDespesas += l.valor;
        gastosPorCategoria[l.categoria] =
            (gastosPorCategoria[l.categoria] ?? 0) + l.valor;
      }
    }

    return {
      'totalReceitas': totalReceitas,
      'totalDespesas': totalDespesas,
      'saldoTotal': totalReceitas - totalDespesas,
      'gastosPorCategoria': gastosPorCategoria,
      'receitasPorCategoria': receitasPorCategoria,
      'totalLancamentos': lancamentos.length,
    };
  }

  /// Insere vários lançamentos em lote
  Future<void> insertLancamentosEmLote(
      List<Map<String, dynamic>> lancamentos) async {
    for (var l in lancamentos) {
      l['sync_status'] = 'pending';
      l['updated_at'] = DateTime.now().toIso8601String();
    }
    await _dbHelper.insertLancamentosEmLote(lancamentos);
    _syncService.syncNow();
  }

  /// Deleta vários lançamentos em lote
  Future<void> deleteEmLote(List<int> ids) async {
    await _dbHelper.deleteEmLote(tabelaLancamentos, ids);
  }

  // ========== MÉTODOS PARA CATEGORIAS ==========

  /// Retorna lista de categorias de gastos
  List<String> getCategoriasGastos() {
    return AppCategories.gastos;
  }

  /// Retorna lista de categorias de receitas
  List<String> getCategoriasReceitas() {
    return AppCategories.receitas;
  }
}
