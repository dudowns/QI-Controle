import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/yahoo_finance_service.dart';
import 'package:intl/intl.dart';

class GraficoAtivoScreen extends StatefulWidget {
  final Map<String, dynamic> ativo;
  const GraficoAtivoScreen({super.key, required this.ativo});

  @override
  State<GraficoAtivoScreen> createState() => _GraficoAtivoScreenState();
}

class _GraficoAtivoScreenState extends State<GraficoAtivoScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  List<Map<String, dynamic>>? dadosHistoricos;
  bool carregando = true;
  String periodoSelecionado = '30d';

  final Map<String, int> periodos = {
    '7d': 7,
    '30d': 30,
    '90d': 90,
    '1y': 365,
  };

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => carregando = true);

    final dias = periodos[periodoSelecionado] ?? 30;
    final dados =
        await _service.getDadosHistoricos(widget.ativo['ticker'], dias: dias);

    setState(() {
      dadosHistoricos = dados;
      carregando = false;
    });
  }

  // 🔥 MÉTODO DE FORMATAÇÃO (AGORA OS VALORES FICAM BONITOS!)
  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // 🔥 PARA O EIXO Y DO GRÁFICO
  String _formatarEixoY(double value) {
    if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}k';
    }
    return 'R\$ ${value.toStringAsFixed(0)}';
  }

  double get _precoAtual =>
      widget.ativo['preco_atual'] ?? widget.ativo['preco_medio'];
  double get _precoMedio => widget.ativo['preco_medio'];
  double get _variacaoTotal =>
      ((_precoAtual - _precoMedio) / _precoMedio) * 100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.ativo['ticker']} - Evolução'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: periodos.keys.map((periodo) {
                final isSelected = periodoSelecionado == periodo;
                return TextButton(
                  onPressed: () {
                    setState(() {
                      periodoSelecionado = periodo;
                    });
                    _carregarDados();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isSelected ? const Color(0xFF6A1B9A) : Colors.grey,
                    backgroundColor: isSelected
                        ? const Color(0xFF6A1B9A).withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Text(periodo),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : dadosHistoricos == null || dadosHistoricos!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Dados não disponíveis',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card de resumo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PREÇO ATUAL',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatarValor(_precoAtual), // ✅ R$ 35,20
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _variacaoTotal >= 0
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _variacaoTotal >= 0
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        size: 16,
                                        color: _variacaoTotal >= 0
                                            ? Colors.green[200]
                                            : Colors.red[200],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_variacaoTotal >= 0 ? '+' : ''}${_variacaoTotal.toStringAsFixed(2)}%',
                                        style: TextStyle(
                                          color: _variacaoTotal >= 0
                                              ? Colors.green[200]
                                              : Colors.red[200],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'desde a compra',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Título do gráfico
                      const Text(
                        'Evolução do Preço',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // GRÁFICO PRINCIPAL
                      Container(
                        height: 300,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: _calcularIntervaloY(),
                              verticalInterval: dadosHistoricos!.length > 10
                                  ? dadosHistoricos!.length / 5
                                  : 1,
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: _calcularIntervaloY(),
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      _formatarEixoY(value), // ✅ R$ 30, R$ 35k
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500),
                                    );
                                  },
                                  reservedSize: 45,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 &&
                                        value.toInt() <
                                            dadosHistoricos!.length) {
                                      final data =
                                          dadosHistoricos![value.toInt()]
                                              ['data'];
                                      if (dadosHistoricos!.length > 20) {
                                        if (value.toInt() % 5 == 0) {
                                          return Text(
                                            DateFormat('dd/MM').format(data),
                                            style: const TextStyle(fontSize: 9),
                                          );
                                        }
                                      } else {
                                        return Text(
                                          DateFormat('dd/MM').format(data),
                                          style: const TextStyle(fontSize: 9),
                                        );
                                      }
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 22,
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _gerarSpots(),
                                isCurved: true,
                                color: const Color(0xFF6A1B9A),
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color:
                                      const Color(0xFF6A1B9A).withOpacity(0.1),
                                ),
                              ),
                              if (_precoMedio > 0)
                                LineChartBarData(
                                  spots: _gerarLinhaMedia(),
                                  isCurved: false,
                                  color: Colors.orange,
                                  barWidth: 2,
                                  dashArray: [5, 5],
                                  dotData: const FlDotData(show: false),
                                ),
                            ],
                            minY: _calcularMinY(),
                            maxY: _calcularMaxY(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Legenda
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendaItem(
                              'Preço Atual',
                              _precoAtual, // ✅ Passa o double
                              const Color(0xFF6A1B9A),
                            ),
                            _buildLegendaItem(
                              'Preço Médio',
                              _precoMedio, // ✅ Passa o double
                              Colors.orange,
                            ),
                            _buildLegendaItem(
                              'Variação',
                              '${_variacaoTotal >= 0 ? '+' : ''}${_variacaoTotal.toStringAsFixed(2)}%', // ✅ String
                              _variacaoTotal >= 0 ? Colors.green : Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLegendaItem(String titulo, dynamic valor, Color cor) {
    String valorFormatado;

    if (valor is double) {
      valorFormatado = _formatarValor(valor); // ✅ R$ 35,20
    } else {
      valorFormatado = valor.toString(); // ✅ +11,93%
    }

    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valorFormatado,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _gerarSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < dadosHistoricos!.length; i++) {
      spots.add(FlSpot(i.toDouble(), dadosHistoricos![i]['preco']));
    }
    return spots;
  }

  List<FlSpot> _gerarLinhaMedia() {
    if (dadosHistoricos!.isEmpty) return [];
    return [
      FlSpot(0, _precoMedio),
      FlSpot((dadosHistoricos!.length - 1).toDouble(), _precoMedio),
    ];
  }

  double _calcularMinY() {
    if (dadosHistoricos!.isEmpty) return 0;
    final minPreco = dadosHistoricos!
        .map((e) => e['preco'] as double)
        .reduce((a, b) => a < b ? a : b);
    final minMedia = _precoMedio * 0.95;
    return (minPreco < minMedia ? minPreco : minMedia) * 0.95;
  }

  double _calcularMaxY() {
    if (dadosHistoricos!.isEmpty) return 0;
    final maxPreco = dadosHistoricos!
        .map((e) => e['preco'] as double)
        .reduce((a, b) => a > b ? a : b);
    final maxMedia = _precoMedio * 1.05;
    return (maxPreco > maxMedia ? maxPreco : maxMedia) * 1.05;
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
