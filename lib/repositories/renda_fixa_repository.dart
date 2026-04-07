import '../services/logger_service.dart';
// lib/repositories/renda_fixa_repository.dart
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/renda_fixa_model.dart';
import '../services/sync_service.dart';
import '../utils/result.dart';
import '../utils/loading_mixin.dart';

class RendaFixaRepository with LoadingMixin {
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
            LoggerService.info('❌ Erro ao converter renda fixa: $e');
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

  // ========== MÉTODOS COM RESULT ==========

  Future<Result<List<RendaFixaModel>>> getAllRendaFixaResult() async {
    return await withLoadingResult(() async {
      try {
        final dados = await _dbHelper.getAllRendaFixa();
        final investimentos =
            dados.map((json) => RendaFixaModel.fromJson(json)).toList();
        return Result.success(investimentos);
      } catch (e) {
        return Result.failure('❌ Erro ao carregar renda fixa: $e');
      }
    });
  }

  Future<Result<RendaFixaModel?>> getRendaFixaByIdResult(int id) async {
    return await withLoadingResult(() async {
      try {
        final dados = await _dbHelper.getRendaFixaById(id);
        if (dados == null) return Result.success(null);
        return Result.success(RendaFixaModel.fromJson(dados));
      } catch (e) {
        return Result.failure('❌ Erro ao buscar renda fixa ID: $id\n$e');
      }
    });
  }

  Future<Result<int>> insertRendaFixaResult(RendaFixaModel investimento) async {
    return await withLoadingResult(() async {
      try {
        final json = investimento.toJson();
        json['sync_status'] = 'pending';
        json['updated_at'] = DateTime.now().toIso8601String();

        final id = await _dbHelper.insertRendaFixa(json);
        _syncService.syncNow();
        return Result.success(id);
      } catch (e) {
        return Result.failure(
            '❌ Erro ao adicionar investimento: ${investimento.nome}\n$e');
      }
    });
  }

  Future<Result<int>> updateRendaFixaResult(RendaFixaModel investimento) async {
    return await withLoadingResult(() async {
      try {
        if (investimento.id == null) {
          return Result.failure('ID do investimento não pode ser nulo');
        }

        final json = investimento.toJson();
        json['sync_status'] = 'pending';
        json['updated_at'] = DateTime.now().toIso8601String();

        final result = await _dbHelper.updateRendaFixa(json);
        _syncService.syncNow();
        return Result.success(result);
      } catch (e) {
        return Result.failure(
            '❌ Erro ao atualizar investimento: ${investimento.nome}\n$e');
      }
    });
  }

  Future<Result<int>> deleteRendaFixaResult(int id) async {
    return await withLoadingResult(() async {
      try {
        final investimento = await getRendaFixaByIdResult(id);
        final remoteId =
            investimento.isSuccess ? investimento.data?.id?.toString() : null;

        final result = await _dbHelper.deleteRendaFixa(id);

        if (remoteId != null && remoteId.isNotEmpty) {
          await _syncService.deleteAndSync('renda_fixa', id, remoteId);
        }

        return Result.success(result);
      } catch (e) {
        return Result.failure('❌ Erro ao excluir renda fixa ID: $id\n$e');
      }
    });
  }

  Future<Result<Map<String, dynamic>>> getEstatisticasRendaFixaResult() async {
    return await withLoadingResult(() async {
      try {
        final result = await getAllRendaFixaResult();
        if (result.isFailure) return Result.failure(result.error);

        final investimentos = result.data;
        double totalAplicado = 0;
        double totalAtual = 0;

        for (var inv in investimentos) {
          totalAplicado += inv.valorAplicado;
          totalAtual += inv.valorFinal ?? inv.valorAplicado;
        }

        return Result.success({
          'totalAplicado': totalAplicado,
          'totalAtual': totalAtual,
          'rendimentoTotal': totalAtual - totalAplicado,
          'quantidade': investimentos.length,
        });
      } catch (e) {
        return Result.failure('❌ Erro ao calcular estatísticas: $e');
      }
    });
  }

  Future<Result<List<RendaFixaModel>>> getRendaFixaAtivosResult() async {
    return await withLoadingResult(() async {
      try {
        final result = await getAllRendaFixaResult();
        if (result.isFailure) return Result.failure(result.error);

        final hoje = DateTime.now();
        final ativos = result.data
            .where((inv) => inv.dataVencimento.isAfter(hoje))
            .toList();
        return Result.success(ativos);
      } catch (e) {
        return Result.failure('❌ Erro ao buscar renda fixa ativos: $e');
      }
    });
  }

  Future<Result<List<RendaFixaModel>>> getRendaFixaVencidosResult() async {
    return await withLoadingResult(() async {
      try {
        final result = await getAllRendaFixaResult();
        if (result.isFailure) return Result.failure(result.error);

        final hoje = DateTime.now();
        final vencidos = result.data
            .where((inv) => inv.dataVencimento.isBefore(hoje))
            .toList();
        return Result.success(vencidos);
      } catch (e) {
        return Result.failure('❌ Erro ao buscar renda fixa vencidos: $e');
      }
    });
  }

  // ========== MÉTODOS AUXILIARES ==========

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

  Future<List<RendaFixaModel>> getAtivos() async {
    final todos = await getAll();
    final hoje = DateTime.now();
    return todos.where((inv) => inv.dataVencimento.isAfter(hoje)).toList();
  }

  Future<List<RendaFixaModel>> getVencidos() async {
    final todos = await getAll();
    final hoje = DateTime.now();
    return todos.where((inv) => inv.dataVencimento.isBefore(hoje)).toList();
  }
}

