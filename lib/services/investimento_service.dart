// lib/services/investimento_service.dart
import '../database/db_helper.dart';
import '../models/investimento_model.dart';

class InvestimentoService {
  final DBHelper _dbHelper = DBHelper();

  Future<void> salvar(Investimento investimento) async {
    await _dbHelper.insertInvestimento(investimento.toJson());
  }

  Future<List<Investimento>> listar() async {
    final dados = await _dbHelper.getAllInvestimentos();
    return dados.map((json) => Investimento.fromJson(json)).toList();
  }

  Future<void> atualizar(Investimento investimento) async {
    await _dbHelper.updateInvestimento(investimento.toJson());
  }

  Future<void> deletar(int id) async {
    await _dbHelper.deleteInvestimento(id);
  }
}
