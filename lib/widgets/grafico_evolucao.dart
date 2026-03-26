// lib/widgets/grafico_evolucao.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class GraficoEvolucao extends StatefulWidget {
  final List<Map<String, dynamic>> dados;
  final double valorInvestido;
  final double patrimonioAtual;

  const GraficoEvolucao({
    super.key,
    required this.dados,
    required this.valorInvestido,
    required this.patrimonioAtual,
  });

  @override
  State<GraficoEvolucao> createState() => _GraficoEvolucaoState();
}

class _GraficoEvolucaoState extends State<GraficoEvolucao> {
  bool _mostrarPatrimonio = true;
  bool _mostrarInvestido = true;

  @override
  Widget build(BuildContext context) {
    // 🔥 Se não houver dados, mostrar mensagem
    if (widget.dados.isEmpty) {
      return Container(
        height: 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: Text(
            'Sem dados para exibir',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Preparar dados para o gráfico - APENAS MESES COM INVESTIMENTO
    final List<_EvolucaoData> chartData = [];
    for (var item in widget.dados) {
      final data = item['data'] as DateTime;
      final patrimonio = item['patrimonio'];
      final investido = item['investido'];

      // 🔥 SÓ ADICIONA SE TIVER INVESTIMENTO (patrimônio > 0 OU investido > 0)
      if (patrimonio > 0 || investido > 0) {
        chartData.add(_EvolucaoData(
          mes:
              '${data.month.toString().padLeft(2, '0')}/${data.year.toString().substring(2, 4)}',
          patrimonio: patrimonio,
          investido: investido,
        ));
      }
    }

    // Se depois do filtro não tiver dados
    if (chartData.isEmpty) {
      return Container(
        height: 450,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(
          child: Text(
            'Nenhum investimento neste período',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 500,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            '📊 Evolução do Patrimônio - ${_getAnoRange(chartData)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // LEGENDA INTERATIVA
          Row(
            children: [
              _buildLegendaInterativa(
                'Patrimônio',
                const Color(0xFF4CAF50),
                _mostrarPatrimonio,
                (value) {
                  setState(() {
                    _mostrarPatrimonio = value!;
                  });
                },
              ),
              const SizedBox(width: 20),
              _buildLegendaInterativa(
                'Valor aplicado',
                const Color(0xFF2196F3),
                _mostrarInvestido,
                (value) {
                  setState(() {
                    _mostrarInvestido = value!;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // GRÁFICO DE BARRAS LADO A LADO
          Expanded(
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              primaryXAxis: CategoryAxis(
                labelRotation: 0,
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 1),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                majorTickLines: const MajorTickLines(size: 0),
                // Intervalo automático - mostra todos os meses com dados
              ),
              primaryYAxis: NumericAxis(
                numberFormat: NumberFormat.currency(
                  locale: 'pt_BR',
                  symbol: 'R\$ ',
                  decimalDigits: 0,
                ),
                axisLine: const AxisLine(width: 1),
                majorGridLines: const MajorGridLines(
                  color: Color(0xFFE0E0E0),
                  dashArray: [5, 5],
                ),
                minimum: 0,
                // Formatação brasileira nos valores do eixo Y
                axisLabelFormatter: (axisLabelRenderArgs) {
                  final value = axisLabelRenderArgs.value;
                  if (value >= 1000) {
                    return ChartAxisLabel(
                      'R\$ ${(value / 1000).toStringAsFixed(0)}k',
                      const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                    );
                  } else {
                    return ChartAxisLabel(
                      'R\$ ${value.toStringAsFixed(0)}',
                      const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                    );
                  }
                },
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                format: 'point.y',
                header: '',
                canShowMarker: false,
                // Tooltip em português
                builder: (dynamic data, dynamic point, dynamic series,
                    int pointIndex, int seriesIndex) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          series.name == 'Patrimônio'
                              ? '💰 Patrimônio'
                              : '💵 Aplicado',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'pt_BR',
                            symbol: 'R\$ ',
                            decimalDigits: 2,
                          ).format(point.y),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: series.name == 'Patrimônio'
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              series: _getSeries(chartData),
            ),
          ),

          const SizedBox(height: 8),

          // Rodapé com valores atuais (em R$ brasileiro)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildValorItem(
                  'Valor aplicado',
                  widget.valorInvestido,
                  const Color(0xFF2196F3),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey[300],
                ),
                _buildValorItem(
                  'Patrimônio',
                  widget.patrimonioAtual,
                  const Color(0xFF4CAF50),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 FUNÇÃO PARA PEGAR O ANO DO PRIMEIRO E ÚLTIMO MÊS
  String _getAnoRange(List<_EvolucaoData> data) {
    if (data.isEmpty) return '2026';

    final primeiroMes = data.first.mes.split('/')[1];
    final ultimoMes = data.last.mes.split('/')[1];

    if (primeiroMes == ultimoMes) {
      return '20$primeiroMes';
    } else {
      return '20$primeiroMes-20$ultimoMes';
    }
  }

  // LEGENDA INTERATIVA
  Widget _buildLegendaInterativa(
    String texto,
    Color cor,
    bool isSelected,
    Function(bool?) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!isSelected),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isSelected ? cor : Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? cor : Colors.grey[400]!,
                width: 1,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? cor : Colors.grey[500],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 SÉRIES COM BARRAS LADO A LADO
  List<CartesianSeries<_EvolucaoData, String>> _getSeries(
      List<_EvolucaoData> data) {
    final List<CartesianSeries<_EvolucaoData, String>> series = [];

    if (_mostrarPatrimonio) {
      series.add(
        ColumnSeries<_EvolucaoData, String>(
          name: 'Patrimônio',
          dataSource: data,
          xValueMapper: (data, _) => data.mes,
          yValueMapper: (data, _) => data.patrimonio,
          color: const Color(0xFF4CAF50),
          width: 0.4,
          spacing: 0.1,
          borderRadius: BorderRadius.circular(4),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
          opacity: _mostrarInvestido ? 0.8 : 1.0,
        ),
      );
    }

    if (_mostrarInvestido) {
      series.add(
        ColumnSeries<_EvolucaoData, String>(
          name: 'Valor Aplicado',
          dataSource: data,
          xValueMapper: (data, _) => data.mes,
          yValueMapper: (data, _) => data.investido,
          color: const Color(0xFF2196F3),
          width: 0.4,
          spacing: 0.1,
          borderRadius: BorderRadius.circular(4),
          dataLabelSettings: const DataLabelSettings(isVisible: false),
          opacity: _mostrarPatrimonio ? 0.8 : 1.0,
        ),
      );
    }

    return series;
  }

  // Item do rodapé com formato brasileiro
  Widget _buildValorItem(String label, double valor, Color cor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: cor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF666666),
              ),
            ),
            Text(
              NumberFormat.currency(
                locale: 'pt_BR',
                symbol: 'R\$ ',
                decimalDigits: 2,
              ).format(valor),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Classe auxiliar para os dados do gráfico
class _EvolucaoData {
  final String mes;
  final double patrimonio;
  final double investido;

  _EvolucaoData({
    required this.mes,
    required this.patrimonio,
    required this.investido,
  });
}
