// lib/repositories/provento_repository.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/provento_model.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';

class ProventoRepository {
  final DBHelper _dbHelper = DBHelper();
  final SyncService _syncService = SyncService();

  static const String tabelaProventos = DBHelper.tabelaProventos;

  // ========== MÉTODOS CRUD COM SINCRONIZAÇÃO ==========

  /// Insere um novo provento
  Future<int> insertProvento(Map<String, dynamic> provento) async {
    provento['sync_status'] = 'pending';
    provento['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertProvento(provento);
    _syncService.syncNow();
    return id;
  }

  /// Insere um provento a partir do modelo
  Future<int> insert(Provento provento) async {
    final json = provento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final id = await _dbHelper.insertProvento(json);
    _syncService.syncNow();
    return id;
  }

  /// Atualiza um provento
  Future<int> updateProvento(Map<String, dynamic> provento) async {
    provento['sync_status'] = 'pending';
    provento['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.updateProvento(provento);
    _syncService.syncNow();
    return result;
  }

  /// Atualiza um provento a partir do modelo
  Future<int> update(Provento provento) async {
    if (provento.id == null) throw Exception('ID não pode ser nulo');

    final json = provento.toJson();
    json['sync_status'] = 'pending';
    json['updated_at'] = DateTime.now().toIso8601String();

    final result = await _dbHelper.updateProvento(json);
    _syncService.syncNow();
    return result;
  }

  /// Deleta um provento
  Future<int> delete(int id) async {
    final provento = await getProventoById(id);
    final remoteId = provento?['remote_id'] as String?;

    final result = await _dbHelper.deleteProvento(id);

    if (remoteId != null && remoteId.isNotEmpty) {
      await _syncService.deleteAndSync('proventos', id, remoteId);
    }

    return result;
  }

  // ========== MÉTODOS DE BUSCA (SEM ALTERAÇÃO) ==========

  /// Busca todos os proventos
  Future<List<Map<String, dynamic>>> getAllProventos() async {
    return await _dbHelper.getAllProventos();
  }

  /// Busca proventos como modelos
  Future<List<Provento>> getAll() async {
    final dados = await _dbHelper.getAllProventos();
    return dados.map((json) => Provento.fromJson(json)).toList();
  }

  /// Busca um provento pelo ID
  Future<Map<String, dynamic>?> getProventoById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      tabelaProventos,
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Busca um provento como modelo
  Future<Provento?> getById(int id) async {
    final dados = await getProventoById(id);
    if (dados == null) return null;
    return Provento.fromJson(dados);
  }

  // ========== MÉTODOS ESPECÍFICOS (SEM ALTERAÇÃO) ==========

  /// Busca proventos futuros
  Future<List<Provento>> getProventosFuturos() async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaProventos,
      where: 'data_pagamento > ?',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'data_pagamento ASC',
    );
    return resultados.map((json) => Provento.fromJson(json)).toList();
  }

  /// Busca proventos por ticker
  Future<List<Provento>> getByTicker(String ticker) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaProventos,
      where: 'ticker = ?',
      whereArgs: [ticker.toUpperCase()],
      orderBy: 'data_pagamento DESC',
    );
    return resultados.map((json) => Provento.fromJson(json)).toList();
  }

  /// Busca proventos por período
  Future<List<Provento>> getByPeriodo(DateTime inicio, DateTime fim) async {
    final db = await _dbHelper.database;
    final resultados = await db.query(
      tabelaProventos,
      where: 'date(data_pagamento) BETWEEN date(?) AND date(?)',
      whereArgs: [inicio.toIso8601String(), fim.toIso8601String()],
      orderBy: 'data_pagamento DESC',
    );
    return resultados.map((json) => Provento.fromJson(json)).toList();
  }

  /// Calcula estatísticas
  Future<Map<String, dynamic>> getEstatisticas() async {
    final todos = await getAll();
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);
    final inicioAno = DateTime(agora.year, 1, 1);
    final umAnoAtras = DateTime(agora.year - 1, agora.month, agora.day);

    double total = 0;
    double mes = 0;
    double ano = 0;
    double ultimos12Meses = 0;
    final Map<String, double> porTicker = {};
    final Map<String, double> porMes = {};

    for (int i = 5; i >= 0; i--) {
      final data = DateTime(agora.year, agora.month - i, 1);
      final chave = DateFormat('MM/yyyy').format(data);
      porMes[chave] = 0;
    }

    for (var p in todos) {
      total += p.totalRecebido;

      if (p.dataPagamento.isAfter(inicioMes) ||
          p.dataPagamento.isAtSameMomentAs(inicioMes)) {
        mes += p.totalRecebido;
      }

      if (p.dataPagamento.isAfter(inicioAno) ||
          p.dataPagamento.isAtSameMomentAs(inicioAno)) {
        ano += p.totalRecebido;
      }

      if (p.dataPagamento.isAfter(umAnoAtras)) {
        ultimos12Meses += p.totalRecebido;
      }

      porTicker[p.ticker] = (porTicker[p.ticker] ?? 0) + p.totalRecebido;

      final chaveMes = DateFormat('MM/yyyy').format(p.dataPagamento);
      porMes[chaveMes] = (porMes[chaveMes] ?? 0) + p.totalRecebido;
    }

    return {
      'total': total,
      'mes': mes,
      'ano': ano,
      'ultimos12Meses': ultimos12Meses,
      'porTicker': porTicker,
      'porMes': porMes,
    };
  }

  /// Agenda notificações para proventos futuros
  Future<void> agendarNotificacoes() async {
    final futuros = await getProventosFuturos();
    for (var p in futuros) {
      if (p.id != null) {
        try {
          await NotificationService().scheduleProventoNotification(
            ticker: p.ticker,
            dataPagamento: p.dataPagamento,
            valor: p.valorPorCota,
            id: p.id!,
          );
        } catch (e) {
          debugPrint('⚠️ Erro ao agendar notificação para ${p.ticker}: $e');
        }
      }
    }
  }
}
