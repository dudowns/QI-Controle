import '../services/logger_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';
import 'performance_service.dart';

class ExportService {
  final DBHelper db = DBHelper();

  // Formatadores
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _fileDateFormat = DateFormat('yyyyMMdd_HHmmss');

  // ========== MÉTODOS DE UTILIDADE ==========

  Future<String?> _getExportPath(String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/exports';
      final dir = Directory(path);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
        LoggerService.info('📁 Pasta de exportação criada: $path');
      }

      return '$path/$fileName';
    } catch (e) {
      LoggerService.error('Erro ao criar pasta de exportação', e);
      return null;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return _dateFormat.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatNumber(double? value) {
    if (value == null) return '0,00';
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  // ========== EXPORTAÇÃO PARA CSV ==========

  Future<File?> exportLancamentosToCsv({bool share = true}) async {
    PerformanceService.start('export_lancamentos_csv');

    try {
      LoggerService.info('📊 Exportando lançamentos para CSV...');

      final lancamentos = await db.getAllLancamentos();

      List<List<String>> rows = [
        [
          'ID',
          'Descrição',
          'Tipo',
          'Categoria',
          'Valor',
          'Data',
          'Observação',
          'Criado em'
        ]
      ];

      double totalReceitas = 0;
      double totalDespesas = 0;

      for (var item in lancamentos) {
        final valor = (item['valor'] ?? 0).toDouble();
        final tipo = item['tipo'] ?? '';

        if (tipo == 'receita') {
          totalReceitas += valor;
        } else {
          totalDespesas += valor;
        }

        rows.add([
          item['id'].toString(),
          item['descricao'] ?? '',
          tipo == 'receita' ? 'Receita' : 'Despesa',
          item['categoria'] ?? '',
          _formatNumber(valor),
          _formatDate(item['data']),
          item['observacao'] ?? '',
          _formatDate(item['created_at']),
        ]);
      }

      rows.add([]);
      rows.add([
        '',
        '',
        '',
        'TOTAL RECEITAS:',
        _formatNumber(totalReceitas),
        '',
        '',
        ''
      ]);
      rows.add([
        '',
        '',
        '',
        'TOTAL DESPESAS:',
        _formatNumber(totalDespesas),
        '',
        '',
        ''
      ]);
      rows.add([
        '',
        '',
        '',
        'SALDO:',
        _formatNumber(totalReceitas - totalDespesas),
        '',
        '',
        ''
      ]);
      rows.add([]);
      rows.add([
        'Exportado em:',
        _dateFormat.format(DateTime.now()),
        '',
        '',
        '',
        '',
        '',
        ''
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      final fileName =
          'lancamentos_${_fileDateFormat.format(DateTime.now())}.csv';
      final path = await _getExportPath(fileName);

      if (path != null) {
        final file = File(path);
        await file.writeAsString(csv, encoding: utf8);

        LoggerService.success(
            '✅ ${lancamentos.length} lançamentos exportados: $fileName');
        PerformanceService.stop('export_lancamentos_csv');

        if (share) {
          await Share.shareXFiles([XFile(path)],
              text: '📊 Exportação de Lançamentos - Controle Financeiro');
        }

        return file;
      }

      PerformanceService.stop('export_lancamentos_csv');
      return null;
    } catch (e) {
      LoggerService.error('Erro ao exportar lançamentos', e);
      PerformanceService.stop('export_lancamentos_csv');
      throw Exception('Erro ao exportar lançamentos: $e');
    }
  }

  Future<File?> exportInvestimentosToCsv({bool share = true}) async {
    PerformanceService.start('export_investimentos_csv');

    try {
      LoggerService.info('📊 Exportando investimentos para CSV...');

      final investimentos = await db.getAllInvestimentos();

      List<List<String>> rows = [
        [
          'ID',
          'Ticker',
          'Tipo',
          'Quantidade',
          'Preço Médio',
          'Preço Atual',
          'Valor Total',
          'Data Compra',
          'Setor'
        ]
      ];

      double valorTotal = 0;

      for (var item in investimentos) {
        final quantidade = (item['quantidade'] ?? 0).toDouble();
        final precoAtual = (item['preco_atual'] ?? 0).toDouble();
        final total = quantidade * precoAtual;
        valorTotal += total;

        rows.add([
          item['id'].toString(),
          item['ticker'] ?? '',
          item['tipo'] ?? '',
          _formatNumber(quantidade),
          _formatNumber(item['preco_medio'] ?? 0),
          _formatNumber(precoAtual),
          _formatNumber(total),
          _formatDate(item['data_compra']),
          item['setor'] ?? '',
        ]);
      }

      rows.add([]);
      rows.add([
        '',
        '',
        '',
        '',
        '',
        'VALOR TOTAL DA CARTEIRA:',
        _formatNumber(valorTotal),
        '',
        ''
      ]);
      rows.add([]);
      rows.add([
        'Exportado em:',
        _dateFormat.format(DateTime.now()),
        '',
        '',
        '',
        '',
        '',
        '',
        ''
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      final fileName =
          'investimentos_${_fileDateFormat.format(DateTime.now())}.csv';
      final path = await _getExportPath(fileName);

      if (path != null) {
        final file = File(path);
        await file.writeAsString(csv, encoding: utf8);

        LoggerService.success(
            '✅ ${investimentos.length} investimentos exportados: $fileName');
        PerformanceService.stop('export_investimentos_csv');

        if (share) {
          await Share.shareXFiles([XFile(path)],
              text: '📈 Exportação de Investimentos - Controle Financeiro');
        }

        return file;
      }

      PerformanceService.stop('export_investimentos_csv');
      return null;
    } catch (e) {
      LoggerService.error('Erro ao exportar investimentos', e);
      PerformanceService.stop('export_investimentos_csv');
      throw Exception('Erro ao exportar investimentos: $e');
    }
  }

  Future<File?> exportMetasToCsv({bool share = true}) async {
    PerformanceService.start('export_metas_csv');

    try {
      LoggerService.info('🎯 Exportando metas para CSV...');

      final metas = await db.getAllMetas();

      List<List<String>> rows = [
        [
          'ID',
          'Título',
          'Valor Objetivo',
          'Valor Atual',
          'Progresso',
          'Data Início',
          'Data Fim',
          'Status'
        ]
      ];

      for (var item in metas) {
        final valorObjetivo = (item['valor_objetivo'] ?? 0).toDouble();
        final valorAtual = (item['valor_atual'] ?? 0).toDouble();
        final progresso =
            valorObjetivo > 0 ? (valorAtual / valorObjetivo * 100) : 0;

        rows.add([
          item['id'].toString(),
          item['titulo'] ?? '',
          _formatNumber(valorObjetivo),
          _formatNumber(valorAtual),
          '${progresso.toStringAsFixed(1)}%',
          _formatDate(item['data_inicio']),
          _formatDate(item['data_fim']),
          (item['concluida'] == 1) ? 'Concluída' : 'Em andamento',
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final fileName = 'metas_${_fileDateFormat.format(DateTime.now())}.csv';
      final path = await _getExportPath(fileName);

      if (path != null) {
        final file = File(path);
        await file.writeAsString(csv, encoding: utf8);

        LoggerService.success('✅ ${metas.length} metas exportadas: $fileName');
        PerformanceService.stop('export_metas_csv');

        if (share) {
          await Share.shareXFiles([XFile(path)],
              text: '🎯 Exportação de Metas - Controle Financeiro');
        }

        return file;
      }

      PerformanceService.stop('export_metas_csv');
      return null;
    } catch (e) {
      LoggerService.error('Erro ao exportar metas', e);
      PerformanceService.stop('export_metas_csv');
      throw Exception('Erro ao exportar metas: $e');
    }
  }

  Future<File?> exportProventosToCsv({bool share = true}) async {
    PerformanceService.start('export_proventos_csv');

    try {
      LoggerService.info('💰 Exportando proventos para CSV...');

      final proventos = await db.getAllProventos();

      List<List<String>> rows = [
        [
          'ID',
          'Ticker',
          'Valor por Cota',
          'Quantidade',
          'Total Recebido',
          'Data Pagamento',
          'Tipo'
        ]
      ];

      double totalProventos = 0;

      for (var item in proventos) {
        final total = (item['total_recebido'] ?? 0).toDouble();
        totalProventos += total;

        rows.add([
          item['id'].toString(),
          item['ticker'] ?? '',
          _formatNumber(item['valor_por_cota'] ?? 0),
          _formatNumber(item['quantidade'] ?? 1),
          _formatNumber(total),
          _formatDate(item['data_pagamento']),
          item['tipo_provento'] ?? 'Dividendo',
        ]);
      }

      rows.add([]);
      rows.add([
        '',
        '',
        '',
        'TOTAL RECEBIDO:',
        _formatNumber(totalProventos),
        '',
        ''
      ]);
      rows.add([]);
      rows.add([
        'Exportado em:',
        _dateFormat.format(DateTime.now()),
        '',
        '',
        '',
        '',
        ''
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      final fileName =
          'proventos_${_fileDateFormat.format(DateTime.now())}.csv';
      final path = await _getExportPath(fileName);

      if (path != null) {
        final file = File(path);
        await file.writeAsString(csv, encoding: utf8);

        LoggerService.success(
            '✅ ${proventos.length} proventos exportados: $fileName');
        PerformanceService.stop('export_proventos_csv');

        if (share) {
          await Share.shareXFiles([XFile(path)],
              text: '💰 Exportação de Proventos - Controle Financeiro');
        }

        return file;
      }

      PerformanceService.stop('export_proventos_csv');
      return null;
    } catch (e) {
      LoggerService.error('Erro ao exportar proventos', e);
      PerformanceService.stop('export_proventos_csv');
      throw Exception('Erro ao exportar proventos: $e');
    }
  }

  // ========== EXPORTAÇÃO PARA JSON ==========

  Future<File?> exportAllToJson({bool share = true}) async {
    PerformanceService.start('export_all_json');

    try {
      LoggerService.info('📦 Exportando todos os dados para JSON...');

      final lancamentos = await db.getAllLancamentos();
      final investimentos = await db.getAllInvestimentos();
      final metas = await db.getAllMetas();
      final proventos = await db.getAllProventos();

      final data = {
        'exportado_em': DateTime.now().toIso8601String(),
        'versao_app': '2.0.0',
        'dados': {
          'lancamentos': lancamentos,
          'investimentos': investimentos,
          'metas': metas,
          'proventos': proventos,
        },
        'resumo': {
          'total_lancamentos': lancamentos.length,
          'total_investimentos': investimentos.length,
          'total_metas': metas.length,
          'total_proventos': proventos.length,
        }
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final fileName =
          'backup_completo_${_fileDateFormat.format(DateTime.now())}.json';
      final path = await _getExportPath(fileName);

      if (path != null) {
        final file = File(path);
        await file.writeAsString(jsonString, encoding: utf8);

        LoggerService.success('✅ Backup JSON criado: $fileName');
        PerformanceService.stop('export_all_json');

        if (share) {
          await Share.shareXFiles([XFile(path)],
              text: '📦 Backup Completo - Controle Financeiro');
        }

        return file;
      }

      PerformanceService.stop('export_all_json');
      return null;
    } catch (e) {
      LoggerService.error('Erro ao exportar JSON', e);
      PerformanceService.stop('export_all_json');
      throw Exception('Erro ao exportar JSON: $e');
    }
  }

  // ========== EXPORTAÇÃO COMPLETA ==========

  Future<List<File>> exportAllFiles() async {
    PerformanceService.start('export_all_files');

    try {
      LoggerService.info('📦 Exportando todos os dados...');

      final files = <File>[];

      final lancamentosFile = await exportLancamentosToCsv(share: false);
      if (lancamentosFile != null) files.add(lancamentosFile);

      final investimentosFile = await exportInvestimentosToCsv(share: false);
      if (investimentosFile != null) files.add(investimentosFile);

      final metasFile = await exportMetasToCsv(share: false);
      if (metasFile != null) files.add(metasFile);

      final proventosFile = await exportProventosToCsv(share: false);
      if (proventosFile != null) files.add(proventosFile);

      final jsonFile = await exportAllToJson(share: false);
      if (jsonFile != null) files.add(jsonFile);

      LoggerService.success('✅ ${files.length} arquivos exportados');
      PerformanceService.stop('export_all_files');

      return files;
    } catch (e) {
      LoggerService.error('Erro ao exportar arquivos', e);
      PerformanceService.stop('export_all_files');
      throw Exception('Erro ao exportar: $e');
    }
  }

  Future<void> exportAllAndShare() async {
    final files = await exportAllFiles();

    if (files.isNotEmpty) {
      final xFiles = files.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(xFiles,
          text: '📦 Exportação Completa - Controle Financeiro');
    }
  }

  // ========== EXPORTAÇÃO COM FILTRO POR DATA ==========

  Future<File?> exportLancamentosPorPeriodoCsv({
    required DateTime dataInicio,
    required DateTime dataFim,
    bool share = true,
  }) async {
    PerformanceService.start('export_lancamentos_periodo');

    try {
      LoggerService.info(
          '📊 Exportando lançamentos do período ${_dateFormat.format(dataInicio)} a ${_dateFormat.format(dataFim)}...');

      final todosLancamentos = await db.getAllLancamentos();

      final lancamentos = todosLancamentos.where((item) {
        final dataStr = item['data'] as String?;
        if (dataStr == null) return false;
        try {
          final data = DateTime.parse(dataStr);
          return (data.isAfter(dataInicio.subtract(const Duration(days: 1))) &&
              data.isBefore(dataFim.add(const Duration(days: 1))));
        } catch (e) {
          return false;
        }
      }).toList();

      List<List<String>> rows = [
        ['ID', 'Descrição', 'Tipo', 'Categoria', 'Valor', 'Data', 'Observação']
      ];

      double totalReceitas = 0;
      double totalDespesas = 0;

      for (var item in lancamentos) {
        final valor = (item['valor'] ?? 0).toDouble();
        final tipo = item['tipo'] ?? '';

        if (tipo == 'receita') {
          totalReceitas += valor;
        } else {
          totalDespesas += valor;
        }

        rows.add([
          item['id'].toString(),
          item['descricao'] ?? '',
          tipo == 'receita' ? 'Receita' : 'Despesa',
          item['categoria'] ?? '',
          _formatNumber(valor),
          _formatDate(item['data']),
          item['observacao'] ?? '',
        ]);
      }

      rows.add([]);
      rows.add([
        '',
        '',
        '',
        'TOTAL RECEITAS:',
        _formatNumber(totalReceitas),
        '',
        ''
      ]);
      rows.add([
        '',
        '',
        '',
        'TOTAL DESPESAS:',
        _formatNumber(totalDespesas),
        '',
        ''
      ]);
      rows.add([
        '',
        '',
        '',
        'SALDO:',
        _formatNumber(totalReceitas - totalDespesas),
        '',
        ''
      ]);
      rows.add([]);
      rows.add([
        'Período:',
        _dateFormat.format(dataInicio),
        'a',
        _dateFormat.format(dataFim),
        '',
        '',
        ''
      ]);
      rows.add([
        'Exportado em:',
        _dateFormat.format(DateTime.now()),
        '',
        '',
        '',
        '',
        ''
      ]);

      String csv = const ListToCsvConverter().convert(rows);
      final fileName =
          'lancamentos_periodo_${_fileDateFormat.format(DateTime.now())}.csv';
      final path = await _getExportPath(fileName);

      if (path != null) {
        final file = File(path);
        await file.writeAsString(csv, encoding: utf8);

        LoggerService.success(
            '✅ ${lancamentos.length} lançamentos exportados do período');
        PerformanceService.stop('export_lancamentos_periodo');

        if (share) {
          await Share.shareXFiles([XFile(path)],
              text:
                  '📊 Exportação de Lançamentos por Período - Controle Financeiro');
        }

        return file;
      }

      PerformanceService.stop('export_lancamentos_periodo');
      return null;
    } catch (e) {
      LoggerService.error('Erro ao exportar lançamentos por período', e);
      PerformanceService.stop('export_lancamentos_periodo');
      throw Exception('Erro ao exportar: $e');
    }
  }

  // ========== LIMPAR EXPORTAÇÕES ANTIGAS ==========

  Future<void> limparExportacoesAntigas({int daysToKeep = 30}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportsPath = '${directory.path}/exports';
      final dir = Directory(exportsPath);

      if (!await dir.exists()) return;

      final files = await dir.list().toList();
      final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
      int removidos = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoff)) {
            await file.delete();
            removidos++;
          }
        }
      }

      if (removidos > 0) {
        LoggerService.info(
            '🗑️ $removidos arquivos de exportação antigos removidos');
      }
    } catch (e) {
      LoggerService.warning('⚠️ Erro ao limpar exportações antigas: $e');
    }
  }
}

