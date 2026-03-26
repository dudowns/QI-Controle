// lib/screens/investimentos_tabs.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../repositories/investimento_repository.dart';
import '../repositories/provento_repository.dart';
import '../models/investimento_model.dart';
import '../models/provento_model.dart';
import '../services/yahoo_finance_service.dart';
import '../services/notification_service.dart';
import '../services/performance_service.dart';
import 'detalhes_ativo.dart';
import 'grafico_ativo.dart';
import 'proventos_screen.dart';
import 'lancamentos_investimentos_screen.dart';
import 'editar_investimento.dart';
import 'novo_investimento_dialog.dart';
import '../models/renda_fixa_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/primary_card.dart';
import '../widgets/gradient_card.dart';
import '../widgets/animated_counter.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/formatters.dart';
import '../widgets/grafico_evolucao.dart';
import '../widgets/adicionar_investimento_modal.dart'; // 🔥 NOVO IMPORT!

class InvestimentosTabsScreen extends StatefulWidget {
  const InvestimentosTabsScreen({super.key});

  @override
  State<InvestimentosTabsScreen> createState() =>
      _InvestimentosTabsScreenState();
}

class _InvestimentosTabsScreenState extends State<InvestimentosTabsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final InvestimentoRepository _investimentoRepo = InvestimentoRepository();
  final ProventoRepository _proventoRepo = ProventoRepository();
  final YahooFinanceService _yahooService = YahooFinanceService();

  late TabController _tabController;
  late AnimationController _animationController;

  List<Investimento> investimentos = [];
  List<Provento> proventos = [];
  List<Map<String, dynamic>> rendaFixa = [];

  bool carregando = true;
  bool _primeiraCarga = true;
  bool atualizando = false;

  // Estatísticas
  double patrimonioTotal = 0;
  double valorInvestido = 0;
  double ganhoCapital = 0;
  double dividendosRecebidos = 0;
  double proventos12Meses = 0;
  double proventosMesAtual = 0;
  double proventosProjetados = 0;

  // Dados para o gráfico de evolução
  List<Map<String, dynamic>> dadosEvolucao = [];

  final Map<String, double> valorPorTipo = {};
  final Map<String, double> proventosPorAtivo = {};
  List<MapEntry<String, double>> topAtivos = [];

  static const Color _profitText = AppColors.success;
  static const Color _lossText = AppColors.error;
  static final Color _profitBg = AppColors.success.withOpacity(0.1);
  static final Color _lossBg = AppColors.error.withOpacity(0.1);

  final Map<String, Color> coresPorTipo = {
    'ACAO': Colors.blue,
    'FII': Colors.green,
    'ETF': AppColors.primary,
    'BDR': Colors.orange,
    'CRIPTO': Colors.amber,
    'RENDA_FIXA': Colors.teal,
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    PerformanceService.start('carregarInvestimentos');

    setState(() {
      carregando = true;
      _primeiraCarga = false;
    });

    try {
      final investimentosData =
          await _investimentoRepo.getAllInvestimentosModel();
      investimentos = investimentosData;

      final proventosData = await _proventoRepo.getAll();
      proventos = proventosData;

      rendaFixa = await DBHelper().getAllRendaFixa();

      _calcularEstatisticas();
      _gerarDadosEvolucao();
    } catch (e) {
      debugPrint('❌ Erro ao carregar dados: $e');
    }

    PerformanceService.stop('carregarInvestimentos');

    setState(() {
      carregando = false;
    });
  }

  void _gerarDadosEvolucao() {
    dadosEvolucao.clear();

    Map<String, Map<String, double>> valoresPorMes = {};

    debugPrint('🔍 Processando investimentos para o gráfico...');

    for (var inv in investimentos) {
      final dataCompra = inv.dataCompra;

      final chaveMes =
          '${dataCompra.year}-${dataCompra.month.toString().padLeft(2, '0')}';

      if (!valoresPorMes.containsKey(chaveMes)) {
        valoresPorMes[chaveMes] = {
          'patrimonio': 0,
          'investido': 0,
        };
      }

      final valorInvestidoMes = inv.quantidade * inv.precoMedio;
      final valorPatrimonioMes =
          inv.quantidade * (inv.precoAtual ?? inv.precoMedio);

      valoresPorMes[chaveMes]!['investido'] =
          (valoresPorMes[chaveMes]!['investido'] ?? 0) + valorInvestidoMes;
      valoresPorMes[chaveMes]!['patrimonio'] =
          (valoresPorMes[chaveMes]!['patrimonio'] ?? 0) + valorPatrimonioMes;

      debugPrint(
          '   📌 ${inv.ticker}: Compra em ${dataCompra.month}/${dataCompra.year} - R\$ ${valorInvestidoMes.toStringAsFixed(2)}');
    }

    for (var rf in rendaFixa) {
      final dataAplicacao = DateTime.parse(rf['data_aplicacao'] as String);
      final chaveMes =
          '${dataAplicacao.year}-${dataAplicacao.month.toString().padLeft(2, '0')}';

      if (!valoresPorMes.containsKey(chaveMes)) {
        valoresPorMes[chaveMes] = {
          'patrimonio': 0,
          'investido': 0,
        };
      }

      final valorInvestidoMes = rf['valor'] as double;
      final valorPatrimonioMes =
          rf['valor_final'] as double? ?? valorInvestidoMes;

      valoresPorMes[chaveMes]!['investido'] =
          (valoresPorMes[chaveMes]!['investido'] ?? 0) + valorInvestidoMes;
      valoresPorMes[chaveMes]!['patrimonio'] =
          (valoresPorMes[chaveMes]!['patrimonio'] ?? 0) + valorPatrimonioMes;

      debugPrint(
          '   📌 Renda Fixa: Aplicação em ${dataAplicacao.month}/${dataAplicacao.year} - R\$ ${valorInvestidoMes.toStringAsFixed(2)}');
    }

    final mesesOrdenados = valoresPorMes.keys.toList()..sort();

    double patrimonioAcumulado = 0;
    double investidoAcumulado = 0;

    debugPrint('\n📊 Dados acumulados por mês:');

    for (String mes in mesesOrdenados) {
      final ano = int.parse(mes.split('-')[0]);
      final mesNum = int.parse(mes.split('-')[1]);

      if (ano > 2026 || (ano == 2026 && mesNum >= 1)) {
        final valores = valoresPorMes[mes]!;

        patrimonioAcumulado += valores['patrimonio']!;
        investidoAcumulado += valores['investido']!;

        dadosEvolucao.add({
          'data': DateTime(ano, mesNum, 1),
          'patrimonio': patrimonioAcumulado,
          'investido': investidoAcumulado,
        });

        debugPrint('   📊 Mês ${mesNum.toString().padLeft(2, '0')}/$ano:');
        debugPrint(
            '      Patrimônio: R\$ ${patrimonioAcumulado.toStringAsFixed(2)}');
        debugPrint(
            '      Investido:  R\$ ${investidoAcumulado.toStringAsFixed(2)}');
      }
    }

    debugPrint('\n✅ Total de meses com dados: ${dadosEvolucao.length}');
  }

  void _calcularEstatisticas() {
    patrimonioTotal = 0;
    valorInvestido = 0;
    dividendosRecebidos = 0;
    proventos12Meses = 0;
    proventosMesAtual = 0;
    proventosProjetados = 0;
    valorPorTipo.clear();
    proventosPorAtivo.clear();

    final agora = DateTime.now();
    final umAnoAtras = DateTime(agora.year - 1, agora.month, agora.day);
    final inicioMes = DateTime(agora.year, agora.month, 1);
    final fimMes = DateTime(agora.year, agora.month + 1, 0);

    final investimentosConsolidados =
        _investimentoRepo.consolidarInvestimentos(investimentos);

    for (var item in investimentosConsolidados) {
      patrimonioTotal += item.valorAtual;
      valorInvestido += item.valorInvestido;

      final tipo = item.tipo.nome;
      valorPorTipo[tipo] = (valorPorTipo[tipo] ?? 0) + item.valorAtual;
    }

    for (var item in rendaFixa) {
      final valorFinal = item['valor_final'] ?? item['valor'] ?? 0;
      patrimonioTotal += valorFinal;
      valorInvestido += (item['valor'] ?? 0);
      valorPorTipo['RENDA_FIXA'] =
          (valorPorTipo['RENDA_FIXA'] ?? 0) + valorFinal;
    }

    final Map<String, double> valorPorAtivo = {};
    for (var inv in investimentosConsolidados) {
      valorPorAtivo[inv.ticker] =
          (valorPorAtivo[inv.ticker] ?? 0) + inv.valorAtual;
    }

    final ativosOrdenados = valorPorAtivo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    topAtivos = ativosOrdenados.take(5).toList();

    for (var p in proventos) {
      dividendosRecebidos += p.totalRecebido;

      proventosPorAtivo[p.ticker] =
          (proventosPorAtivo[p.ticker] ?? 0) + p.totalRecebido;

      if (p.dataPagamento.isAfter(umAnoAtras)) {
        proventos12Meses += p.totalRecebido;
      }

      if (p.dataPagamento.isAfter(inicioMes) &&
          p.dataPagamento.isBefore(fimMes)) {
        proventosMesAtual += p.totalRecebido;
      }

      if (p.dataPagamento.isAfter(agora)) {
        proventosProjetados += p.totalRecebido;
      }
    }

    ganhoCapital = patrimonioTotal - valorInvestido;
  }

  Widget _buildGraficoPizza() {
    if (valorPorTipo.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Sem dados para exibir',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final cores = {
      'ACAO': Colors.blue,
      'FII': Colors.green,
      'RENDA_FIXA': Colors.orange,
      'CRIPTO': Colors.purple,
      'ETF': AppColors.primary,
      'BDR': Colors.teal,
    };

    final List<PieChartSectionData> sections = [];

    valorPorTipo.forEach((tipo, valor) {
      final percentual = (valor / patrimonioTotal) * 100;
      if (percentual > 0.5) {
        sections.add(PieChartSectionData(
          value: valor,
          color: cores[tipo] ?? Colors.grey,
          title: '${percentual.toStringAsFixed(1)}%',
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          radius: 70,
        ));
      }
    });

    return Container(
      height: 180,
      padding: const EdgeInsets.all(6),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 35,
          sections: sections,
        ),
      ),
    );
  }

  Widget _buildTopAtivos() {
    if (topAtivos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 TOP 5 ATIVOS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...topAtivos.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final ativo = entry.value.key;
            final valor = entry.value.value;
            final percentual = (valor / patrimonioTotal) * 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        '$index',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ativo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    Formatador.moedaCompacta(valor),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${percentual.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInvestimentoPorMes() {
    final Map<String, double> investidoPorMes = {};

    for (var inv in investimentos) {
      final dataCompra = inv.dataCompra;
      final chaveMes =
          '${dataCompra.month.toString().padLeft(2, '0')}/${dataCompra.year}';
      final valorInvestido = inv.quantidade * inv.precoMedio;

      investidoPorMes[chaveMes] =
          (investidoPorMes[chaveMes] ?? 0) + valorInvestido;
    }

    for (var rf in rendaFixa) {
      final dataAplicacao = DateTime.parse(rf['data_aplicacao'] as String);
      final chaveMes =
          '${dataAplicacao.month.toString().padLeft(2, '0')}/${dataAplicacao.year}';
      final valorInvestido = rf['valor'] as double;

      investidoPorMes[chaveMes] =
          (investidoPorMes[chaveMes] ?? 0) + valorInvestido;
    }

    final mesesOrdenados = investidoPorMes.keys.toList()
      ..sort((a, b) {
        final aParts = a.split('/');
        final bParts = b.split('/');
        final aDate = DateTime(int.parse(aParts[1]), int.parse(aParts[0]));
        final bDate = DateTime(int.parse(bParts[1]), int.parse(bParts[0]));
        return bDate.compareTo(aDate);
      });

    final ultimosMeses = mesesOrdenados.take(6).toList();

    if (ultimosMeses.isEmpty) {
      return const SizedBox.shrink();
    }

    final maiorValor = investidoPorMes.values.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.trending_up, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Investimento por Mês',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ultimosMeses.map((mes) {
            final valor = investidoPorMes[mes]!;
            final percentual = valor / maiorValor;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mes,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.border(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: MediaQuery.of(context).size.width *
                              0.3 *
                              percentual,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Formatador.moedaCompacta(valor),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total últimos 6 meses:',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
                Text(
                  Formatador.moedaCompacta(
                    ultimosMeses.fold(
                        0.0, (sum, mes) => sum + investidoPorMes[mes]!),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoEvolucao() {
    if (dadosEvolucao.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Sem dados históricos para exibir',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 400,
      margin: const EdgeInsets.only(top: 8),
      child: GraficoEvolucao(
        dados: dadosEvolucao,
        valorInvestido: valorInvestido,
        patrimonioAtual: patrimonioTotal,
      ),
    );
  }

  Widget _buildResumoCompacto() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoColuna('Aplicado', valorInvestido, Colors.blue),
          Container(height: 30, width: 1, color: AppColors.border(context)),
          _buildInfoColuna('Dividendos', dividendosRecebidos, Colors.green),
          Container(height: 30, width: 1, color: AppColors.border(context)),
          _buildInfoColuna('Ganho', ganhoCapital,
              ganhoCapital >= 0 ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _buildInfoColuna(String label, double valor, Color cor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedCounter(
          value: valor,
          formatter: Formatador.moedaCompacta,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Widget _buildPainelTab() {
    final rentabilidade = valorInvestido > 0
        ? ((patrimonioTotal - valorInvestido) / valorInvestido) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PATRIMÔNIO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatador.moeda(patrimonioTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: rentabilidade >= 0
                            ? _profitBg.withOpacity(0.2)
                            : _lossBg.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            rentabilidade >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 12,
                            color: rentabilidade >= 0 ? _profitText : _lossText,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${rentabilidade >= 0 ? '+' : ''}${rentabilidade.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  rentabilidade >= 0 ? _profitText : _lossText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'vs. investido',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildResumoCompacto(),
          const SizedBox(height: 12),
          _buildInvestimentoPorMes(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🥧 Distribuição',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 160,
                        child: _buildGraficoPizza(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: _buildTopAtivos(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Evolução Patrimonial',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                _buildGraficoEvolucao(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuCompraVenda() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'O que deseja fazer?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_up,
                      color: Colors.blue, size: 20),
                ),
                title: const Text(
                  'Comprar Ações/FIIs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text('Adicionar novo investimento',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _abrirDialogAdicionar(); // Agora usa o MODAL!
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.savings, color: Colors.teal, size: 20),
                ),
                title: const Text(
                  'Comprar Renda Fixa',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text('CDB, LCI, Tesouro, etc',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _abrirDialogRendaFixa();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.trending_down,
                      color: Colors.red, size: 20),
                ),
                title: const Text(
                  'Vender Ativo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: const Text('Registrar venda de um investimento',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _abrirDialogVenda();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🟢 AGORA USA O MODAL!
  Future<void> _abrirDialogAdicionar() async {
    await AdicionarInvestimentoModal.show(
      context: context,
      onSalvo: (investimento) {
        carregarDados();
      },
    );
  }

  void _abrirDialogRendaFixa() {
    showDialog(
      context: context,
      builder: (context) => NovoInvestimentoDialog(
        onSalvar: _salvarRendaFixa,
      ),
    );
  }

  void _abrirDialogVenda() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidade em desenvolvimento'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _salvarRendaFixa(RendaFixaModel investimento) async {
    try {
      await DBHelper().insertRendaFixa(investimento.toJson());
      await carregarDados();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${investimento.nome} adicionado!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _atualizarPrecos() async {
    setState(() => atualizando = true);

    int atualizados = 0;
    int comErro = 0;

    for (var item in investimentos) {
      if (item.id == null) continue;

      try {
        final preco = await _yahooService.getPrecoAtual(item.ticker);
        if (preco != null && preco > 0) {
          await _investimentoRepo.updatePrecoAtual(item.id!, preco);
          atualizados++;
        } else {
          comErro++;
        }
      } catch (e) {
        comErro++;
        debugPrint('❌ Erro ao atualizar ${item.ticker}: $e');
      }
    }

    await carregarDados();
    setState(() => atualizando = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$atualizados ativos atualizados${comErro > 0 ? ', $comErro erros' : ''}'),
          backgroundColor: comErro > 0 ? AppColors.warning : AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_primeiraCarga && carregando) {
      return const _InvestimentosSkeleton();
    }

    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        toolbarHeight: 50,
        title: const Text(
          'Investimentos',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(45),
          child: Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard, size: 18), text: 'PAINEL'),
                Tab(icon: Icon(Icons.history, size: 18), text: 'LANÇAMENTOS'),
                Tab(
                    icon: Icon(Icons.monetization_on, size: 18),
                    text: 'PROVENTOS'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: atualizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, size: 20),
            onPressed: atualizando ? null : _atualizarPrecos,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPainelTab(),
          LancamentosInvestimentosScreen(investimentos: investimentos),
          ProventosScreen(
            proventos: proventos,
            onRefresh: carregarDados,
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white, size: 24),
              onPressed: _mostrarMenuCompraVenda,
            )
          : null,
    );
  }
}

class _InvestimentosSkeleton extends StatelessWidget {
  const _InvestimentosSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SkeletonLoader(
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkeletonLoader(
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
