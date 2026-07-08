// lib/screens/mobile/dashboard_mobile.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../repositories/repositories.dart';
import '../../constants/app_categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/animated_counter.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/toast.dart';
import '../../services/services.dart';
import '../../providers/layout_provider.dart';
import '../../services/sync_service_improved.dart';

class DashboardMobileScreen extends StatefulWidget {
  const DashboardMobileScreen({super.key});

  @override
  State<DashboardMobileScreen> createState() => _DashboardMobileScreenState();
}

class _DashboardMobileScreenState extends State<DashboardMobileScreen> {
  final LancamentoRepository _lancamentoRepository = LancamentoRepository();
  final MetaRepository _metaRepository = MetaRepository();
  final ContaRepository _contaRepository = ContaRepository();
  final DashboardService _dashboardService = DashboardService();
  final InsightService _insightService = InsightService();
  final SyncServiceImproved _syncImproved = SyncServiceImproved();

  List<Map<String, dynamic>> _lancamentos = [];
  List<Map<String, dynamic>> _investimentos = [];
  List<Map<String, dynamic>> _metas = [];

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

  List<Insight> _insights = [];
  String _mensagemMotivacional = '';
  double _previsaoGastos = 0;
  bool _mostrarInsights = true;

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
      // ✅ 1. PRIMEIRO carrega os dados locais
      final metricas = await _dashboardService.getMetricasRapidas();
      _totalReceitas = (metricas['receitas_mes'] ?? 0).toDouble();
      _totalDespesas = (metricas['despesas_mes'] ?? 0).toDouble();
      _metasAtivas = (metricas['metas_ativas'] ?? 0) as int;

      final contasPendentes = await _dashboardService.getContasPendentesPorMes(
        _mesSelecionado.year,
        _mesSelecionado.month,
      );
      _totalContasPendentes =
          (contasPendentes['valor_total'] ?? 0.0).toDouble();
      _quantidadeContas = (contasPendentes['quantidade'] ?? 0) as int;

      _lancamentos = await _lancamentoRepository.getAllLancamentos();
      _metas = await _metaRepository.getAllMetas();

      final db = await _contaRepository.getDatabase();
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
      _calcularTotais();
      _calcularEstatisticas();
      _calcularEvolucaoMensal();
      _calcularGastosPorCategoria();
      _carregarUltimosLancamentos();
      await _gerarInsights();

      // ✅ 2. DEPOIS sincroniza em background (sem await)
      _syncImproved.syncContasDoMes(
          _mesSelecionado.year, _mesSelecionado.month);
      _syncImproved.syncProventos();
      _syncImproved.syncAllData();
    } catch (e) {
      debugPrint('Erro ao carregar dashboard: $e');
      if (mounted) Toast.error(context, 'Erro ao carregar dashboard');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _gerarInsights() async {
    try {
      final insights = await _insightService.gerarInsights(
        lancamentos: _lancamentos,
        metas: _metas,
        totalReceitas: _totalReceitas,
        totalDespesas: _totalDespesas,
        mesSelecionado: _mesSelecionado,
      );
      _insights = insights;
      _mensagemMotivacional = _insightService.getMensagemMotivacional();
      _previsaoGastos = await _insightService.preverGastosProximoMes();
    } catch (e) {
      debugPrint('Erro ao gerar insights: $e');
    }
  }

  void _calcularTotais() {
    double receitas = 0, despesas = 0;
    for (var lancamento in _lancamentos) {
      try {
        final data = DateTime.parse(lancamento['data'].toString());
        if (data.year == _mesSelecionado.year &&
            data.month == _mesSelecionado.month) {
          final valor = (lancamento['valor'] as num).toDouble();
          if (lancamento['tipo'] == 'receita') {
            receitas += valor;
          } else {
            despesas += valor;
          }
        }
      } catch (e) {
        debugPrint('Erro ao processar lançamento: $e');
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
      if ((meta['concluida'] as int?) == 0) ativas++;
    }
    _metasAtivas = ativas;
  }

  void _calcularEstatisticas() {
    final lancamentosMes = _lancamentos.where((l) {
      try {
        final data = DateTime.parse(l['data'].toString());
        return data.year == _mesSelecionado.year &&
            data.month == _mesSelecionado.month;
      } catch (e) {
        return false;
      }
    }).toList();

    double despesasTotal = 0;
    double receitasTotal = 0;
    final Map<String, double> gastosPorCategoria = {};

    for (var l in lancamentosMes) {
      final valor = (l['valor'] as num).toDouble();
      if (l['tipo'] != 'receita') {
        despesasTotal += valor;
        final cat = l['categoria']?.toString() ?? 'Outros';
        gastosPorCategoria[cat] = (gastosPorCategoria[cat] ?? 0) + valor;
      } else {
        receitasTotal += valor;
      }
    }

    final diasNoMes =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0).day;
    _mediaGastosDiaria = diasNoMes > 0 ? despesasTotal / diasNoMes : 0;

    if (gastosPorCategoria.isNotEmpty) {
      MapEntry<String, double>? maior;
      for (var entry in gastosPorCategoria.entries) {
        if (maior == null || entry.value > maior.value) maior = entry;
      }
      _maiorGasto = maior;
    } else {
      _maiorGasto = null;
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
        try {
          final dl = DateTime.parse(l['data'].toString());
          if (dl.year == data.year && dl.month == data.month) {
            final valor = (l['valor'] as num).toDouble();
            if (l['tipo'] == 'receita') {
              receitas += valor;
            } else {
              despesas += valor;
            }
          }
        } catch (e) {
          debugPrint('Erro ao processar evolução mensal: $e');
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
      try {
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
      } catch (e) {
        debugPrint('Erro ao calcular gastos por categoria: $e');
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
      try {
        final data = DateTime.parse(l['data'].toString());
        return data.year == _mesSelecionado.year &&
            data.month == _mesSelecionado.month;
      } catch (e) {
        return false;
      }
    }).toList()
      ..sort((a, b) => b['data'].compareTo(a['data']));
    _ultimosLancamentos = _ultimosLancamentos.take(5).toList();
  }

  void _navegarMes(int delta) {
    setState(() => _mesSelecionado =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + delta, 1));
    _carregarDados();
  }

  String _formatarMoeda(double valor) {
    if (valor.isNaN || valor.isInfinite) return 'R\$ 0,00';
    return _realFormat.format(valor);
  }

  String _formatarEixoY(double valor) => valor >= 1000
      ? '${(valor / 1000).toStringAsFixed(0)}k'
      : valor.toStringAsFixed(0);

  void _irParaLancamentos() => Navigator.pushNamed(context, '/lancamentos');

  void _toggleInsights() {
    setState(() => _mostrarInsights = !_mostrarInsights);
  }

  Widget _buildStatCard(String title, double value, Color color, IconData icon,
      {String? subtitle}) {
    final displayValue = (value.isNaN || value.isInfinite) ? 0.0 : value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatarMoeda(displayValue),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Insight insight) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[800]!.withValues(alpha: 0.3)
            : insight.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark ? Colors.grey[700]! : insight.color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[700]!.withValues(alpha: 0.3)
                  : insight.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                insight.emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : insight.color,
                  ),
                ),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: insight.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _carregarDados,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightsSection(),
            Center(child: _buildMonthSelector()),
            const SizedBox(height: 12),
            _buildSaldoCard(),
            const SizedBox(height: 12),
            _buildMobileSummary(),
            const SizedBox(height: 12),
            _buildMotivationalMessage(),
            const SizedBox(height: 12),
            _buildExpensesSection(),
            const SizedBox(height: 12),
            _buildIncomeExpenseChart(),
            const SizedBox(height: 12),
            _buildStatsCard(),
            const SizedBox(height: 12),
            _buildUltimasTransacoesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    if (_insights.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'IA',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  _insights.length.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _mostrarInsights ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: _toggleInsights,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    ];

    if (_mostrarInsights) {
      children.addAll(_insights.map((insight) => _buildInsightCard(insight)));
    }

    children.add(const SizedBox(height: 4));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSaldoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _saldo >= 0
              ? [Colors.green.shade700, Colors.green.shade500]
              : [Colors.red.shade700, Colors.red.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SALDO DO MÊS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatarMoeda(_saldo),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSaldoItem(
                  'Receitas', _totalReceitas, Colors.green.shade300),
              const SizedBox(width: 10),
              _buildSaldoItem('Despesas', _totalDespesas, Colors.red.shade300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoItem(String label, double valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
            Text(
              _formatarMoeda(valor),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                size: 18, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => _navegarMes(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          Text(
            '${_meses[_mesSelecionado.month - 1]}. ${_mesSelecionado.year}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.chevron_right,
                size: 18, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => _navegarMes(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummary() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
            'Receitas', _totalReceitas, AppColors.success, Icons.trending_up),
        _buildStatCard(
            'Despesas', _totalDespesas, AppColors.error, Icons.trending_down),
        _buildStatCard('Contas Pendentes', _totalContasPendentes,
            AppColors.warning, Icons.receipt,
            subtitle: '$_quantidadeContas conta(s)'),
        _buildStatCard(
            'Patrimônio', _patrimonio, AppColors.primary, Icons.account_balance,
            subtitle: '$_metasAtivas meta(s)'),
      ],
    );
  }

  Widget _buildMotivationalMessage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.grey[800]!, Colors.grey[900]!]
              : [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.03)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.grey[700]!
              : AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _mensagemMotivacional,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesSection() {
    final gastos = _gastosPorCategoria;
    final despesasTotal = _totalDespesas;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gastos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Center(
          child: Text(
            'Nenhum gasto registrado',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    final pizzaData = gastos.map((item) {
      final v = (item['total'] as num).toDouble();
      return {
        'categoria': item['categoria']?.toString() ?? 'Outros',
        'valor': v,
        'percentual': despesasTotal > 0 ? (v / despesasTotal) * 100 : 0,
        'cor':
            AppCategories.getColor(item['categoria']?.toString() ?? 'Outros'),
      };
    }).toList()
      ..sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));

    final top = pizzaData.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Despesas por Categoria',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 110,
                  width: 110,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: top.map((item) {
                        final p = item['percentual'] as double;
                        return PieChartSectionData(
                          value: item['valor'] as double,
                          color: item['cor'] as Color,
                          title: p >= 5 ? '${p.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          radius: 50,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: Column(
                  children: top.map((item) {
                    final cat = item['categoria'] as String;
                    final v = item['valor'] as double;
                    final cor = item['cor'] as Color;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: cor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  cat,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _formatarMoeda(v),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_evolucaoMensal.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Center(
          child: Text(
            'Carregando dados...',
            style:
                TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      );
    }

    double maxValor = 0;
    for (var item in _evolucaoMensal) {
      final r = (item['receitas'] as num).toDouble();
      final d = (item['despesas'] as num).toDouble();
      if (r > maxValor) maxValor = r;
      if (d > maxValor) maxValor = d;
    }
    maxValor = maxValor * 1.2;
    if (maxValor == 0) maxValor = 100;
    final double intervalo = maxValor / 4;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receitas vs Despesas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Receitas: ${_formatarMoeda(_totalReceitas)}',
                style: const TextStyle(fontSize: 10, color: AppColors.success),
              ),
              Text(
                'Despesas: ${_formatarMoeda(_totalDespesas)}',
                style: const TextStyle(fontSize: 10, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
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
                          ? (item['receitas'] as num).toDouble()
                          : (item['despesas'] as num).toDouble();
                      return BarTooltipItem(
                        '${isR ? 'Receitas' : 'Despesas'}\n${_formatarMoeda(v)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                    tooltipBgColor: AppColors.primary,
                    tooltipRoundedRadius: 6,
                    tooltipPadding: const EdgeInsets.all(6),
                  ),
                ),
                barGroups: List.generate(
                  _evolucaoMensal.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (_evolucaoMensal[i]['receitas'] as num).toDouble(),
                        color: AppColors.success,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: (_evolucaoMensal[i]['despesas'] as num).toDouble(),
                        color: AppColors.error,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    barsSpace: 6,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i >= 0 && i < _evolucaoMensal.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _meses[(_evolucaoMensal[i]['mes'] as int) -
                                  1], // ← SEM ${}
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          );
                        }
                        return const Text(''); // ← Isso está correto aqui
                      },
                      reservedSize: 18,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (v, m) {
                        if (v == 0) {
                          return Text(
                            '0',
                            style: TextStyle(
                              fontSize: 8,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          );
                        }
                        if (v > 0 && v <= maxValor) {
                          return Text(
                            _formatarEixoY(v),
                            style: TextStyle(
                              fontSize: 8,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          );
                        }
                        return const Text('');
                      },
                      interval: intervalo,
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: isDark
                        ? Colors.grey[700]!.withValues(alpha: 0.3)
                        : Colors.grey[300]!.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                    dashArray: [3, 3],
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conselho = _insightService.getConselhoFinanceiro(
      _saldo,
      _totalReceitas,
      _totalDespesas,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Média gastos/dia:',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                _formatarMoeda(_mediaGastosDiaria),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maior gasto:',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Flexible(
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _maiorGasto != null
                        ? '${_maiorGasto!.key} ${_formatarMoeda(_maiorGasto!.value)}'
                        : 'Nenhum gasto',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taxa de economia:',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                '${_taxaEconomia.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color:
                      _taxaEconomia >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[800]!.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    conselho,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (_previsaoGastos > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.purple[900]!.withValues(alpha: 0.2)
                    : Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Colors.purple),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '🤖 Previsão próximo mês: ${_formatarMoeda(_previsaoGastos)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.purple[300] : Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUltimasTransacoesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final children = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Últimas Transações',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
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
            child: const Text('Ver todas ->', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
      const SizedBox(height: 10),
    ];

    if (_ultimosLancamentos.isEmpty) {
      children.add(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Nenhuma transação recente',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    } else {
      children.addAll(
        _ultimosLancamentos.map((t) => _buildTransacaoItem(t)).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: _irParaLancamentos,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[800]!.withValues(alpha: 0.3)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icone, color: cor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['descricao']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: categoriaCor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          categoria,
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd/MM').format(data),
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '$prefixo ${_formatarMoeda(valor)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
