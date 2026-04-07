// lib/services/movimentacao_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/movimentacao_model.dart';
import '../database/db_helper.dart';

class MovimentacaoService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DBHelper _dbHelper = DBHelper();

  static const String tabela = 'movimentacoes_investimentos';

  // Inserir movimentação
  Future<void> inserirMovimentacao(Movimentacao movimentacao) async {
    try {
      await _supabase.from(tabela).insert(movimentacao.toJson());
    } catch (e) {
      final db = await _dbHelper.database;
      await db.insert(tabela, movimentacao.toJson());
    }
  }

  // Buscar movimentações por ticker
  Future<List<Movimentacao>> getMovimentacoesByTicker(String ticker) async {
    try {
      final response = await _supabase
          .from(tabela)
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .eq('ticker', ticker.toUpperCase())
          .order('data', ascending: false);

      return (response as List)
          .map((json) => Movimentacao.fromJson(json))
          .toList();
    } catch (e) {
      final db = await _dbHelper.database;
      final results = await db.query(
        tabela,
        where: 'ticker = ?',
        whereArgs: [ticker.toUpperCase()],
        orderBy: 'data DESC',
      );
      return results.map((json) => Movimentacao.fromJson(json)).toList();
    }
  }

  // Buscar últimas movimentações (para dashboard)
  Future<List<Movimentacao>> getUltimasMovimentacoes({int limit = 5}) async {
    try {
      final response = await _supabase
          .from(tabela)
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('data', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Movimentacao.fromJson(json))
          .toList();
    } catch (e) {
      final db = await _dbHelper.database;
      final results = await db.query(
        tabela,
        orderBy: 'data DESC',
        limit: limit,
      );
      return results.map((json) => Movimentacao.fromJson(json)).toList();
    }
  }

  // Calcular posição atual (quantidade, preço médio)
  Future<Map<String, dynamic>> calcularPosicao(String ticker) async {
    final movimentacoes = await getMovimentacoesByTicker(ticker);

    double quantidade = 0;
    double totalGasto = 0;
    double totalTaxas = 0;

    for (var m in movimentacoes) {
      if (m.isCompra) {
        quantidade += m.quantidade;
        totalGasto += m.quantidade * m.preco;
        totalTaxas += m.taxa;
      } else {
        quantidade -= m.quantidade;
      }
    }

    final precoMedio =
        quantidade > 0 ? (totalGasto + totalTaxas) / quantidade : 0;

    return {
      'quantidade': quantidade,
      'preco_medio': precoMedio,
      'total_investido': totalGasto + totalTaxas,
    };
  }
}

