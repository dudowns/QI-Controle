// lib/services/pdf_service.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/db_helper.dart';
import '../utils/formatters.dart';

class PdfService {
  final DBHelper _dbHelper = DBHelper();

  Future<File> gerarRelatorioMensal(int ano, int mes) async {
    final db = await _dbHelper.database;

    final lancamentos = await db.query(
      'lancamentos',
      where: "strftime('%Y', data) = ? AND strftime('%m', data) = ?",
      whereArgs: [ano.toString(), mes.toString().padLeft(2, '0')],
      orderBy: 'data DESC',
    );

    final pdf = pw.Document();

    double totalReceitas = 0;
    double totalDespesas = 0;

    for (var l in lancamentos) {
      final valor =
          (l['valor'] as num).toDouble(); // ✅ CORRIGIDO: cast para num
      if (l['tipo'].toString() == 'receita') {
        // ✅ CORRIGIDO: .toString()
        totalReceitas += valor;
      } else {
        totalDespesas += valor;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Relatorio Financeiro - ${_nomeMes(mes)}/$ano',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              children: [
                _buildLinha('Total Receitas', Formatador.moeda(totalReceitas),
                    PdfColors.green),
                _buildLinha('Total Despesas', Formatador.moeda(totalDespesas),
                    PdfColors.red),
                _buildLinha(
                    'Saldo',
                    Formatador.moeda(totalReceitas - totalDespesas),
                    totalReceitas - totalDespesas >= 0
                        ? PdfColors.green
                        : PdfColors.red,
                    negrito: true),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Data', 'Descricao', 'Categoria', 'Valor'],
            data: lancamentos.map((l) {
              final valor = (l['valor'] as num).toDouble(); // ✅ CORRIGIDO
              return [
                _formatDate(
                    DateTime.parse(l['data'].toString())), // ✅ CORRIGIDO
                l['descricao'].toString(), // ✅ CORRIGIDO
                l['categoria'].toString(), // ✅ CORRIGIDO
                l['tipo'].toString() == 'receita' // ✅ CORRIGIDO
                    ? '+ ${Formatador.moeda(valor)}'
                    : '- ${Formatador.moeda(valor)}'
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
              'Gerado em: ${DateTime.now().toIso8601String().split('T')[0]}',
              style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );

    // ✅ CORRIGIDO: Directory.systemTemp
    final output = Directory.systemTemp;
    final file = File('${output.path}/relatorio_${ano}_$mes.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildLinha(String label, String valor, PdfColor cor,
      {bool negrito = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: negrito
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal)), // ✅ CORRIGIDO
        pw.Text(valor,
            style: pw.TextStyle(
                color: cor,
                fontSize: 14,
                fontWeight: negrito
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal)), // ✅ CORRIGIDO
      ],
    );
  }

  String _nomeMes(int mes) {
    const meses = [
      'Janeiro',
      'Fevereiro',
      'Marco',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return meses[mes - 1];
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
