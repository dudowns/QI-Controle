// lib/screens/proventos_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/provento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/adicionar_provento_modal.dart'; // 🔥 NOVO IMPORT!
import 'editar_provento.dart';

class ProventosScreen extends StatefulWidget {
  final List<Provento> proventos;
  final VoidCallback onRefresh;
  final List<String>? tickersDisponiveis; // 🔥 NOVO!

  const ProventosScreen({
    super.key,
    required this.proventos,
    required this.onRefresh,
    this.tickersDisponiveis,
  });

  @override
  State<ProventosScreen> createState() => _ProventosScreenState();
}

class _ProventosScreenState extends State<ProventosScreen> {
  String _filtroPeriodo = '12M';
  final List<String> _periodos = ['1M', '3M', '6M', '12M', 'TODOS'];

  Map<String, double> _proventosPorMes = {};
  Map<String, double> _proventosPorAtivo = {};
  double _totalPeriodo = 0;
  double _mediaMensal = 0;
  double _projetadoProximoMes = 0;

  @override
  void initState() {
    super.initState();
    _calcularEstatisticas();
  }

  void _calcularEstatisticas() {
    _proventosPorMes.clear();
    _proventosPorAtivo.clear();
    _totalPeriodo = 0;

    final agora = DateTime.now();
    DateTime dataLimite;

    switch (_filtroPeriodo) {
      case '1M':
        dataLimite = DateTime(agora.year, agora.month - 1, agora.day);
        break;
      case '3M':
        dataLimite = DateTime(agora.year, agora.month - 3, agora.day);
        break;
      case '6M':
        dataLimite = DateTime(agora.year, agora.month - 6, agora.day);
        break;
      case '12M':
        dataLimite = DateTime(agora.year - 1, agora.month, agora.day);
        break;
      default:
        dataLimite = DateTime(2000);
    }

    for (var p in widget.proventos) {
      if (p.dataPagamento.isAfter(dataLimite) || _filtroPeriodo == 'TODOS') {
        _totalPeriodo += p.totalRecebido;

        final chaveMes = DateFormat('MMM/yy').format(p.dataPagamento);
        _proventosPorMes[chaveMes] =
            (_proventosPorMes[chaveMes] ?? 0) + p.totalRecebido;

        _proventosPorAtivo[p.ticker] =
            (_proventosPorAtivo[p.ticker] ?? 0) + p.totalRecebido;
      }
    }

    _mediaMensal =
        _proventosPorMes.isEmpty ? 0 : _totalPeriodo / _proventosPorMes.length;

    // Calcular projetado (últimos 3 meses)
    final tresMesesAtras = DateTime(agora.year, agora.month - 3, agora.day);
    double somaUltimos3 = 0;
    int count = 0;

    for (var p in widget.proventos) {
      if (p.dataPagamento.isAfter(tresMesesAtras)) {
        somaUltimos3 += p.totalRecebido;
        count++;
      }
    }

    _projetadoProximoMes = count > 0 ? somaUltimos3 / count : 0;
  }

  List<PieChartSectionData> _getGraficoProventos() {
    final List<PieChartSectionData> sections = [];
    final cores = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    final ativosOrdenados = _proventosPorAtivo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int corIndex = 0;
    for (var entry in ativosOrdenados.take(6)) {
      final percentual = (entry.value / _totalPeriodo) * 100;
      sections.add(PieChartSectionData(
        value: entry.value,
        color: cores[corIndex % cores.length],
        title: percentual > 3 ? '${percentual.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 70,
      ));
      corIndex++;
    }

    if (ativosOrdenados.length > 6) {
      double outros = 0;
      for (int i = 6; i < ativosOrdenados.length; i++) {
        outros += ativosOrdenados[i].value;
      }
      if (outros > 0) {
        sections.add(PieChartSectionData(
          value: outros,
          color: Colors.grey,
          title: 'Outros',
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          radius: 70,
        ));
      }
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _getGraficoProventos();

    return Scaffold(
      backgroundColor: AppColors.background(context), // ✅ DINÂMICO!
      body: Column(
        children: [
          // Filtros de período
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Período:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context), // ✅ DINÂMICO!
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: _periodos.map((periodo) {
                      final isSelected = _filtroPeriodo == periodo;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FilterChip(
                            label: Text(periodo),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _filtroPeriodo = periodo;
                                _calcularEstatisticas();
                              });
                            },
                            selectedColor: AppColors.primary.withOpacity(0.1),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary(
                                      context), // ✅ DINÂMICO!
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Cards de resumo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildResumoCard(
                    'Total',
                    _totalPeriodo,
                    Icons.summarize,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResumoCard(
                    'Média',
                    _mediaMensal,
                    Icons.calculate,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResumoCard(
                    'Projetado',
                    _projetadoProximoMes,
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Gráfico e lista
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Gráfico de pizza
                  if (sections.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context), // ✅ DINÂMICO!
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.border(context)), // ✅ DINÂMICO!
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💰 Distribuição por Ativo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  AppColors.textPrimary(context), // ✅ DINÂMICO!
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 0,
                                centerSpaceRadius: 40,
                                sections: sections,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: _proventosPorAtivo.entries.map((entry) {
                              return _buildLegendaAtivo(
                                entry.key,
                                entry.value,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Lista de proventos
                  ...widget.proventos
                      .map((p) => _buildProventoCard(p))
                      .toList(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          // 🔥 AGORA USA O MODAL!
          if (widget.tickersDisponiveis == null ||
              widget.tickersDisponiveis!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Primeiro adicione um investimento'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          AdicionarProventoModal.show(
            context: context,
            tickersDisponiveis: widget.tickersDisponiveis!,
            onSalvo: widget.onRefresh,
          );
        },
      ),
    );
  }

  Widget _buildResumoCard(
      String label, double valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context), // ✅ DINÂMICO!
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)), // ✅ DINÂMICO!
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 14, color: cor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatador.moedaCompacta(valor),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendaAtivo(String ticker, double valor) {
    final percentual = (valor / _totalPeriodo) * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface(context).withOpacity(0.5), // ✅ DINÂMICO!
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)), // ✅ DINÂMICO!
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            ticker,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context), // ✅ DINÂMICO!
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${percentual.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary(context), // ✅ DINÂMICO!
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProventoCard(Provento p) {
    final hoje = DateTime.now();
    final isFuturo = p.dataPagamento.isAfter(hoje);
    final diasParaPagamento = p.dataPagamento.difference(hoje).inDays;

    Color statusColor;
    String statusText;

    if (isFuturo) {
      if (diasParaPagamento <= 7) {
        statusColor = Colors.orange;
        statusText = '⚠️ Próximo';
      } else {
        statusColor = AppColors.primary;
        statusText = '⏳ Futuro';
      }
    } else {
      statusColor = Colors.green;
      statusText = '✅ Recebido';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context), // ✅ DINÂMICO!
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)), // ✅ DINÂMICO!
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.ticker,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                AppColors.textPrimary(context), // ✅ DINÂMICO!
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.tipo.nome,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatador.moeda(p.totalRecebido),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.quantidade.toStringAsFixed(0)} cotas',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pagamento: ${DateFormat('dd/MM/yyyy').format(p.dataPagamento)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                  ),
                ],
              ),
              if (p.dataCom != null)
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 12,
                      color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'COM: ${DateFormat('dd/MM/yyyy').format(p.dataCom!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context), // ✅ DINÂMICO!
                      ),
                    ),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: AppColors.primary,
                onPressed: () => _editarProvento(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _editarProvento(Provento p) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarProventoScreen(
          provento: p.toJson(),
        ),
      ),
    );
    if (result == true) {
      widget.onRefresh();
    }
  }
}
