// lib/screens/dashboard.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../constants/app_colors.dart';
import '../models/lancamento_model.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';
import '../widgets/animated_counter.dart';
import 'main_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  late final SupabaseService _supabaseService;

  @override
  bool get wantKeepAlive => true;

  DateTime mesAtual = DateTime.now();
  Map<String, dynamic>? dados;
  bool loading = true;
  String? erro;

  double _mediaGastosDiaria = 0;
  MapEntry<String, double>? _maiorGasto;
  double _taxaEconomia = 0;
  List<Map<String, dynamic>> _ultimos3Meses = [];
  List<Map<String, dynamic>> _ultimasTransacoes = [];

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _supabaseService = Provider.of<SupabaseService>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      erro = null;
    });

    try {
      final primeiroDia = DateTime(mesAtual.year, mesAtual.month, 1);
      final ultimoDia = DateTime(mesAtual.year, mesAtual.month + 1, 0);

      // Buscar lançamentos do mês
      final lancamentos = await _supabaseService.getLancamentos();

      // Filtrar pelo mês atual
      final lancamentosMes = lancamentos
          .where((l) =>
              l.data.isAfter(primeiroDia.subtract(const Duration(days: 1))) &&
              l.data.isBefore(ultimoDia.add(const Duration(days: 1))))
          .toList();

      // Calcular receitas e despesas
      double receitas = 0;
      double despesas = 0;
      final Map<String, double> gastosPorCategoria = {};

      for (var l in lancamentosMes) {
        if (l.tipo == TipoLancamento.receita) {
          receitas += l.valor;
        } else {
          despesas += l.valor;
          gastosPorCategoria[l.categoria] =
              (gastosPorCategoria[l.categoria] ?? 0) + l.valor;
        }
      }

      // Gastos por categoria
      final gastos = gastosPorCategoria.entries.map((entry) {
        return {
          'categoria': entry.key,
          'total': entry.value,
        };
      }).toList();
      gastos.sort(
          (a, b) => (b['total'] as double).compareTo(a['total'] as double));

      // Buscar últimas transações
      _ultimasTransacoes =
          await _supabaseService.getUltimasTransacoes(limit: 5);

      // Buscar evolução mensal
      await _carregarEvolucaoMensal();

      // Buscar contas pendentes
      final contasResponse = await _carregarContasPendentes();

      // Buscar patrimônio
      final patrimonio = await _carregarPatrimonio();

      // Buscar metas ativas
      final metas = await _supabaseService.getMetas();
      final metasAtivas = metas.where((m) => !m.concluida).length;

      _calcularEstatisticas(gastos, despesas, receitas);

      dados = {
        'receitas': receitas,
        'despesas': despesas,
        'saldo': receitas - despesas,
        'gastos': gastos,
        'contasPendentes': contasResponse['total'],
        'qtdContas': contasResponse['quantidade'],
        'patrimonio': patrimonio,
        'metasAtivas': metasAtivas,
        'ultimas_transacoes': _ultimasTransacoes,
      };
    } catch (e) {
      debugPrint('❌ Erro: $e');
      erro = "Erro ao carregar dados";
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _carregarEvolucaoMensal() async {
    _ultimos3Meses.clear();
    final todosLancamentos = await _supabaseService.getLancamentos();

    for (int i = 2; i >= 0; i--) {
      final data = DateTime(mesAtual.year, mesAtual.month - i, 1);
      final inicio = DateTime(data.year, data.month, 1);
      final fim = DateTime(data.year, data.month + 1, 0);

      double receitas = 0;
      double despesas = 0;

      for (var l in todosLancamentos) {
        if (l.data.isAfter(inicio.subtract(const Duration(days: 1))) &&
            l.data.isBefore(fim.add(const Duration(days: 1)))) {
          if (l.tipo == TipoLancamento.receita) {
            receitas += l.valor;
          } else {
            despesas += l.valor;
          }
        }
      }

      _ultimos3Meses.add({
        'mes': data.month,
        'receitas': receitas,
        'despesas': despesas,
      });
    }
  }

  Future<Map<String, dynamic>> _carregarContasPendentes() async {
    final contas = await _supabaseService.getContas();
    double total = 0;
    for (var conta in contas) {
      total += conta.valor;
    }
    return {'total': total, 'quantidade': contas.length};
  }

  Future<double> _carregarPatrimonio() async {
    final investimentos = await _supabaseService.getInvestimentos();
    double patrimonio = 0;
    for (var inv in investimentos) {
      patrimonio += inv.valorAtual;
    }
    return patrimonio;
  }

  void _calcularEstatisticas(
      List gastos, double despesasTotal, double receitasTotal) {
    final diasNoMes = DateTime(mesAtual.year, mesAtual.month + 1, 0).day;
    _mediaGastosDiaria = despesasTotal / diasNoMes;

    if (gastos.isNotEmpty) {
      MapEntry<String, double>? maior;
      for (var item in gastos) {
        final valor = (item['total'] as double);
        final categoria = item['categoria']?.toString() ?? 'Outros';
        if (maior == null || valor > maior.value) {
          maior = MapEntry(categoria, valor);
        }
      }
      _maiorGasto = maior;
    } else {
      _maiorGasto = null;
    }

    _taxaEconomia = receitasTotal > 0
        ? ((receitasTotal - despesasTotal) / receitasTotal) * 100
        : 0;
  }

  void _navegarMes(int delta) {
    setState(() {
      mesAtual = DateTime(mesAtual.year, mesAtual.month + delta);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (erro != null && dados == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(erro!,
                style: TextStyle(color: AppColors.textPrimary(context))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _carregarDados,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarDados,
      color: AppColors.primary,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_buildMonthSelector()],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard('Receitas', _toDouble(dados!['receitas']),
                    AppColors.success, Icons.trending_up),
                const SizedBox(width: 12),
                _buildStatCard('Despesas', _toDouble(dados!['despesas']),
                    AppColors.error, Icons.trending_down),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Contas Pendentes',
                  _toDouble(dados!['contasPendentes']),
                  AppColors.warning,
                  Icons.receipt,
                  subtitle: '${dados!['qtdContas']} conta(s)',
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Patrimônio',
                  _toDouble(dados!['patrimonio']),
                  AppColors.primary,
                  Icons.account_balance,
                  subtitle: '${dados!['metasAtivas']} meta(s) ativa(s)',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
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
            const SizedBox(height: 20),
            _buildUltimasTransacoesSection(),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
            '${_meses[mesAtual.month - 1]}. ${mesAtual.year}',
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
    final gastos = dados!['gastos'] as List;
    final despesasTotal = _toDouble(dados!['despesas']);

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
      final valor = _toDouble(item['total']);
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
    if (_ultimos3Meses.isEmpty) {
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
    for (var item in _ultimos3Meses) {
      final receitas = item['receitas'] as double;
      final despesas = item['despesas'] as double;
      if (receitas > maxValor) maxValor = receitas;
      if (despesas > maxValor) maxValor = despesas;
    }
    maxValor = maxValor * 1.2;
    if (maxValor == 0) maxValor = 100;

    final int numeroDeDivisoes = 4;
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
              Text('Receitas: ${_formatarMoeda(_toDouble(dados!['receitas']))}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.success)),
              Text('Despesas: ${_formatarMoeda(_toDouble(dados!['despesas']))}',
                  style: TextStyle(
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
                      final item = _ultimos3Meses[group.x.toInt()];
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
                barGroups: List.generate(_ultimos3Meses.length, (index) {
                  final item = _ultimos3Meses[index];
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
                        if (index >= 0 && index < _ultimos3Meses.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                                '${_meses[(_ultimos3Meses[index]['mes'] as int) - 1]}.',
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
                        color: AppColors.border(context).withOpacity(0.3),
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
              Text('📊 Média de gastos/dia:',
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
              Text('🏆 Maior gasto:',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context))),
              Expanded(
                child: AnimatedCounter(
                  value: _maiorGasto?.value ?? 0,
                  duration: const Duration(milliseconds: 800),
                  style: TextStyle(
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
              Text('💰 Taxa de economia:',
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
              Row(
                children: [
                  Icon(Icons.history, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Últimas Transações',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              TextButton(
                onPressed: () {
                  MainScreen.navigateTo(1);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child:
                    const Text('Ver todas →', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ultimasTransacoes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Nenhuma transação recente',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary(context))),
              ),
            )
          else
            ..._ultimasTransacoes
                .map((transacao) => _buildTransacaoItem(transacao)),
        ],
      ),
    );
  }

  Widget _buildTransacaoItem(Map<String, dynamic> transacao) {
    final isReceita = transacao['tipo'] == 'receita';
    final cor = isReceita ? AppColors.success : AppColors.error;
    final icone = isReceita ? Icons.arrow_upward : Icons.arrow_downward;
    final prefixo = isReceita ? '+' : '-';
    final valor = _toDouble(transacao['valor']);
    final data = DateTime.parse(transacao['data']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          MainScreen.navigateTo(1);
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: cor.withOpacity(0.1),
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
                  Text(transacao['categoria']?.toString() ?? 'Outros',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(context))),
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
