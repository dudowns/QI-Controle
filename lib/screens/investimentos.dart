import '../services/logger_service.dart';
// lib/screens/investimentos.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../models/investimento_model.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_modals.dart';
import 'transacoes_screen.dart';

class InvestimentosScreen extends StatefulWidget {
  const InvestimentosScreen({super.key});

  @override
  State<InvestimentosScreen> createState() => _InvestimentosScreenState();
}

class _InvestimentosScreenState extends State<InvestimentosScreen> {
  final DBHelper _dbHelper = DBHelper();

  List<Investimento> _investimentos = [];
  List<Investimento> _investimentosFiltrados = [];
  List<Map<String, dynamic>> _ultimasTransacoes = [];

  bool _isLoading = true;
  bool _carregandoTransacoes = false;
  int _visualizacaoAtual = 0;
  String _filtroAtivo = 'Todos';

  double _patrimonioTotal = 0;
  double _valorInvestido = 0;
  double _ganhoPerda = 0;
  double _percentualGanho = 0;
  int _totalAtivos = 0;

  double _totalRendaFixa = 0;

  final Map<String, Color> _coresPorTipo = {
    'Ações': Colors.blue,
    'FIIs': Colors.green,
    'Cripto': Colors.orange,
    'Renda Fixa': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _carregarUltimasTransacoes();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dados = await _dbHelper.getAllInvestimentos();
      _investimentos =
          dados.map((json) => Investimento.fromJson(json)).toList();

      final rendaFixa = await _dbHelper.getAllRendaFixa();
      _totalRendaFixa = 0;
      final hoje = DateTime.now();

      for (var item in rendaFixa) {
        final inv = RendaFixaModel.fromJson(item);
        final valorHoje = RendaFixaDiaria.calcularValorEm(inv, hoje);
        _totalRendaFixa += valorHoje;
      }

      if (_totalRendaFixa > 0) {
        bool existeRendaFixa =
            _investimentos.any((inv) => inv.tipo.toUpperCase() == 'RENDA_FIXA');

        if (!existeRendaFixa) {
          _investimentos.add(Investimento(
            ticker: 'RENDA FIXA',
            tipo: 'RENDA_FIXA',
            quantidade: 1,
            precoMedio: _totalRendaFixa,
            precoAtual: _totalRendaFixa,
          ));
        } else {
          final index = _investimentos
              .indexWhere((inv) => inv.tipo.toUpperCase() == 'RENDA_FIXA');
          if (index != -1) {
            _investimentos[index] = Investimento(
              id: _investimentos[index].id,
              ticker: 'RENDA FIXA',
              tipo: 'RENDA_FIXA',
              quantidade: 1,
              precoMedio: _totalRendaFixa,
              precoAtual: _totalRendaFixa,
            );
          }
        }
      }

      _aplicarFiltro();
      _calcularTotais();
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar investimentos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calcularTotais() {
    double totalInvestido = 0;
    double totalAtual = 0;

    for (var inv in _investimentos) {
      if (inv.ticker != 'RENDA FIXA') {
        totalInvestido += inv.valorInvestido;
        totalAtual += inv.valorAtual;
      }
    }

    totalAtual += _totalRendaFixa;

    _valorInvestido = totalInvestido;
    _patrimonioTotal = totalAtual;
    _ganhoPerda = _patrimonioTotal - _valorInvestido;
    _percentualGanho =
        _valorInvestido > 0 ? (_ganhoPerda / _valorInvestido) * 100 : 0;
    _totalAtivos =
        _investimentos.where((inv) => inv.ticker != 'RENDA FIXA').length;
  }

  Future<void> _carregarUltimasTransacoes() async {
    setState(() => _carregandoTransacoes = true);
    try {
      final db = await _dbHelper.database;
      _ultimasTransacoes = await db.query(
        'transacoes',
        orderBy: 'data DESC',
        limit: 5,
      );
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar transações: $e');
      _ultimasTransacoes = [];
    } finally {
      setState(() => _carregandoTransacoes = false);
    }
  }

  void _aplicarFiltro() {
    setState(() {
      switch (_filtroAtivo) {
        case 'Ações':
          _investimentosFiltrados = _investimentos
              .where((inv) => inv.tipo.toUpperCase() == 'ACAO')
              .toList();
          break;
        case 'FIIs':
          _investimentosFiltrados = _investimentos
              .where((inv) => inv.tipo.toUpperCase() == 'FII')
              .toList();
          break;
        case 'Cripto':
          _investimentosFiltrados = _investimentos
              .where((inv) => inv.tipo.toUpperCase() == 'CRIPTO')
              .toList();
          break;
        case 'Renda Fixa':
          _investimentosFiltrados = _investimentos
              .where((inv) => inv.tipo.toUpperCase() == 'RENDA_FIXA')
              .toList();
          break;
        default:
          _investimentosFiltrados = List.from(_investimentos);
      }
    });
  }

  List<Map<String, dynamic>> get _dadosDistribuicao {
    final Map<String, double> valores = {
      'Ações': 0,
      'FIIs': 0,
      'Cripto': 0,
      'Renda Fixa': 0,
    };

    for (var inv in _investimentos) {
      final tipo = inv.tipo.toUpperCase();
      if (tipo == 'ACAO') {
        valores['Ações'] = (valores['Ações'] ?? 0) + inv.valorAtual;
      } else if (tipo == 'FII') {
        valores['FIIs'] = (valores['FIIs'] ?? 0) + inv.valorAtual;
      } else if (tipo == 'CRIPTO') {
        valores['Cripto'] = (valores['Cripto'] ?? 0) + inv.valorAtual;
      } else if (tipo == 'RENDA_FIXA') {
        valores['Renda Fixa'] = (valores['Renda Fixa'] ?? 0) + inv.valorAtual;
      }
    }

    return valores.entries.where((entry) => entry.value > 0).map((entry) {
      return {
        'categoria': entry.key,
        'valor': entry.value,
        'percentual':
            _patrimonioTotal > 0 ? (entry.value / _patrimonioTotal) * 100 : 0,
      };
    }).toList();
  }

  List<Investimento> get _top5Ativos {
    final Map<String, Investimento> agrupados = {};

    for (var inv in _investimentos) {
      if (inv.ticker == 'RENDA FIXA') continue;

      if (agrupados.containsKey(inv.ticker)) {
        final existente = agrupados[inv.ticker]!;
        final novaQuantidade = existente.quantidade + inv.quantidade;
        final novoPrecoMedio = ((existente.precoMedio * existente.quantidade) +
                (inv.precoMedio * inv.quantidade)) /
            novaQuantidade;

        agrupados[inv.ticker] = Investimento(
          id: existente.id,
          ticker: inv.ticker,
          tipo: inv.tipo,
          quantidade: novaQuantidade,
          precoMedio: novoPrecoMedio,
          precoAtual: inv.precoAtual ?? existente.precoAtual,
          dataCompra: existente.dataCompra,
          corretora: existente.corretora,
          setor: existente.setor,
          dividendYield: existente.dividendYield,
        );
      } else {
        agrupados[inv.ticker] = inv;
      }
    }

    final lista = agrupados.values.toList();
    lista.sort((a, b) => b.valorAtual.compareTo(a.valorAtual));
    return lista.take(5).toList();
  }

  Future<void> _adicionarInvestimento(Investimento investimento) async {
    try {
      await _dbHelper.insertInvestimento(investimento.toJson());
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${investimento.ticker} adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildResumoCards(),
                  const SizedBox(height: 20),
                  _buildToggleButtons(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _visualizacaoAtual == 0
                        ? _buildPainel()
                        : _buildListaAtivos(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Investimentos',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context))),
          _buildBotaoAdicionar(),
        ],
      ),
    );
  }

  Widget _buildResumoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildResumoCard('Patrimônio', _patrimonioTotal,
              Icons.account_balance_wallet, AppColors.primary,
              percentual: _percentualGanho),
          const SizedBox(width: 8),
          _buildResumoCard('Investido', _valorInvestido, Icons.trending_down,
              AppColors.info),
          const SizedBox(width: 8),
          _buildResumoCard('Ganho/Perda', _ganhoPerda.abs(), Icons.trending_up,
              _ganhoPerda >= 0 ? AppColors.success : AppColors.error,
              percentual: _percentualGanho, isPositive: _ganhoPerda >= 0),
          const SizedBox(width: 8),
          _buildResumoCard('Ativos', _totalAtivos.toDouble(), Icons.show_chart,
              AppColors.warning,
              isCount: true),
        ],
      ),
    );
  }

  Widget _buildResumoCard(
      String titulo, double valor, IconData icone, Color cor,
      {bool isCount = false, double? percentual, bool isPositive = true}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor.withValues(alpha:0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: cor.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icone, size: 14, color: cor)),
            const SizedBox(height: 8),
            Text(isCount ? valor.toStringAsFixed(0) : Formatador.moeda(valor),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
            if (percentual != null &&
                titulo != 'Investido' &&
                titulo != 'Ativos')
              Row(children: [
                Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 10,
                    color: isPositive ? AppColors.success : AppColors.error),
                const SizedBox(width: 2),
                Text(
                    '${isPositive ? '+' : ''}${percentual.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            isPositive ? AppColors.success : AppColors.error)),
              ]),
            const SizedBox(height: 2),
            Text(titulo,
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 36,
            width: 180,
            decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border(context))),
            child: Row(children: [
              _buildToggleButton('Painel', _visualizacaoAtual == 0,
                  () => setState(() => _visualizacaoAtual = 0)),
              _buildToggleButton('Ativos', _visualizacaoAtual == 1,
                  () => setState(() => _visualizacaoAtual = 1)),
            ]),
          ),
          if (_visualizacaoAtual == 1) _buildFiltros(),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(18)),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary(context)))),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    final List<String> filtros = [
      'Todos',
      'Ações',
      'FIIs',
      'Cripto',
      'Renda Fixa'
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: filtros.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final filtro = filtros[index];
          final isSelected = _filtroAtivo == filtro;
          return GestureDetector(
            onTap: () => setState(() {
              _filtroAtivo = filtro;
              _aplicarFiltro();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primary : AppColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border(context)),
              ),
              child: Text(filtro,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary(context))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBotaoAdicionar() {
    return ElevatedButton.icon(
      onPressed: _mostrarModalAdicionar,
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Adicionar',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    );
  }

  Widget _buildPainel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 5, child: _buildDistribuicaoCard()),
            const SizedBox(width: 12),
            Expanded(flex: 4, child: _buildTop5Card()),
          ]),
          const SizedBox(height: 16),
          _buildUltimasTransacoesCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDistribuicaoCard() {
    final distribuicao = _dadosDistribuicao;

    if (distribuicao.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context).withValues(alpha:0.5)),
        ),
        child: Center(
          child: Text(
            'Nenhum investimento cadastrado',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.border(context).withValues(alpha:0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF9D4EDD)]),
                    borderRadius: BorderRadius.circular(14)),
                child:
                    const Icon(Icons.pie_chart, size: 18, color: Colors.white)),
            const SizedBox(width: 12),
            const Text('Distribuição por Tipo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 130,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: distribuicao.asMap().entries.map((entry) {
                      final item = entry.value;
                      final percentual = item['percentual'] as double;
                      final categoria = item['categoria'] as String;
                      return PieChartSectionData(
                        value: item['valor'] as double,
                        color: _coresPorTipo[categoria] ?? Colors.grey,
                        title: percentual > 8
                            ? '${percentual.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        radius: 55,
                      );
                    }).toList(),
                  )),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 5,
                child: Column(
                  children: distribuicao.map((item) {
                    final categoria = item['categoria'] as String;
                    final valor = item['valor'] as double;
                    final percentual = item['percentual'] as double;
                    final cor = _coresPorTipo[categoria] ?? Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(categoria,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Container(height: 2, width: 30, color: cor),
                                  ])),
                          Expanded(
                              flex: 1,
                              child: Text('${percentual.toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          AppColors.textSecondary(context)))),
                          const SizedBox(width: 8),
                          Expanded(
                              flex: 1,
                              child: Text(Formatador.moeda(valor),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: cor))),
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

  Widget _buildTop5Card() {
    final top5 = _top5Ativos;

    if (top5.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context).withValues(alpha:0.5)),
        ),
        child: Center(
          child: Text(
            'Nenhum investimento',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.border(context).withValues(alpha:0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.orange, Color(0xFFFFA000)]),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.emoji_events,
                    size: 18, color: Colors.white)),
            const SizedBox(width: 12),
            const Text('Top 5 Ativos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          ...top5.asMap().entries.map((entry) {
            final index = entry.key;
            final inv = entry.value;
            final isPositive = inv.variacaoPercentual >= 0;
            final cor = isPositive ? AppColors.success : AppColors.error;

            final quantidade = inv.quantidade;
            final precoMedio = inv.precoMedio;
            final valorInvestido = inv.valorInvestido;
            final valorAtual = inv.valorAtual;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: index == 0
                                ? const LinearGradient(colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA000)
                                  ])
                                : index == 1
                                    ? const LinearGradient(colors: [
                                        Color(0xFFC0C0C0),
                                        Color(0xFF9E9E9E)
                                      ])
                                    : index == 2
                                        ? const LinearGradient(colors: [
                                            Color(0xFFCD7F32),
                                            Color(0xFF8D6E63)
                                          ])
                                        : LinearGradient(colors: [
                                            AppColors.muted(context),
                                            AppColors.muted(context)
                                                .withValues(alpha:0.7)
                                          ]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                              child: Text('${index + 1}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(inv.ticker,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textSecondary(context))),
                              const SizedBox(height: 2),
                              Text(
                                  '${quantidade.toStringAsFixed(0)} cotas · PM ${Formatador.moeda(precoMedio)}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textSecondary(context))),
                              Text('Inv: ${Formatador.moeda(valorInvestido)}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textSecondary(context))),
                            ]),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(Formatador.moeda(valorAtual),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: cor)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: cor.withValues(alpha:0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                Icon(
                                    isPositive
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 8,
                                    color: cor),
                                const SizedBox(width: 2),
                                Text(
                                    '${inv.variacaoPercentual.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 9, color: cor)),
                              ]),
                            ),
                          ]),
                    ],
                  ),
                ),
                if (index < top5.length - 1)
                  Divider(
                      height: 1,
                      thickness: 0.5,
                      color: AppColors.border(context)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUltimasTransacoesCard() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.border(context).withValues(alpha:0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.info, Color(0xFF0284C7)]),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.history,
                          size: 18, color: Colors.white)),
                  const SizedBox(width: 12),
                  const Text('Últimas Movimentações',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
                TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TransacoesScreen())),
                    child: const Text('Ver todas →',
                        style: TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 16),
            if (_carregandoTransacoes)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()))
            else if (_ultimasTransacoes.isEmpty)
              Column(children: [
                Icon(Icons.receipt, size: 48, color: AppColors.muted(context)),
                const SizedBox(height: 8),
                Text('Nenhuma movimentação ainda',
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ])
            else
              ..._ultimasTransacoes.take(3).map((t) => _buildTransacaoCard(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransacaoCard(Map<String, dynamic> t) {
    final isCompra = t['tipo_transacao'] == 'COMPRA';
    final cor = isCompra ? AppColors.success : AppColors.error;
    final quantidade = (t['quantidade'] as num).toDouble();
    final preco = (t['preco_unitario'] as num).toDouble();
    final taxa = (t['taxa'] as num?)?.toDouble() ?? 0;
    final total = quantidade * preco + taxa;
    final data = DateTime.parse(t['data']);
    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TransacoesScreen(ticker: t['ticker']))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: AppColors.border(context).withValues(alpha:0.5)))),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: cor.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(isCompra ? Icons.trending_up : Icons.trending_down,
                    color: cor, size: 18)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t['ticker'],
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                      '${quantidade.toStringAsFixed(2)} cotas × ${Formatador.moeda(preco)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary(context))),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Formatador.moeda(total),
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12, color: cor)),
              Text(Formatador.diaMes(data),
                  style: TextStyle(
                      fontSize: 9, color: AppColors.textSecondary(context))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildListaAtivos() {
    final Map<String, Investimento> ativosAgrupados = {};

    for (var inv in _investimentosFiltrados) {
      if (inv.ticker == 'RENDA FIXA') continue;

      if (ativosAgrupados.containsKey(inv.ticker)) {
        final existente = ativosAgrupados[inv.ticker]!;
        final novaQuantidade = existente.quantidade + inv.quantidade;
        final novoPrecoMedio = ((existente.precoMedio * existente.quantidade) +
                (inv.precoMedio * inv.quantidade)) /
            novaQuantidade;

        ativosAgrupados[inv.ticker] = Investimento(
          id: existente.id,
          ticker: inv.ticker,
          tipo: inv.tipo,
          quantidade: novaQuantidade,
          precoMedio: novoPrecoMedio,
          precoAtual: inv.precoAtual ?? existente.precoAtual,
          dataCompra: existente.dataCompra,
          corretora: existente.corretora,
          setor: existente.setor,
          dividendYield: existente.dividendYield,
        );
      } else {
        ativosAgrupados[inv.ticker] = inv;
      }
    }

    final listaAtivos = ativosAgrupados.values.toList();

    if (listaAtivos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: AppColors.muted(context)),
            const SizedBox(height: 16),
            Text('Nenhum investimento encontrado',
                style: TextStyle(color: AppColors.textSecondary(context))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _mostrarModalAdicionar,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar investimento'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: listaAtivos.length,
      itemBuilder: (context, index) {
        final inv = listaAtivos[index];
        final isPositive = inv.variacaoPercentual >= 0;
        final quantidade = inv.quantidade;
        final precoMedio = inv.precoMedio;
        final valorInvestido = inv.valorInvestido;
        final valorAtual = inv.valorAtual;

        return GestureDetector(
          onTap: () => _showDetalhes(inv),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (isPositive ? AppColors.success : AppColors.error)
                      .withValues(alpha:0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: TipoInvestimento.getCor(inv.tipo).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(
                          inv.ticker.substring(
                              0, inv.ticker.length > 2 ? 2 : inv.ticker.length),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TipoInvestimento.getCor(inv.tipo)))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(inv.ticker,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary(context))),
                      const SizedBox(height: 2),
                      Text(
                          '${quantidade.toStringAsFixed(0)} cotas · PM ${Formatador.moeda(precoMedio)}',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary(context))),
                      Text('Inv: ${Formatador.moeda(valorInvestido)}',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary(context))),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Formatador.moeda(valorAtual),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isPositive
                              ? AppColors.success
                              : AppColors.error)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color:
                            (isPositive ? AppColors.success : AppColors.error)
                                .withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(
                          isPositive
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 8,
                          color:
                              isPositive ? AppColors.success : AppColors.error),
                      const SizedBox(width: 2),
                      Text('${inv.variacaoPercentual.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 9,
                              color: isPositive
                                  ? AppColors.success
                                  : AppColors.error)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetalhes(Investimento inv) {
    final isPositive = inv.variacaoPercentual >= 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: TipoInvestimento.getCor(inv.tipo).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(
                    inv.ticker.substring(
                        0, inv.ticker.length > 2 ? 2 : inv.ticker.length),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TipoInvestimento.getCor(inv.tipo)))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(inv.ticker,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildDetalheLinha('Quantidade',
              '${inv.quantidade.toStringAsFixed(0)} cotas', Icons.numbers),
          _buildDetalheLinha('Preço Médio', Formatador.moeda(inv.precoMedio),
              Icons.monetization_on),
          _buildDetalheLinha(
              'Preço Atual',
              Formatador.moeda(inv.precoAtual ?? inv.precoMedio),
              Icons.trending_up),
          const Divider(),
          _buildDetalheLinha('Valor Investido',
              Formatador.moeda(inv.valorInvestido), Icons.attach_money,
              cor: Colors.blue),
          _buildDetalheLinha('Valor Atual', Formatador.moeda(inv.valorAtual),
              Icons.account_balance_wallet,
              cor: isPositive ? Colors.green : Colors.red),
          _buildDetalheLinha(
              'Variação',
              '${isPositive ? '+' : ''}${inv.variacaoPercentual.toStringAsFixed(2)}%',
              Icons.trending_up,
              cor: isPositive ? Colors.green : Colors.red),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _buildDetalheLinha(String label, String valor, IconData icon,
      {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(valor,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: cor)),
      ]),
    );
  }

  void _mostrarModalAdicionar() async {
    final resultado =
        await AppModals.mostrarModalInvestimento(context: context);
    if (resultado != null) {
      final novoInvestimento = Investimento(
        ticker: resultado['ticker'],
        tipo: resultado['tipo'],
        quantidade: resultado['quantidade'],
        precoMedio: resultado['preco_medio'],
        precoAtual: resultado['preco_atual'],
      );
      await _adicionarInvestimento(novoInvestimento);
    }
  }
}

// 🔥 CLASSE AUXILIAR PARA INVESTIMENTO (ADICIONADA NO FINAL)
class TipoInvestimento {
  static String getNomeAmigavel(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return 'Ações';
      case 'FII':
        return 'FIIs';
      case 'CRIPTO':
        return 'Cripto';
      case 'RENDA_FIXA':
        return 'Renda Fixa';
      default:
        return tipo;
    }
  }

  static Color getCor(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return Colors.blue;
      case 'FII':
        return Colors.green;
      case 'CRIPTO':
        return Colors.orange;
      case 'RENDA_FIXA':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

