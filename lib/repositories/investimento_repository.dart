// lib/repositories/investimento_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/investimento_model.dart';
import '../database/db_helper.dart';

class InvestimentoRepository {
  final _supabase = Supabase.instance.client;
  final DBHelper _dbHelper = DBHelper();

  Future<List<Investimento>> getAllInvestimentosModel() async {
    try {
      final response = await _supabase
          .from('investments') // ✅ TROCADO PARA investments
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
      await _supabase
          .from('investments')
          .insert(investimento.toJson()); // ✅ TROCADO
    } catch (e) {
      await _dbHelper.insert(
          DBHelper.tabelaInvestimentos, investimento.toJson());
    }
  }

  Future<void> updateInvestimentoModel(Investimento investimento) async {
    try {
      await _supabase
          .from('investments') // ✅ TROCADO
          .update(investimento.toJson())
          .eq('id', investimento.id ?? '');
    } catch (e) {
      if (investimento.id != null) {
        await _dbHelper.update(
          DBHelper.tabelaInvestimentos,
          investimento.toJson(),
          investimento.id!,
        );
      }
    }
  }

  Future<void> deleteInvestimentoModel(String id) async {
    try {
      await _supabase.from('investments').delete().eq('id', id); // ✅ TROCADO
    } catch (e) {
      await _dbHelper.delete(DBHelper.tabelaInvestimentos, id);
    }
  }
}
