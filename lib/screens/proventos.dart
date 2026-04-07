import '../services/logger_service.dart';
// lib/screens/proventos.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../models/provento_model.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_modals.dart';

class ProventosScreen extends StatefulWidget {
  const ProventosScreen({super.key});

  @override
  State<ProventosScreen> createState() => _ProventosScreenState();
}

class _ProventosScreenState extends State<ProventosScreen> {
  final DBHelper _dbHelper = DBHelper();

  List<Provento> _proventos = [];
  List<String> _tickersDisponiveis = [];
  bool _carregando = true;
  String _filtroPeriodo = '12M';
  final List<String> _periodos = ['1M', '3M', '6M', '12M', 'TODOS'];

  final Map<String, double> _proventosPorMes = {};
  final Map<String, double> _proventosPorAtivo = {};
  double _totalPeriodo = 0;
  double _mediaMensal = 0;
  double _projetadoProximoMes = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _carregarTickers();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final dados = await _dbHelper.getAllProventos();
      _proventos = dados.map((json) => Provento.fromJson(json)).toList();
      _calcularEstatisticas();
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar proventos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarTickers() async {
    try {
      final dados = await _dbHelper.getAllInvestimentos();
      _tickersDisponiveis =
          dados.map((inv) => inv['ticker'] as String).toSet().toList();
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar tickers: $e');
      _tickersDisponiveis = [];
    }
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

    for (var p in _proventos) {
      if (p.dataPagamento.isAfter(dataLimite) || _filtroPeriodo == 'TODOS') {
        _totalPeriodo += p.totalRecebido;

        final chaveMes = _formatarMes(p.dataPagamento);
        _proventosPorMes[chaveMes] =
            (_proventosPorMes[chaveMes] ?? 0) + p.totalRecebido;

        _proventosPorAtivo[p.ticker] =
            (_proventosPorAtivo[p.ticker] ?? 0) + p.totalRecebido;
      }
    }

    _mediaMensal =
        _proventosPorMes.isEmpty ? 0 : _totalPeriodo / _proventosPorMes.length;

    final tresMesesAtras = DateTime(agora.year, agora.month - 3, agora.day);
    double somaUltimos3 = 0;
    int count = 0;

    for (var p in _proventos) {
      if (p.dataPagamento.isAfter(tresMesesAtras)) {
        somaUltimos3 += p.totalRecebido;
        count++;
      }
    }

    _projetadoProximoMes = count > 0 ? somaUltimos3 / count : 0;
  }

  String _formatarMes(DateTime data) {
    const meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez'
    ];
    return '${meses[data.month - 1]}/${data.year.toString().substring(2)}';
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
      Colors.brown
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
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
              fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
          radius: 70,
        ));
      }
    }

    return sections;
  }

  Future<void> _adicionarProvento() async {
    if (_tickersDisponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primeiro adicione um investimento'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final resultado = await AppModals.mostrarModalProvento(
      context: context,
      tickersDisponiveis: _tickersDisponiveis,
    );

    if (resultado != null) {
      final novoProvento = Provento(
        ticker: resultado['ticker'],
        tipo: _getTipoProvento(resultado['tipo_provento']),
        valorPorCota: resultado['valor_por_cota'],
        quantidade: resultado['quantidade'],
        dataPagamento: DateTime.parse(resultado['data_pagamento']),
        dataCom: resultado['data_com'] != null
            ? DateTime.parse(resultado['data_com'])
            : null,
      );
      await _dbHelper.insertProvento(novoProvento.toJson());
      await _carregarDados();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Provento adicionado!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  TipoProvento _getTipoProvento(String tipo) {
    switch (tipo) {
      case 'Dividendo':
        return TipoProvento.dividendo;
      case 'JCP':
        return TipoProvento.jcp;
      case 'Rendimento':
        return TipoProvento.rendaFixa;
      default:
        return TipoProvento.outros;
    }
  }

  Future<void> _editarProvento(Provento provento) async {
    final resultado = await AppModals.mostrarModalProvento(
      context: context,
      provento: provento.toJson(),
      tickersDisponiveis: _tickersDisponiveis,
    );

    if (resultado != null) {
      final proventoAtualizado = Provento(
        id: provento.id,
        ticker: resultado['ticker'],
        tipo: _getTipoProvento(resultado['tipo_provento']),
        valorPorCota: resultado['valor_por_cota'],
        quantidade: resultado['quantidade'],
        dataPagamento: DateTime.parse(resultado['data_pagamento']),
        dataCom: resultado['data_com'] != null
            ? DateTime.parse(resultado['data_com'])
            : null,
      );
      await _dbHelper.updateProvento(proventoAtualizado.toJson());
      await _carregarDados();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✏️ Provento atualizado!'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _excluirProvento(int id, String ticker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Provento'),
        content: Text('Deseja excluir provento de $ticker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteProvento(id);
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Provento excluído!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _getGraficoProventos();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Seletor de período
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Período:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: _periodos.map((periodo) {
                            final isSelected = _filtroPeriodo == periodo;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: FilterChip(
                                  label: Text(periodo),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _filtroPeriodo = periodo;
                                      _calcularEstatisticas();
                                    });
                                  },
                                  selectedColor:
                                      AppColors.primary.withValues(alpha:0.1),
                                  checkmarkColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textSecondary(context),
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
                          child: _buildResumoCard('Total', _totalPeriodo,
                              Icons.summarize, AppColors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildResumoCard('Média', _mediaMensal,
                              Icons.calculate, Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildResumoCard(
                              'Projetado',
                              _projetadoProximoMes,
                              Icons.trending_up,
                              Colors.orange)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Lista de proventos
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (sections.isNotEmpty && _totalPeriodo > 0)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.border(context)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💰 Distribuição por Ativo',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: PieChart(PieChartData(
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 40,
                                    sections: sections,
                                  )),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (_proventos.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.attach_money,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text('Nenhum provento registrado',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600])),
                                  const SizedBox(height: 8),
                                  Text('Toque no botão + para adicionar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500])),
                                ],
                              ),
                            ),
                          )
                        else
                          ..._proventos.map((p) => _buildProventoCard(p)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _adicionarProvento,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildResumoCard(
      String label, double valor, IconData icone, Color cor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icone, size: 14, color: cor),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: AppColors.textSecondary(context))),
          ]),
          const SizedBox(height: 8),
          Text(Formatador.moedaCompacta(valor),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
        ],
      ),
    );
  }

  Widget _buildProventoCard(Provento p) {
    final isFuturo = p.dataPagamento.isAfter(DateTime.now());
    final diasParaPagamento = p.dataPagamento.difference(DateTime.now()).inDays;

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

    return Dismissible(
      key: Key(p.id ?? DateTime.now().millisecondsSinceEpoch.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir'),
            content: Text('Excluir provento de ${p.ticker}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Excluir', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _excluirProvento(int.parse(p.id!), p.ticker),
      child: InkWell(
        onTap: () => _editarProvento(p),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.monetization_on, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(p.ticker,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(statusText,
                            style: TextStyle(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(p.tipo.nome,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatador.moeda(p.totalRecebido),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor)),
                  const SizedBox(height: 4),
                  Text(
                      '${p.quantidade.toStringAsFixed(0)} cotas × ${Formatador.moeda(p.valorPorCota)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                  const SizedBox(height: 4),
                  Text('Pagamento: ${Formatador.data(p.dataPagamento)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

