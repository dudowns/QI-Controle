// lib/repositories/investimento_repository.dart

import '../database/db_helper.dart';
import '../models/investimento_model.dart';
import '../services/sync_service.dart';

class InvestimentoRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();

  static const String tabelaInvestimentos = DBHelper.tabelaInvestimentos;

  // ========== MÉTODOS CRUD COM SINCRONIZAÇÃO ==========

  /// Insere um novo investimento
  Future<int> insertInvestimento(Map<String, dynamic> investimento) async {
    investimento['sync_status'] = 'pending';
    investimento['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertInvestimento(investimento);
    _syncService.syncNow();
    return id;
  }

  /// Insere um investimento a partir do modelo
  Future<int> insertInvestimentoModel(Investimento investimento) async {
    final json = investimento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertInvestimento(json);
    _syncService.syncNow();
    return id;
  }

  /// Atualiza um investimento
  Future<int> updateInvestimento(Map<String, dynamic> investimento) async {
    investimento['sync_status'] = 'pending';
    investimento['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.updateInvestimento(investimento);
    _syncService.syncNow();
    return result;
  }

  /// Atualiza um investimento a partir do modelo
  Future<int> updateInvestimentoModel(Investimento investimento) async {
    if (investimento.id == null) throw Exception('ID não pode ser nulo');

    final json = investimento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.updateInvestimento(json);
    _syncService.syncNow();
    return result;
  }

  /// Deleta um investimento
  Future<int> deleteInvestimento(int id) async {
    final investimento = await getInvestimentoById(id);
    final remoteId = investimento?['remote_id'] as String?;

    final result = await _dbHelper.deleteInvestimento(id);

    if (remoteId != null && remoteId.isNotEmpty) {
      await _syncService.deleteAndSync('investimentos', id, remoteId);
    }

    return result;
  }

  /// Atualiza preço atual
  Future<int> updatePrecoAtual(int id, double preco) async {
    final result = await _dbHelper.updatePrecoAtual(id, preco);
    await _syncService.markAsPending('investimentos', id);
    return result;
  }

  // ========== MÉTODOS DE BUSCA (SEM ALTERAÇÃO) ==========

  /// Busca todos os investimentos
  Future<List<Map<String, dynamic>>> getAllInvestimentos() async {
    return await _dbHelper.getAllInvestimentos();
  }

  /// Busca investimentos como modelos
  Future<List<Investimento>> getAllInvestimentosModel() async {
    final dados = await _dbHelper.getAllInvestimentos();
    return dados.map((json) => Investimento.fromJson(json)).toList();
  }

  /// Busca um investimento pelo ID
  Future<Map<String, dynamic>?> getInvestimentoById(int id) async {
    return await _dbHelper.getInvestimentoById(id);
  }

  /// Busca um investimento como modelo
  Future<Investimento?> getInvestimentoModelById(int id) async {
    final dados = await _dbHelper.getInvestimentoById(id);
    if (dados == null) return null;
    return Investimento.fromJson(dados);
  }

  // ========== MÉTODOS ESPECÍFICOS (SEM ALTERAÇÃO) ==========

  /// Busca investimentos por tipo
  Future<List<Investimento>> getInvestimentosByTipo(String tipo) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaInvestimentos,
      where: 'tipo = ?',
      whereArgs: [tipo],
    );
    return resultados.map((json) => Investimento.fromJson(json)).toList();
  }

  /// Busca investimentos por ticker
  Future<List<Investimento>> getInvestimentosByTicker(String ticker) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaInvestimentos,
      where: 'ticker = ?',
      whereArgs: [ticker.toUpperCase()],
      orderBy: 'data_compra DESC',
    );
    return resultados.map((json) => Investimento.fromJson(json)).toList();
  }

  /// Calcula estatísticas da carteira
  Future<Map<String, dynamic>> getEstatisticasCarteira() async {
    final investimentos = await getAllInvestimentosModel();

    double patrimonioTotal = 0;
    double valorInvestido = 0;
    final Map<String, double> valorPorTipo = {};

    for (var inv in investimentos) {
      patrimonioTotal += inv.valorAtual;
      valorInvestido += inv.valorInvestido;

      valorPorTipo[inv.tipo.nome] =
          (valorPorTipo[inv.tipo.nome] ?? 0) + inv.valorAtual;
    }

    return {
      'patrimonioTotal': patrimonioTotal,
      'valorInvestido': valorInvestido,
      'ganhoCapital': patrimonioTotal - valorInvestido,
      'percentualGanho': valorInvestido > 0
          ? ((patrimonioTotal - valorInvestido) / valorInvestido) * 100
          : 0,
      'valorPorTipo': valorPorTipo,
      'totalAtivos': investimentos.length,
    };
  }

  /// Consolida investimentos iguais
  List<Investimento> consolidarInvestimentos(List<Investimento> lista) {
    final Map<String, List<Investimento>> agrupados = {};

    for (var inv in lista) {
      if (!agrupados.containsKey(inv.ticker)) {
        agrupados[inv.ticker] = [];
      }
      agrupados[inv.ticker]!.add(inv);
    }

    final List<Investimento> consolidados = [];

    for (var entry in agrupados.entries) {
      final listaDoTicker = entry.value;

      if (listaDoTicker.length == 1) {
        consolidados.add(listaDoTicker.first);
      } else {
        double quantidadeTotal = 0;
        double valorTotalInvestido = 0;
        double? precoAtual;
        DateTime dataCompraMaisRecente = listaDoTicker.first.dataCompra;

        for (var inv in listaDoTicker) {
          quantidadeTotal += inv.quantidade;
          valorTotalInvestido += inv.valorInvestido;

          if (inv.precoAtual != null && inv.precoAtual! > 0) {
            precoAtual = inv.precoAtual;
          }

          if (inv.dataCompra.isAfter(dataCompraMaisRecente)) {
            dataCompraMaisRecente = inv.dataCompra;
          }
        }

        final precoMedioConsolidado = valorTotalInvestido / quantidadeTotal;

        consolidados.add(
          Investimento(
            ticker: entry.key,
            tipo: listaDoTicker.first.tipo,
            quantidade: quantidadeTotal,
            precoMedio: precoMedioConsolidado,
            precoAtual: precoAtual,
            dataCompra: dataCompraMaisRecente,
          ),
        );
      }
    }

    return consolidados;
  }

  /// Ordena investimentos
  List<Investimento> ordenarInvestimentos(
    List<Investimento> lista, {
    required String criterio,
    bool crescente = false,
  }) {
    final sorted = List<Investimento>.from(lista);

    switch (criterio) {
      case 'ticker':
        sorted.sort((a, b) => a.ticker.compareTo(b.ticker));
        break;
      case 'valor':
        sorted.sort((a, b) => b.valorAtual.compareTo(a.valorAtual));
        break;
      case 'rentabilidade':
        sorted.sort(
            (a, b) => b.variacaoPercentual.compareTo(a.variacaoPercentual));
        break;
      case 'quantidade':
        sorted.sort((a, b) => b.quantidade.compareTo(a.quantidade));
        break;
    }

    if (crescente) {
      return sorted.reversed.toList();
    }
    return sorted;
  }

  /// Agrupa investimentos por tipo
  Map<String, List<Investimento>> agruparPorTipo(List<Investimento> lista) {
    final Map<String, List<Investimento>> agrupado = {};

    for (var inv in lista) {
      final tipo = inv.tipo.nome;
      if (!agrupado.containsKey(tipo)) {
        agrupado[tipo] = [];
      }
      agrupado[tipo]!.add(inv);
    }

    return agrupado;
  }
}
