// lib/screens/dashboard.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';
import '../widgets/animated_counter.dart';
import '../services/dashboard_service.dart';
import '../widgets/toast.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DBHelper _dbHelper = DBHelper();
  final DashboardService _dashboardService = DashboardService();

  List<Map<String, dynamic>> _lancamentos = [];
  List<Map<String, dynamic>> _investimentos = [];
  List<Map<String, dynamic>> _metas = [];
  List<Map<String, dynamic>> _contas = [];

  bool _isLoading = true;
  DateTime _mesSelecionado = DateTime.now();

  double _totalReceitas = 0;
  double _totalDespesas = 0;
  double _saldo = 0;
  double _patrimonio = 0;
  double _totalContasPendentes = 0;
  int _quantidadeContas = 0;
  int _metasAtivas = 0;

  double _mediaGastosDiaria = 0;
  MapEntry<String, double>? _maiorGasto;
  double _taxaEconomia = 0;

  List<Map<String, dynamic>> _gastosPorCategoria = [];
  final List<Map<String, dynamic>> _evolucaoMensal = [];
  List<Map<String, dynamic>> _ultimosLancamentos = [];

  final NumberFormat _realFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  final List<String> _meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez'
  ];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final metricas = await _dashboardService.getMetricasRapidas();
      _totalReceitas = metricas['receitas_mes'] ?? 0;
      _totalDespesas = metricas['despesas_mes'] ?? 0;
      _metasAtivas = metricas['metas_ativas'] ?? 0;

      // ✅ BUSCA CONTAS PENDENTES DO MÊS SELECIONADO
      final contasPendentes = await _dashboardService.getContasPendentesPorMes(
        _mesSelecionado.year,
        _mesSelecionado.month,
      );
      _totalContasPendentes = contasPendentes['valor_total'] ?? 0.0;
      _quantidadeContas = contasPendentes['quantidade'] ?? 0;

      _lancamentos = await _dbHelper.getAllLancamentos();

      // ✅ CALCULA PATRIMÔNIO A PARTIR DAS TRANSAÇÕES
      final db = await _dbHelper.database;
      final transacoes = await db.query('transacoes', orderBy: 'data ASC');

      final Map<String, Map<String, dynamic>> agrupados = {};
      for (var tx in transacoes) {
        final ticker = tx['ticker']?.toString().toUpperCase() ?? '';
        if (ticker.isEmpty) continue;

        final tipo = tx['tipo_transacao']?.toString() ?? 'COMPRA';
        final quantidade = (tx['quantidade'] as num?)?.toDouble() ?? 0;
        final preco = (tx['preco_unitario'] as num?)?.toDouble() ?? 0;
        final taxa = (tx['taxa'] as num?)?.toDouble() ?? 0;

        if (!agrupados.containsKey(ticker)) {
          if (tipo == 'COMPRA') {
            agrupados[ticker] = {
              'ticker': ticker,
              'quantidade': quantidade,
              'preco_medio': preco,
              'preco_atual': preco,
            };
          }
        } else {
          final existente = agrupados[ticker]!;
          if (tipo == 'COMPRA') {
            final novaQtd = (existente['quantidade'] as double) + quantidade;
            final valorAntigo = (existente['quantidade'] as double) *
                (existente['preco_medio'] as double);
            final valorNovo = (quantidade * preco) + taxa;
            existente['quantidade'] = novaQtd;
            existente['preco_medio'] = (valorAntigo + valorNovo) / novaQtd;
            existente['preco_atual'] = existente['preco_medio'];
          } else if (tipo == 'VENDA') {
            final novaQtd = (existente['quantidade'] as double) - quantidade;
            if (novaQtd <= 0.001) {
              agrupados.remove(ticker);
            } else {
              existente['quantidade'] = novaQtd;
            }
          }
        }
      }

      _investimentos = agrupados.values.toList();

      _metas = await _dbHelper.getAllMetas();
      _contas = await _dbHelper.getPagamentosDoMes(
          _mesSelecionado.year, _mesSelecionado.month);

      _calcularTotais();
      _calcularEstatisticas();
      _calcularEvolucaoMensal();
      _calcularGastosPorCategoria();
      _carregarUltimosLancamentos();
    } catch (e) {
      debugPrint('Erro ao carregar dashboard: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar dashboard');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularTotais() {
    double receitas = 0;
    double despesas = 0;

    for (var lancamento in _lancamentos) {
      final data = DateTime.parse(lancamento['data'].toString());
      if (data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month) {
        if (lancamento['tipo'] == 'receita') {
          receitas += (lancamento['valor'] as num).toDouble();
        } else {
          despesas += (lancamento['valor'] as num).toDouble();
        }
      }
    }

    _totalReceitas = receitas;
    _totalDespesas = despesas;
    _saldo = receitas - despesas;

    // ✅ Calcula patrimônio total
    double patrimonio = 0;
    for (var investimento in _investimentos) {
      final quantidade = (investimento['quantidade'] as num?)?.toDouble() ?? 0;
      final precoAtual = (investimento['preco_atual'] as num?)?.toDouble() ??
          (investimento['preco_medio'] as num?)?.toDouble() ??
          0;
      patrimonio += quantidade * precoAtual;
    }
    _patrimonio = patrimonio;

    int ativas = 0;
    for (var meta in _metas) {
      if ((meta['concluida'] as int) == 0) {
        ativas++;
      }
    }
    _metasAtivas = ativas;
  }

  void _calcularEstatisticas() {
    final lancamentosMes = _lancamentos.where((lancamento) {
      final data = DateTime.parse(lancamento['data'].toString());
      return data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month;
    }).toList();

    double despesasTotal = 0;
    final Map<String, double> gastosPorCategoria = {};

    for (var lancamento in lancamentosMes) {
      if (lancamento['tipo'] != 'receita') {
        final valor = (lancamento['valor'] as num).toDouble();
        despesasTotal += valor;
        final categoria = lancamento['categoria']?.toString() ?? 'Outros';
        gastosPorCategoria[categoria] =
            (gastosPorCategoria[categoria] ?? 0) + valor;
      }
    }

    final diasNoMes =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0).day;
    _mediaGastosDiaria = despesasTotal / diasNoMes;

    if (gastosPorCategoria.isNotEmpty) {
      MapEntry<String, double>? maior;
      for (var entry in gastosPorCategoria.entries) {
        if (maior == null || entry.value > maior.value) {
          maior = entry;
        }
      }
      _maiorGasto = maior;
    } else {
      _maiorGasto = null;
    }

    double receitasTotal = 0;
    for (var lancamento in lancamentosMes) {
      if (lancamento['tipo'] == 'receita') {
        receitasTotal += (lancamento['valor'] as num).toDouble();
      }
    }
    _taxaEconomia = receitasTotal > 0
        ? ((receitasTotal - despesasTotal) / receitasTotal) * 100
        : 0;
  }

  void _calcularEvolucaoMensal() {
    _evolucaoMensal.clear();

    for (int i = 2; i >= 0; i--) {
      final data = DateTime(_mesSelecionado.year, _mesSelecionado.month - i, 1);
      double receitas = 0;
      double despesas = 0;

      for (var lancamento in _lancamentos) {
        final dataLanc = DateTime.parse(lancamento['data'].toString());
        if (dataLanc.year == data.year && dataLanc.month == data.month) {
          if (lancamento['tipo'] == 'receita') {
            receitas += (lancamento['valor'] as num).toDouble();
          } else {
            despesas += (lancamento['valor'] as num).toDouble();
          }
        }
      }

      _evolucaoMensal.add({
        'mes': data.month,
        'receitas': receitas,
        'despesas': despesas,
      });
    }
  }

  void _calcularGastosPorCategoria() {
    final Map<String, double> gastos = {};
    double totalDespesas = 0;

    for (var lancamento in _lancamentos) {
      final data = DateTime.parse(lancamento['data'].toString());
      if (data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month) {
        if (lancamento['tipo'] != 'receita') {
          final valor = (lancamento['valor'] as num).toDouble();
          final categoria = lancamento['categoria']?.toString() ?? 'Outros';
          gastos[categoria] = (gastos[categoria] ?? 0) + valor;
          totalDespesas += valor;
        }
      }
    }

    _gastosPorCategoria = gastos.entries.map((entry) {
      return {
        'categoria': entry.key,
        'total': entry.value,
        'percentual':
            totalDespesas > 0 ? (entry.value / totalDespesas) * 100 : 0,
      };
    }).toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  }

  void _carregarUltimosLancamentos() {
    _ultimosLancamentos = _lancamentos.where((lancamento) {
      final data = DateTime.parse(lancamento['data'].toString());
      return data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month;
    }).toList()
      ..sort((a, b) => b['data'].compareTo(a['data']));

    _ultimosLancamentos = _ultimosLancamentos.take(5).toList();
  }

  void _navegarMes(int delta) {
    setState(() {
      _mesSelecionado =
          DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1);
    });
    _carregarDados();
  }

  String _formatarMoeda(double valor) {
    return _realFormat.format(valor);
  }

  String _formatarEixoY(double valor) {
    if (valor >= 1000) {
      return '${(valor / 1000).toStringAsFixed(0)}k';
    }
    return valor.toStringAsFixed(0);
  }

  void _irParaLancamentos() {
    Navigator.pushNamed(context, '/lancamentos');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _carregarDados,
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - opacity)),
                    child: child,
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_buildMonthSelector()],
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - opacity)),
                    child: child,
                  ),
                );
              },
              child: Row(
                children: [
                  _buildStatCard('Receitas', _totalReceitas, AppColors.success,
                      Icons.trending_up),
                  const SizedBox(width: 12),
                  _buildStatCard('Despesas', _totalDespesas, AppColors.error,
                      Icons.trending_down),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Contas Pendentes',
                    _totalContasPendentes,
                    AppColors.warning,
                    Icons.receipt,
                    subtitle: '$_quantidadeContas conta(s)',
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Patrimonio',
                    _patrimonio,
                    AppColors.primary,
                    Icons.account_balance,
                    subtitle: '$_metasAtivas meta(s) ativa(s)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - opacity)),
                    child: child,
                  ),
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildExpensesSection(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _buildIncomeExpenseChart(),
                        const SizedBox(height: 12),
                        _buildStatsCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, opacity, child) {
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, 50 * (1 - opacity)),
                    child: child,
                  ),
                );
              },
              child: _buildUltimasTransacoesSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => _navegarMes(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            '${_meses[_mesSelecionado.month - 1]}. ${_mesSelecionado.year}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => _navegarMes(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double value, Color color, IconData icon,
      {String? subtitle}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            AnimatedCounter(
              value: value,
              duration: const Duration(milliseconds: 1000),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
              formatter: (val) => _formatarMoeda(val),
            ),
            Text(title,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(context))),
            if (subtitle != null)
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesSection() {
    final gastos = _gastosPorCategoria;
    final despesasTotal = _totalDespesas;

    if (gastos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Center(
          child: Text('Nenhum gasto registrado',
              style: TextStyle(color: AppColors.textSecondary(context))),
        ),
      );
    }

    final List<Map<String, dynamic>> pizzaData = gastos.map((item) {
      final valor = (item['total'] as num).toDouble();
      return {
        'categoria': item['categoria']?.toString() ?? 'Outros',
        'valor': valor,
        'percentual': despesasTotal > 0 ? (valor / despesasTotal) * 100 : 0,
        'cor':
            AppCategories.getColor(item['categoria']?.toString() ?? 'Outros'),
      };
    }).toList()
      ..sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));

    final List<Map<String, dynamic>> topCategorias = pizzaData.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Despesas por Categoria',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 140,
                      width: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: topCategorias.map((item) {
                            final percentual = item['percentual'] as double;
                            return PieChartSectionData(
                              value: item['valor'] as double,
                              color: item['cor'] as Color,
                              title: percentual > 6
                                  ? '${percentual.toStringAsFixed(0)}%'
                                  : '',
                              titleStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              radius: 65,
                              showTitle: true,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: Column(
                  children: topCategorias.map((item) {
                    final categoria = item['categoria'] as String;
                    final valorItem = item['valor'] as double;
                    final cor = item['cor'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(categoria,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary(context))),
                              AnimatedCounter(
                                value: valorItem,
                                duration: const Duration(milliseconds: 800),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary(context)),
                                formatter: (val) => _formatarMoeda(val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(height: 2, width: 35, color: cor),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseChart() {
    if (_evolucaoMensal.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Center(
          child: Text('Carregando dados...',
              style: TextStyle(color: AppColors.textSecondary(context))),
        ),
      );
    }

    double maxValor = 0;
    for (var item in _evolucaoMensal) {
      final receitas = item['receitas'] as double;
      final despesas = item['despesas'] as double;
      if (receitas > maxValor) maxValor = receitas;
      if (despesas > maxValor) maxValor = despesas;
    }
    maxValor = maxValor * 1.2;
    if (maxValor == 0) maxValor = 100;

    const int numeroDeDivisoes = 4;
    final double intervalo = maxValor / numeroDeDivisoes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Receitas vs Despesas',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Receitas: ${_formatarMoeda(_totalReceitas)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success)),
              Text('Despesas: ${_formatarMoeda(_totalDespesas)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValor,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = _evolucaoMensal[group.x.toInt()];
                      final isReceita = rodIndex == 0;
                      final valor = isReceita
                          ? item['receitas'] as double
                          : item['despesas'] as double;
                      final label = isReceita ? 'Receitas' : 'Despesas';
                      return BarTooltipItem(
                        '$label\n${_formatarMoeda(valor)}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      );
                    },
                    tooltipBgColor: AppColors.primary,
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                  ),
                ),
                barGroups: List.generate(_evolucaoMensal.length, (index) {
                  final item = _evolucaoMensal[index];
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                          toY: item['receitas'] as double,
                          color: AppColors.success,
                          width: 24,
                          borderRadius: BorderRadius.circular(6)),
                      BarChartRodData(
                          toY: item['despesas'] as double,
                          color: AppColors.error,
                          width: 24,
                          borderRadius: BorderRadius.circular(6)),
                    ],
                    barsSpace: 10,
                  );
                }),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _evolucaoMensal.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                '${_meses[(_evolucaoMensal[index]['mes'] as int) - 1]}.',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) {
                          return Text('0',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary(context)));
                        }
                        if (value > 0 && value <= maxValor) {
                          return Text(_formatarEixoY(value),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary(context)));
                        }
                        return const Text('');
                      },
                      interval: intervalo,
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                        color: AppColors.border(context).withValues(alpha: 0.3),
                        strokeWidth: 0.5,
                        dashArray: [5, 5]);
                  },
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Media de gastos/dia:',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context))),
              AnimatedCounter(
                value: _mediaGastosDiaria,
                duration: const Duration(milliseconds: 800),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context)),
                formatter: (val) => _formatarMoeda(val),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Maior gasto:',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context))),
              Expanded(
                child: AnimatedCounter(
                  value: _maiorGasto?.value ?? 0,
                  duration: const Duration(milliseconds: 800),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning),
                  formatter: (val) {
                    if (_maiorGasto != null) {
                      return '${_maiorGasto!.key} ${_formatarMoeda(val)}';
                    }
                    return 'Nenhum gasto';
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taxa de economia:',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context))),
              AnimatedCounter(
                value: _taxaEconomia,
                duration: const Duration(milliseconds: 800),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _taxaEconomia >= 0
                        ? AppColors.success
                        : AppColors.error),
                formatter: (val) => '${val.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUltimasTransacoesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Ultimas Transacoes',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              TextButton(
                onPressed: _irParaLancamentos,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child:
                    const Text('Ver todas ->', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ultimosLancamentos.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Nenhuma transacao recente',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary(context))),
              ),
            )
          else
            ..._ultimosLancamentos
                .map((transacao) => Material(
                      color: Colors.transparent,
                      child: _buildTransacaoItem(transacao),
                    ))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildTransacaoItem(Map<String, dynamic> transacao) {
    final isReceita = transacao['tipo'] == 'receita';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final icone = isReceita ? Icons.arrow_upward : Icons.arrow_downward;
    final prefixo = isReceita ? '+' : '-';
    final valor = (transacao['valor'] as num).toDouble();
    final data = DateTime.parse(transacao['data'].toString());
    final categoria = transacao['categoria']?.toString() ?? 'Outros';
    final categoriaCor = AppCategories.getColor(categoria);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _irParaLancamentos,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icone, color: cor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transacao['descricao']?.toString() ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary(context))),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: categoriaCor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(categoria,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary(context))),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedCounter(
                  value: valor,
                  duration: const Duration(milliseconds: 600),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: cor),
                  formatter: (val) => '$prefixo ${Formatador.moeda(val)}',
                ),
                const SizedBox(height: 2),
                Text(DateFormat('dd/MM').format(data),
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
