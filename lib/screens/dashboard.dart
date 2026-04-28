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

  // ✅ ÚNICO MÉTODO ALTERADO
  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final metricas = await _dashboardService.getMetricasRapidas();
      _totalReceitas = metricas['receitas_mes'] ?? 0;
      _totalDespesas = metricas['despesas_mes'] ?? 0;
      _metasAtivas = metricas['metas_ativas'] ?? 0;

      final contasPendentes = await _dashboardService.getContasPendentesPorMes(
        _mesSelecionado.year,
        _mesSelecionado.month,
      );
      _totalContasPendentes = contasPendentes['valor_total'] ?? 0.0;
      _quantidadeContas = contasPendentes['quantidade'] ?? 0;

      _lancamentos = await _dbHelper.getAllLancamentos();

      // ✅ USA 'investments' E COLUNAS CORRETAS (preco_medio, data_compra)
      final db = await _dbHelper.database;
      final transacoes =
          await db.query('investments', orderBy: 'data_compra ASC');

      final Map<String, Map<String, dynamic>> agrupados = {};
      for (var tx in transacoes) {
        final ticker = tx['ticker']?.toString().toUpperCase() ?? '';
        if (ticker.isEmpty) continue;

        final tipo = tx['tipo_transacao']?.toString() ?? 'COMPRA';
        final quantidade = (tx['quantidade'] as num?)?.toDouble() ?? 0;
        final preco = (tx['preco_medio'] as num?)?.toDouble() ?? 0;

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
            existente['quantidade'] = novaQtd;
            existente['preco_medio'] =
                (valorAntigo + (quantidade * preco)) / novaQtd;
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
      if (mounted) Toast.error(context, 'Erro ao carregar dashboard');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularTotais() {
    double receitas = 0, despesas = 0;
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
      if ((meta['concluida'] as int) == 0) ativas++;
    }
    _metasAtivas = ativas;
  }

  void _calcularEstatisticas() {
    final lancamentosMes = _lancamentos.where((l) {
      final data = DateTime.parse(l['data'].toString());
      return data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month;
    }).toList();

    double despesasTotal = 0;
    final Map<String, double> gastosPorCategoria = {};
    for (var l in lancamentosMes) {
      if (l['tipo'] != 'receita') {
        final valor = (l['valor'] as num).toDouble();
        despesasTotal += valor;
        final cat = l['categoria']?.toString() ?? 'Outros';
        gastosPorCategoria[cat] = (gastosPorCategoria[cat] ?? 0) + valor;
      }
    }

    final diasNoMes =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0).day;
    _mediaGastosDiaria = despesasTotal / diasNoMes;

    if (gastosPorCategoria.isNotEmpty) {
      MapEntry<String, double>? maior;
      for (var entry in gastosPorCategoria.entries) {
        if (maior == null || entry.value > maior.value) maior = entry;
      }
      _maiorGasto = maior;
    } else {
      _maiorGasto = null;
    }

    double receitasTotal = 0;
    for (var l in lancamentosMes) {
      if (l['tipo'] == 'receita')
        receitasTotal += (l['valor'] as num).toDouble();
    }
    _taxaEconomia = receitasTotal > 0
        ? ((receitasTotal - despesasTotal) / receitasTotal) * 100
        : 0;
  }

  void _calcularEvolucaoMensal() {
    _evolucaoMensal.clear();
    for (int i = 2; i >= 0; i--) {
      final data = DateTime(_mesSelecionado.year, _mesSelecionado.month - i, 1);
      double receitas = 0, despesas = 0;
      for (var l in _lancamentos) {
        final dl = DateTime.parse(l['data'].toString());
        if (dl.year == data.year && dl.month == data.month) {
          if (l['tipo'] == 'receita') {
            receitas += (l['valor'] as num).toDouble();
          } else {
            despesas += (l['valor'] as num).toDouble();
          }
        }
      }
      _evolucaoMensal
          .add({'mes': data.month, 'receitas': receitas, 'despesas': despesas});
    }
  }

  void _calcularGastosPorCategoria() {
    final Map<String, double> gastos = {};
    double totalDespesas = 0;
    for (var l in _lancamentos) {
      final data = DateTime.parse(l['data'].toString());
      if (data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month) {
        if (l['tipo'] != 'receita') {
          final valor = (l['valor'] as num).toDouble();
          totalDespesas += valor;
          final cat = l['categoria']?.toString() ?? 'Outros';
          gastos[cat] = (gastos[cat] ?? 0) + valor;
        }
      }
    }
    _gastosPorCategoria = gastos.entries
        .map((e) => {
              'categoria': e.key,
              'total': e.value,
              'percentual':
                  totalDespesas > 0 ? (e.value / totalDespesas) * 100 : 0
            })
        .toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
  }

  void _carregarUltimosLancamentos() {
    _ultimosLancamentos = _lancamentos.where((l) {
      final data = DateTime.parse(l['data'].toString());
      return data.year == _mesSelecionado.year &&
          data.month == _mesSelecionado.month;
    }).toList()
      ..sort((a, b) => b['data'].compareTo(a['data']));
    _ultimosLancamentos = _ultimosLancamentos.take(5).toList();
  }

  void _navegarMes(int delta) {
    setState(() => _mesSelecionado =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1));
    _carregarDados();
  }

  String _formatarMoeda(double valor) => _realFormat.format(valor);
  String _formatarEixoY(double valor) => valor >= 1000
      ? '${(valor / 1000).toStringAsFixed(0)}k'
      : valor.toStringAsFixed(0);
  void _irParaLancamentos() => Navigator.pushNamed(context, '/lancamentos');

  // ========== BUILD (ORIGINAL COMPLETO) ==========
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _carregarDados,
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (c, o, child) => Opacity(
                opacity: o,
                child: Transform.translate(
                    offset: Offset(0, 50 * (1 - o)), child: child)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_buildMonthSelector()]),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (c, o, child) => Opacity(
                opacity: o,
                child: Transform.translate(
                    offset: Offset(0, 50 * (1 - o)), child: child)),
            child: Row(children: [
              _buildStatCard('Receitas', _totalReceitas, AppColors.success,
                  Icons.trending_up),
              const SizedBox(width: 12),
              _buildStatCard('Despesas', _totalDespesas, AppColors.error,
                  Icons.trending_down),
              const SizedBox(width: 12),
              _buildStatCard('Contas Pendentes', _totalContasPendentes,
                  AppColors.warning, Icons.receipt,
                  subtitle: '$_quantidadeContas conta(s)'),
              const SizedBox(width: 12),
              _buildStatCard('Patrimonio', _patrimonio, AppColors.primary,
                  Icons.account_balance,
                  subtitle: '$_metasAtivas meta(s) ativa(s)'),
            ]),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (c, o, child) => Opacity(
                opacity: o,
                child: Transform.translate(
                    offset: Offset(0, 50 * (1 - o)), child: child)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: _buildExpensesSection()),
              const SizedBox(width: 16),
              Expanded(
                  flex: 4,
                  child: Column(children: [
                    _buildIncomeExpenseChart(),
                    const SizedBox(height: 12),
                    _buildStatsCard()
                  ])),
            ]),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (c, o, child) => Opacity(
                opacity: o,
                child: Transform.translate(
                    offset: Offset(0, 50 * (1 - o)), child: child)),
            child: _buildUltimasTransacoesSection(),
          ),
        ]),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border(context))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => _navegarMes(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
        const SizedBox(width: 8),
        Text('${_meses[_mesSelecionado.month - 1]}. ${_mesSelecionado.year}',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context))),
        const SizedBox(width: 8),
        IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => _navegarMes(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
      ]),
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
            border: Border.all(color: AppColors.border(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          AnimatedCounter(
              value: value,
              duration: const Duration(milliseconds: 1000),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
              formatter: (val) => _formatarMoeda(val)),
          Text(title,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary(context))),
          if (subtitle != null)
            Text(subtitle,
                style: TextStyle(
                    fontSize: 10, color: AppColors.textSecondary(context))),
        ]),
      ),
    );
  }

  Widget _buildExpensesSection() {
    final gastos = _gastosPorCategoria;
    final despesasTotal = _totalDespesas;
    if (gastos.isEmpty)
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.cardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context))),
          child: Center(
              child: Text('Nenhum gasto registrado',
                  style: TextStyle(color: AppColors.textSecondary(context)))));
    final pizzaData = gastos.map((item) {
      final v = (item['total'] as num).toDouble();
      return {
        'categoria': item['categoria']?.toString() ?? 'Outros',
        'valor': v,
        'percentual': despesasTotal > 0 ? (v / despesasTotal) * 100 : 0,
        'cor': AppCategories.getColor(item['categoria']?.toString() ?? 'Outros')
      };
    }).toList()
      ..sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));
    final top = pizzaData.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Despesas por Categoria',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              flex: 5,
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: SizedBox(
                          height: 140,
                          width: 140,
                          child: PieChart(PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 35,
                              sections: top.map((item) {
                                final p = item['percentual'] as double;
                                return PieChartSectionData(
                                    value: item['valor'] as double,
                                    color: item['cor'] as Color,
                                    title:
                                        p > 6 ? '${p.toStringAsFixed(0)}%' : '',
                                    titleStyle: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    radius: 65);
                              }).toList())))))),
          const SizedBox(width: 16),
          Expanded(
              flex: 6,
              child: Column(
                  children: top.map((item) {
                final cat = item['categoria'] as String;
                final v = item['valor'] as double;
                final cor = item['cor'] as Color;
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary(context))),
                                AnimatedCounter(
                                    value: v,
                                    duration: const Duration(milliseconds: 800),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context)),
                                    formatter: (val) => _formatarMoeda(val))
                              ]),
                          const SizedBox(height: 4),
                          Container(height: 2, width: 35, color: cor)
                        ]));
              }).toList())),
        ]),
      ]),
    );
  }

  Widget _buildIncomeExpenseChart() {
    if (_evolucaoMensal.isEmpty)
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.cardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context))),
          child: Center(
              child: Text('Carregando dados...',
                  style: TextStyle(color: AppColors.textSecondary(context)))));
    double maxValor = 0;
    for (var item in _evolucaoMensal) {
      final r = item['receitas'] as double;
      final d = item['despesas'] as double;
      if (r > maxValor) maxValor = r;
      if (d > maxValor) maxValor = d;
    }
    maxValor = maxValor * 1.2;
    if (maxValor == 0) maxValor = 100;
    const int nd = 4;
    final double intervalo = maxValor / nd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Receitas vs Despesas',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
        ]),
        const SizedBox(height: 16),
        SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxValor,
              minY: 0,
              barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (g, gi, rod, ri) {
                        final item = _evolucaoMensal[g.x.toInt()];
                        final isR = ri == 0;
                        final v = isR
                            ? item['receitas'] as double
                            : item['despesas'] as double;
                        return BarTooltipItem(
                            '${isR ? 'Receitas' : 'Despesas'}\n${_formatarMoeda(v)}',
                            const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold));
                      },
                      tooltipBgColor: AppColors.primary,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8))),
              barGroups: List.generate(
                  _evolucaoMensal.length,
                  (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                            toY: _evolucaoMensal[i]['receitas'] as double,
                            color: AppColors.success,
                            width: 24,
                            borderRadius: BorderRadius.circular(6)),
                        BarChartRodData(
                            toY: _evolucaoMensal[i]['despesas'] as double,
                            color: AppColors.error,
                            width: 24,
                            borderRadius: BorderRadius.circular(6))
                      ],
                      barsSpace: 10)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i >= 0 && i < _evolucaoMensal.length)
                            return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    '${_meses[(_evolucaoMensal[i]['mes'] as int) - 1]}.',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)));
                          return const Text('');
                        },
                        reservedSize: 32)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, m) {
                          if (v == 0)
                            return Text('0',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary(context)));
                          if (v > 0 && v <= maxValor)
                            return Text(_formatarEixoY(v),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary(context)));
                          return const Text('');
                        },
                        interval: intervalo)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: AppColors.border(context).withValues(alpha: 0.3),
                      strokeWidth: 0.5,
                      dashArray: [5, 5])),
              borderData: FlBorderData(show: false),
            ))),
      ]),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context))),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
              formatter: (val) => _formatarMoeda(val))
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
                  formatter: (val) => _maiorGasto != null
                      ? '${_maiorGasto!.key} ${_formatarMoeda(val)}'
                      : 'Nenhum gasto'))
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Taxa de economia:',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary(context))),
          AnimatedCounter(
              value: _taxaEconomia,
              duration: const Duration(milliseconds: 800),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      _taxaEconomia >= 0 ? AppColors.success : AppColors.error),
              formatter: (val) => '${val.toStringAsFixed(1)}%')
        ]),
      ]),
    );
  }

  Widget _buildUltimasTransacoesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [
            Icon(Icons.history, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Ultimas Transacoes',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
          ]),
          TextButton(
              onPressed: _irParaLancamentos,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child:
                  const Text('Ver todas ->', style: TextStyle(fontSize: 11))),
        ]),
        const SizedBox(height: 12),
        if (_ultimosLancamentos.isEmpty)
          Center(
              child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Nenhuma transacao recente',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context)))))
        else
          ..._ultimosLancamentos
              .map((t) => Material(
                  color: Colors.transparent, child: _buildTransacaoItem(t)))
              .toList(),
      ]),
    );
  }

  Widget _buildTransacaoItem(Map<String, dynamic> t) {
    final isReceita = t['tipo'] == 'receita';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final icone = isReceita ? Icons.arrow_upward : Icons.arrow_downward;
    final prefixo = isReceita ? '+' : '-';
    final valor = (t['valor'] as num).toDouble();
    final data = DateTime.parse(t['data'].toString());
    final categoria = t['categoria']?.toString() ?? 'Outros';
    final categoriaCor = AppCategories.getColor(categoria);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
          onTap: _irParaLancamentos,
          borderRadius: BorderRadius.circular(8),
          child: Row(children: [
            Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icone, color: cor, size: 16)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t['descricao']?.toString() ?? '',
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
                            color: AppColors.textSecondary(context)))
                  ]),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              AnimatedCounter(
                  value: valor,
                  duration: const Duration(milliseconds: 600),
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: cor),
                  formatter: (val) => '$prefixo ${Formatador.moeda(val)}'),
              const SizedBox(height: 2),
              Text(DateFormat('dd/MM').format(data),
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary(context))),
            ]),
          ])),
    );
  }
}
