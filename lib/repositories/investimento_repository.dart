import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/investimento_model.dart';
import '../database/db_helper.dart';

class InvestimentoRepository {
  final _supabase = Supabase.instance.client;
  final DBHelper _dbHelper = DBHelper();

  Future<List<Investimento>> getAllInvestimentosModel() async {
    try {
      final response = await _supabase
          .from('investimentos')
          .select()
          .order('ticker', ascending: true);

      return (response as List)
          .map((json) => Investimento.fromJson(json))
          .toList();
    } catch (e) {
      return await getAllInvestimentosLocal();
    }
  }

  Future<List<Investimento>> getAllInvestimentosLocal() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DBHelper.tabelaInvestimentos,
      orderBy: 'ticker ASC',
    );
    return results.map((json) => Investimento.fromJson(json)).toList();
  }

  Future<void> insertInvestimentoModel(Investimento investimento) async {
    try {
      await _supabase.from('investimentos').insert(investimento.toJson());
    } catch (e) {
      await _dbHelper.insert(
          DBHelper.tabelaInvestimentos, investimento.toJson());
    }
  }

  Future<void> updateInvestimentoModel(Investimento investimento) async {
    try {
      await _supabase
          .from('investimentos')
          .update(investimento.toJson())
          .eq('id', investimento.id ?? '');
    } catch (e) {
      if (investimento.id != null) {
        await _dbHelper.update(
          DBHelper.tabelaInvestimentos,
          investimento.toJson(),
          int.parse(investimento.id!),
        );
      }
    }
  }

  Future<void> deleteInvestimentoModel(String id) async {
    try {
      await _supabase.from('investimentos').delete().eq('id', id);
    } catch (e) {
      await _dbHelper.delete(DBHelper.tabelaInvestimentos, int.parse(id));
    }
  }
}
