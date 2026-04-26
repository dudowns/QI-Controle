// lib/screens/detalhes_renda_fixa.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../utils/formatters.dart';
import '../constants/app_colors.dart';

class DetalhesRendaFixaScreen extends StatefulWidget {
  final RendaFixaModel investimento;

  const DetalhesRendaFixaScreen({super.key, required this.investimento});

  @override
  State<DetalhesRendaFixaScreen> createState() =>
      _DetalhesRendaFixaScreenState();
}

class _DetalhesRendaFixaScreenState extends State<DetalhesRendaFixaScreen> {
  late List<Map<String, dynamic>> _evolucao;
  late double _valorHoje;
  late double _rendimentoHoje;
  late double _irParcial;
  late double _iofParcial;

  @override
  void initState() {
    super.initState();
    _calcularDados();
  }

  void _calcularDados() {
    final hoje = DateTime.now();

    _valorHoje =
        RendaFixaDiaria.calcularValorEm(widget.investimento, hoje).toDouble();
    _rendimentoHoje = _valorHoje - widget.investimento.valorAplicado;
    _irParcial =
        RendaFixaDiaria.calcularIRParcial(widget.investimento, hoje).toDouble();
    _iofParcial = _calcularIOFParcial();
    _evolucao =
        RendaFixaDiaria.gerarEvolucaoDiaria(widget.investimento, maxPontos: 20);
  }

  double _calcularIOFParcial() {
    final diasUteis = _calcularDiasUteisAteHoje();
    if (diasUteis >= 30) return 0.0;
    final aliquota = (30 - diasUteis) / 30 * 0.96;
    return _rendimentoHoje * aliquota;
  }

  int _calcularDiasUteisAteHoje() {
    final diasTotais =
        DateTime.now().difference(widget.investimento.dataAplicacao).inDays;
    if (diasTotais <= 0) return 0;
    return (diasTotais * 5 / 7).round();
  }

  double _calcularRendimentoHoje() {
    final ontem = DateTime.now().subtract(const Duration(days: 1));
    final valorOntem =
        RendaFixaDiaria.calcularValorEm(widget.investimento, ontem).toDouble();
    return _valorHoje - valorOntem;
  }

  String _formatarTaxa() {
    switch (widget.investimento.indexador) {
      case Indexador.preFixado:
        return '${widget.investimento.taxa.toStringAsFixed(2)}% a.a.';
      case Indexador.posFixadoCDI:
        return '${widget.investimento.taxa.toStringAsFixed(0)}% do CDI';
      case Indexador.ipca:
        return 'IPCA + ${widget.investimento.taxa.toStringAsFixed(2)}%';
    }
  }

  String _getIndexadorTexto() {
    switch (widget.investimento.indexador) {
      case Indexador.preFixado:
        return 'Prefixado';
      case Indexador.posFixadoCDI:
        return 'Pos-fixado (% CDI)';
      case Indexador.ipca:
        return 'IPCA+';
    }
  }

  @override
  Widget build(BuildContext context) {
    final diasAplicados =
        DateTime.now().difference(widget.investimento.dataAplicacao).inDays;
    final diasTotais = widget.investimento.dataVencimento
        .difference(widget.investimento.dataAplicacao)
        .inDays;
    final progresso = diasTotais > 0 ? diasAplicados / diasTotais : 0.0;
    final isPositive = _rendimentoHoje >= 0;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(widget.investimento.nome),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary(context),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPositive
                      ? [Colors.green.shade700, Colors.green.shade400]
                      : [Colors.orange.shade700, Colors.orange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VALOR ATUAL',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(Formatador.moeda(_valorHoje),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Icon(
                              isPositive
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                              color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                              '${isPositive ? '+' : ''}${_rendimentoHoje.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ])),
                    const SizedBox(width: 12),
                    Text('desde a aplicacao',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.cardBackground(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border(context))),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progresso',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context))),
                      Text('${(progresso * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7B2CBF),
                              fontSize: 16)),
                    ]),
                const SizedBox(height: 8),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: progresso.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        color: const Color(0xFF7B2CBF),
                        minHeight: 8)),
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Formatador.data(widget.investimento.dataAplicacao),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                      Text(Formatador.data(widget.investimento.dataVencimento),
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ]),
              ]),
            ),
            const SizedBox(height: 20),
            if (_evolucao.isNotEmpty) ...[
              Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.cardBackground(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border(context))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Evolucao do Investimento',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Expanded(
                            child: LineChart(LineChartData(
                                gridData: FlGridData(
                                    show: true,
                                    drawHorizontalLine: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: _calcularIntervaloY()),
                                titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: _calcularIntervaloY(),
                                            getTitlesWidget: (value, meta) =>
                                                Text(
                                                    Formatador.moedaCompacta(
                                                        value),
                                                    style: const TextStyle(
                                                        fontSize: 10)),
                                            reservedSize: 45)),
                                    bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              if (value.toInt() >= 0 &&
                                                  value.toInt() <
                                                      _evolucao.length) {
                                                final data =
                                                    _evolucao[value.toInt()]
                                                        ['data'] as DateTime;
                                                if (_evolucao.length > 15) {
                                                  if (value.toInt() % 3 == 0)
                                                    return Text(
                                                        DateFormat('dd/MM')
                                                            .format(data),
                                                        style: const TextStyle(
                                                            fontSize: 9));
                                                } else {
                                                  return Text(
                                                      DateFormat('dd/MM')
                                                          .format(data),
                                                      style: const TextStyle(
                                                          fontSize: 9));
                                                }
                                              }
                                              return const Text('');
                                            },
                                            reservedSize: 22)),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false))),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                      spots: _evolucao.asMap().entries.map((e) {
                                        final valor = (e.value['valor'] as num?)
                                                ?.toDouble() ??
                                            0.0;
                                        return FlSpot(e.key.toDouble(), valor);
                                      }).toList(),
                                      isCurved: true,
                                      color: const Color(0xFF7B2CBF),
                                      barWidth: 3,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                          show: true,
                                          color: const Color(0xFF7B2CBF)
                                              .withValues(alpha: 0.1)))
                                ],
                                minY: _calcularMinY(),
                                maxY: _calcularMaxY()))),
                      ])),
              const SizedBox(height: 20),
            ],
            Row(children: [
              Expanded(
                  child: _buildInfoCard(
                      'Aplicacao',
                      Formatador.moeda(widget.investimento.valorAplicado),
                      Icons.account_balance_wallet,
                      Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInfoCard(
                      'Taxa', _formatarTaxa(), Icons.percent, Colors.green)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _buildInfoCard(
                      'Rendimento Hoje',
                      Formatador.moeda(_calcularRendimentoHoje()),
                      Icons.trending_up,
                      Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildInfoCard('IR (parcial)',
                      Formatador.moeda(_irParcial), Icons.receipt, Colors.red)),
            ]),
            const SizedBox(height: 20),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.cardBackground(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context))),
                child: Column(children: [
                  _buildDetalheLinha('Indexador', _getIndexadorTexto()),
                  _buildDetalheLinha(
                      'Liquidez',
                      widget.investimento.liquidezDiaria
                          ? 'Diaria'
                          : 'No vencimento'),
                  _buildDetalheLinha('Dias uteis',
                      '${_calcularDiasUteisAteHoje()} de ${widget.investimento.diasUteis}'),
                  if (!widget.investimento.isIsento) ...[
                    const Divider(height: 24),
                    _buildDetalheLinha(
                        'Rendimento Bruto', Formatador.moeda(_rendimentoHoje),
                        cor: Colors.green),
                    _buildDetalheLinha(
                        'IOF', '-${Formatador.moeda(_iofParcial)}',
                        cor: Colors.red),
                    _buildDetalheLinha('IR', '-${Formatador.moeda(_irParcial)}',
                        cor: Colors.red),
                    const Divider(height: 16),
                    _buildDetalheLinha(
                        'Rendimento Liquido',
                        Formatador.moeda(
                            _rendimentoHoje - _iofParcial - _irParcial),
                        cor: Colors.green,
                        negrito: true,
                        fontSize: 16),
                  ],
                  const Divider(height: 24),
                  _buildDetalheLinha('Valor Final Projetado',
                      Formatador.moeda(widget.investimento.valorFinal ?? 0),
                      cor: const Color(0xFF7B2CBF),
                      negrito: true,
                      fontSize: 16),
                ])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color cor) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.cardBackground(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: cor, size: 14)),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ]));
  }

  Widget _buildDetalheLinha(String label, String value,
      {Color? cor, bool negrito = false, double fontSize = 14}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style:
                  TextStyle(fontSize: fontSize - 2, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
                  color: cor ?? AppColors.textPrimary(context))),
        ]));
  }

  double _calcularMinY() {
    if (_evolucao.isEmpty) return 0;
    final minValor = _evolucao
        .map((e) => (e['valor'] as num).toDouble())
        .reduce((a, b) => a < b ? a : b);
    return minValor * 0.95;
  }

  double _calcularMaxY() {
    if (_evolucao.isEmpty) return 0;
    final maxValor = _evolucao
        .map((e) => (e['valor'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
    return maxValor * 1.05;
  }

  double _calcularIntervaloY() {
    final minY = _calcularMinY();
    final maxY = _calcularMaxY();
    final intervalo = (maxY - minY) / 5;
    if (intervalo < 1) return 0.5;
    if (intervalo < 2) return 1;
    if (intervalo < 5) return 2;
    if (intervalo < 10) return 5;
    if (intervalo < 25) return 10;
    if (intervalo < 50) return 25;
    if (intervalo < 100) return 50;
    return 100;
  }
}
