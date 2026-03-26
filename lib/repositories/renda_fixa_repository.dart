// lib/repositories/renda_fixa_repository.dart

import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/renda_fixa_model.dart';
import '../services/sync_service.dart';

class RendaFixaRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();

  static const String tabelaRendaFixa = DBHelper.tabelaRendaFixa;

  /// Insere um novo investimento
  Future<int> insert(RendaFixaModel investimento) async {
    final json = investimento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertRendaFixa(json);
    _syncService.syncNow();
    return id;
  }

  /// Atualiza um investimento
  Future<int> update(RendaFixaModel investimento) async {
    if (investimento.id == null) throw Exception('ID não pode ser nulo');

    final json = investimento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.updateRendaFixa(json);
    _syncService.syncNow();
    return result;
  }

  /// Deleta um investimento
  Future<int> delete(int id) async {
    final investimento = await getById(id);
    final remoteId = investimento?.id.toString();

    final result = await _dbHelper.deleteRendaFixa(id);

    if (remoteId != null) {
      await _syncService.deleteAndSync('renda_fixa', id, remoteId);
    }

    return result;
  }

  /// Busca todos os investimentos de renda fixa
  Future<List<RendaFixaModel>> getAll() async {
    final dados = await _dbHelper.getAllRendaFixa();
    return dados
        .map((json) {
          try {
            return RendaFixaModel.fromJson(json);
          } catch (e) {
            debugPrint('❌ Erro ao converter renda fixa: $e');
            return null;
          }
        })
        .whereType<RendaFixaModel>()
        .toList();
  }

  /// Busca um investimento pelo ID
  Future<RendaFixaModel?> getById(int id) async {
    final dados = await _dbHelper.getRendaFixaById(id);
    if (dados == null) return null;
    return RendaFixaModel.fromJson(dados);
  }

  /// Calcula estatísticas
  Future<Map<String, dynamic>> getEstatisticas() async {
    final investimentos = await getAll();

    double totalAplicado = 0;
    double totalAtual = 0;

    for (var inv in investimentos) {
      totalAplicado += inv.valorAplicado;
      totalAtual += inv.valorFinal ?? inv.valorAplicado;
    }

    return {
      'totalAplicado': totalAplicado,
      'totalAtual': totalAtual,
      'rendimentoTotal': totalAtual - totalAplicado,
      'quantidade': investimentos.length,
    };
  }

  /// Busca investimentos ativos
  Future<List<RendaFixaModel>> getAtivos() async {
    final todos = await getAll();
    final hoje = DateTime.now();
    return todos.where((inv) => inv.dataVencimento.isAfter(hoje)).toList();
  }

  /// Busca investimentos vencidos
  Future<List<RendaFixaModel>> getVencidos() async {
    final todos = await getAll();
    final hoje = DateTime.now();
    return todos.where((inv) => inv.dataVencimento.isBefore(hoje)).toList();
  }
}
