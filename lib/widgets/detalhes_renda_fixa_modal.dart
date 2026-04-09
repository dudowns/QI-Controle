// lib/widgets/detalhes_renda_fixa_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../constants/app_colors.dart';

class DetalhesRendaFixaModal extends StatefulWidget {
  final RendaFixaModel investimento;

  const DetalhesRendaFixaModal({super.key, required this.investimento});

  @override
  State<DetalhesRendaFixaModal> createState() => _DetalhesRendaFixaModalState();

  static Future<void> show({
    required BuildContext context,
    required RendaFixaModel investimento,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: DetalhesRendaFixaModal(investimento: investimento),
      ),
    );
  }
}

class _DetalhesRendaFixaModalState extends State<DetalhesRendaFixaModal> {
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
        RendaFixaDiaria.gerarEvolucaoDiaria(widget.investimento, maxPontos: 15);
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
        return 'Pós-fixado (% CDI)';
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

    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(widget.investimento.nome, context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card valor atual
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPositive
                            ? [Colors.green.shade600, Colors.green.shade400]
                            : [Colors.orange.shade600, Colors.orange.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VALOR ATUAL',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(CurrencyFormatter.format(_valorHoje),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                children: [
                                  Icon(
                                      isPositive
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 12,
                                      color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${isPositive ? '+' : ''}${_rendimentoHoje.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('desde a aplicação',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progresso
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Progresso',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${(progresso * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7B2CBF),
                                fontSize: 14)),
                      ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progresso.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF7B2CBF),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            DateFormatter.formatDate(
                                widget.investimento.dataAplicacao),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                        Text(
                            DateFormatter.formatDate(
                                widget.investimento.dataVencimento),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ]),
                  const SizedBox(height: 16),

                  // Gráfico
                  if (_evolucao.isNotEmpty) ...[
                    SizedBox(
                      height: 120,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < _evolucao.length &&
                                      value.toInt() % 3 == 0) {
                                    final data = _evolucao[value.toInt()]
                                        ['data'] as DateTime;
                                    return Text(
                                        DateFormat('dd/MM').format(data),
                                        style: const TextStyle(fontSize: 8));
                                  }
                                  return const Text('');
                                },
                                reservedSize: 18,
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: _evolucao.asMap().entries.map((e) {
                                final valor =
                                    (e.value['valor'] as num?)?.toDouble() ??
                                        0.0;
                                return FlSpot(e.key.toDouble(), valor);
                              }).toList(),
                              isCurved: true,
                              color: const Color(0xFF7B2CBF),
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF7B2CBF)
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Cards info
                  Row(
                    children: [
                      Expanded(
                          child: _buildInfoCard(
                              'Aplicação',
                              CurrencyFormatter.format(
                                  widget.investimento.valorAplicado),
                              Icons.account_balance_wallet,
                              Colors.blue)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildInfoCard('Taxa', _formatarTaxa(),
                              Icons.percent, Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _buildInfoCard(
                              'Rendimento Hoje',
                              CurrencyFormatter.format(
                                  _calcularRendimentoHoje()),
                              Icons.trending_up,
                              Colors.orange)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _buildInfoCard(
                              'IR (parcial)',
                              CurrencyFormatter.format(_irParcial),
                              Icons.receipt,
                              Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Detalhes
                  _buildDetalheLinha('Indexador', _getIndexadorTexto()),
                  _buildDetalheLinha(
                      'Liquidez',
                      widget.investimento.liquidezDiaria
                          ? 'Diária'
                          : 'No vencimento'),
                  _buildDetalheLinha('Dias úteis',
                      '${_calcularDiasUteisAteHoje()} de ${widget.investimento.diasUteis}'),
                  if (!widget.investimento.isIsento) ...[
                    const Divider(height: 16),
                    _buildDetalheLinha('Rendimento Bruto',
                        CurrencyFormatter.format(_rendimentoHoje),
                        cor: Colors.green),
                    _buildDetalheLinha(
                        'IOF', '-${CurrencyFormatter.format(_iofParcial)}',
                        cor: Colors.red),
                    _buildDetalheLinha(
                        'IR', '-${CurrencyFormatter.format(_irParcial)}',
                        cor: Colors.red),
                    const Divider(height: 8),
                    _buildDetalheLinha(
                        'Rendimento Líquido',
                        CurrencyFormatter.format(
                            _rendimentoHoje - _iofParcial - _irParcial),
                        cor: Colors.green,
                        negrito: true),
                  ],
                  const Divider(height: 16),
                  _buildDetalheLinha(
                      'Valor Final Projetado',
                      CurrencyFormatter.format(
                          widget.investimento.valorFinal ?? 0),
                      cor: const Color(0xFF7B2CBF),
                      negrito: true),
                  const SizedBox(height: 16),
                  _buildButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, size: 20, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color cor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor, size: 14),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetalheLinha(String label, String value,
      {Color? cor, bool negrito = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: fontSize - 2, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: negrito ? FontWeight.bold : FontWeight.normal,
                  color: cor ?? const Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Fechar', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('OK',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
