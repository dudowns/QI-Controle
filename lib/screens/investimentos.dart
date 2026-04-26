// lib/screens/investimentos.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/db_helper.dart';
import '../models/investimento_model.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/adicionar_investimento_modal.dart';
import '../widgets/toast.dart';
import '../services/logger_service.dart';
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
  bool _atualizandoCotacoes = false;
  int _visualizacaoAtual = 0;
  String _filtroAtivo = 'Todos';

  double _patrimonioTotal = 0;
  double _valorInvestido = 0;
  double _ganhoPerda = 0;
  double _percentualGanho = 0;
  int _totalAtivos = 0;
  double _totalRendaFixa = 0;

  final Map<String, Color> _coresPorTipo = {
    'Acoes': Colors.blue,
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
      final db = await _dbHelper.database;
      final transacoes = await db.query('transacoes', orderBy: 'data ASC');

      final Map<String, Investimento> agrupados = {};

      for (var tx in transacoes) {
        final ticker = tx['ticker']?.toString().toUpperCase() ?? '';
        if (ticker.isEmpty) continue;

        final tipo = tx['tipo_transacao']?.toString() ?? 'COMPRA';
        final tipoInvestimento =
            tx['tipo_investimento']?.toString() ?? _obterTipoPorTicker(ticker);
        final quantidade = (tx['quantidade'] as num?)?.toDouble() ?? 0.0;
        final preco = (tx['preco_unitario'] as num?)?.toDouble() ?? 0.0;
        final taxa = (tx['taxa'] as num?)?.toDouble() ?? 0.0;
        final data = tx['data']?.toString() ?? DateTime.now().toIso8601String();

        if (!agrupados.containsKey(ticker)) {
          if (tipo == 'COMPRA') {
            agrupados[ticker] = Investimento(
              ticker: ticker,
              tipo: tipoInvestimento,
              quantidade: quantidade,
              precoMedio: preco,
              precoAtual: preco,
              dataCompra: data,
            );
          }
        } else {
          final existente = agrupados[ticker]!;

          if (tipo == 'COMPRA') {
            final novaQuantidade = existente.quantidade + quantidade;
            final valorTotalAntigo =
                existente.quantidade * existente.precoMedio;
            final valorNovaCompra = (quantidade * preco) + taxa;
            final novoPrecoMedio =
                (valorTotalAntigo + valorNovaCompra) / novaQuantidade;

            agrupados[ticker] = Investimento(
              ticker: ticker,
              tipo: tipoInvestimento,
              quantidade: novaQuantidade,
              precoMedio: novoPrecoMedio,
              precoAtual: existente.precoAtual,
              dataCompra: existente.dataCompra,
            );
          } else if (tipo == 'VENDA') {
            if (existente.quantidade >= quantidade) {
              final novaQuantidade = existente.quantidade - quantidade;
              if (novaQuantidade <= 0.001) {
                agrupados.remove(ticker);
              } else {
                agrupados[ticker] = Investimento(
                  ticker: ticker,
                  tipo: tipoInvestimento,
                  quantidade: novaQuantidade,
                  precoMedio: existente.precoMedio,
                  precoAtual: existente.precoAtual,
                  dataCompra: existente.dataCompra,
                );
              }
            }
          }
        }
      }

      _investimentos = agrupados.values.toList();
      _investimentos.sort((a, b) => a.ticker.compareTo(b.ticker));

      final rendaFixa = await _dbHelper.getAllRendaFixa();
      _totalRendaFixa = 0;
      final hoje = DateTime.now();

      for (var item in rendaFixa) {
        final inv = RendaFixaModel.fromJson(item);
        final valorHoje = RendaFixaDiaria.calcularValorEm(inv, hoje);
        _totalRendaFixa += valorHoje;
      }

      if (_totalRendaFixa > 0) {
        _investimentos.add(Investimento(
          ticker: 'RENDA FIXA',
          tipo: 'RENDA_FIXA',
          quantidade: 1,
          precoMedio: _totalRendaFixa,
          precoAtual: _totalRendaFixa,
        ));
      }

      _aplicarFiltro();
      _calcularTotais();
    } catch (e) {
      LoggerService.error('Erro ao carregar investimentos: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _obterTipoPorTicker(String ticker) {
    if (ticker.endsWith('11')) return 'FII';
    if (ticker.contains('BTC') || ticker.contains('ETH')) return 'CRIPTO';
    return 'ACAO';
  }

  Future<void> _atualizarPrecos() async {
    if (_atualizandoCotacoes) return;
    setState(() => _atualizandoCotacoes = true);
    try {
      // TODO: Implementar integracao com API de cotacoes (B3/Yahoo Finance)
      // Por enquanto, apenas simula a atualizacao
      await Future.delayed(const Duration(seconds: 1));
      _calcularTotais();
      if (mounted) {
        Toast.info(context, 'Funcionalidade de cotacoes em desenvolvimento');
      }
    } catch (e) {
      LoggerService.error('Erro ao atualizar cotacoes: $e');
      if (mounted) Toast.error(context, 'Erro ao atualizar: $e');
    } finally {
      if (mounted) setState(() => _atualizandoCotacoes = false);
    }
  }

  void _calcularTotais() {
    double totalInvestido = 0;
    double totalAtual = 0;
    int ativos = 0;

    for (var inv in _investimentos) {
      if (inv.ticker != 'RENDA FIXA') {
        totalInvestido += inv.valorInvestido;
        totalAtual += inv.valorAtual;
        ativos++;
      }
    }

    totalAtual += _totalRendaFixa;
    _valorInvestido = totalInvestido;
    _patrimonioTotal = totalAtual;
    _ganhoPerda = _patrimonioTotal - _valorInvestido;
    _percentualGanho =
        _valorInvestido > 0 ? (_ganhoPerda / _valorInvestido) * 100 : 0;
    _totalAtivos = ativos;
  }

  Future<void> _carregarUltimasTransacoes() async {
    setState(() => _carregandoTransacoes = true);
    try {
      final db = await _dbHelper.database;
      _ultimasTransacoes =
          await db.query('transacoes', orderBy: 'data DESC', limit: 5);
    } catch (e) {
      LoggerService.error('Erro ao carregar transacoes: $e');
      _ultimasTransacoes = [];
    } finally {
      if (mounted) setState(() => _carregandoTransacoes = false);
    }
  }

  void _aplicarFiltro() {
    setState(() {
      switch (_filtroAtivo) {
        case 'Acoes':
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
      'Acoes': 0,
      'FIIs': 0,
      'Cripto': 0,
      'Renda Fixa': 0
    };
    for (var inv in _investimentos) {
      final tipo = inv.tipo.toUpperCase();
      if (tipo == 'ACAO')
        valores['Acoes'] = (valores['Acoes'] ?? 0) + inv.valorAtual;
      else if (tipo == 'FII')
        valores['FIIs'] = (valores['FIIs'] ?? 0) + inv.valorAtual;
      else if (tipo == 'CRIPTO')
        valores['Cripto'] = (valores['Cripto'] ?? 0) + inv.valorAtual;
      else if (tipo == 'RENDA_FIXA')
        valores['Renda Fixa'] = (valores['Renda Fixa'] ?? 0) + inv.valorAtual;
    }
    return valores.entries.where((entry) => entry.value > 0).map((entry) {
      return {
        'categoria': entry.key,
        'valor': entry.value,
        'percentual':
            _patrimonioTotal > 0 ? (entry.value / _patrimonioTotal) * 100 : 0
      };
    }).toList();
  }

  List<Investimento> get _top5Ativos {
    final lista =
        _investimentos.where((inv) => inv.ticker != 'RENDA FIXA').toList();
    lista.sort((a, b) => b.valorAtual.compareTo(a.valorAtual));
    return lista.take(5).toList();
  }

  void _mostrarModalAdicionar() async {
    await AdicionarInvestimentoModal.show(
      context: context,
      onSave: (investimento, tipoTransacao, dataTransacao) async {
        await _adicionarInvestimento(
            investimento, tipoTransacao, dataTransacao);
      },
    );
  }

  Future<void> _adicionarInvestimento(Investimento investimento,
      String tipoTransacao, DateTime dataTransacao) async {
    try {
      final db = await _dbHelper.database;
      final total = investimento.quantidade * investimento.precoMedio;
      await db.insert('transacoes', {
        'ticker': investimento.ticker,
        'tipo_investimento': investimento.tipo,
        'tipo_transacao': tipoTransacao,
        'quantidade': investimento.quantidade,
        'preco_unitario': investimento.precoMedio,
        'taxa': 0.0,
        'total': total,
        'data': dataTransacao.toIso8601String(),
        'sync_status': 'pending',
      });
      await _carregarDados();
      await _carregarUltimasTransacoes();
      if (mounted) {
        Toast.success(context,
            '${investimento.ticker} ${tipoTransacao == 'COMPRA' ? 'adicionado' : 'vendido'}!');
        _atualizarPrecos();
      }
    } catch (e) {
      LoggerService.error('Erro: $e');
      if (mounted) Toast.error(context, 'Erro ao adicionar: $e');
    }
  }

  void _mostrarModalEditar(Investimento investimento) async {
    await AdicionarInvestimentoModal.show(
      context: context,
      investimento: investimento,
      onSave: (investimentoEditado, tipoTransacao, dataTransacao) async {
        Toast.info(context, 'Edicao apenas visual por enquanto');
      },
    );
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
                          : _buildListaAtivos()),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Investimentos',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context))),
        Row(children: [
          _buildBotaoAtualizarCotacoes(),
          const SizedBox(width: 8),
          _buildBotaoAdicionar(),
        ]),
      ]),
    );
  }

  Widget _buildBotaoAtualizarCotacoes() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: IconButton(
        icon: _atualizandoCotacoes
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))
            : const Icon(Icons.sync, color: AppColors.primary),
        onPressed: _atualizandoCotacoes ? null : _atualizarPrecos,
        tooltip: 'Atualizar cotacoes',
      ),
    );
  }

  Widget _buildResumoCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _buildResumoCard('Patrimonio', _patrimonioTotal,
            Icons.account_balance_wallet, AppColors.primary,
            percentual: _percentualGanho),
        const SizedBox(width: 8),
        _buildResumoCard(
            'Investido', _valorInvestido, Icons.trending_down, AppColors.info),
        const SizedBox(width: 8),
        _buildResumoCard('Ganho/Perda', _ganhoPerda.abs(), Icons.trending_up,
            _ganhoPerda >= 0 ? AppColors.success : AppColors.error,
            percentual: _percentualGanho, isPositive: _ganhoPerda >= 0),
        const SizedBox(width: 8),
        _buildResumoCard('Ativos', _totalAtivos.toDouble(), Icons.show_chart,
            AppColors.warning,
            isCount: true),
      ]),
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
            border: Border.all(color: cor.withValues(alpha: 0.2), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icone, size: 14, color: cor)),
          const SizedBox(height: 8),
          Text(isCount ? valor.toStringAsFixed(0) : Formatador.moeda(valor),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
          if (percentual != null && titulo != 'Investido' && titulo != 'Ativos')
            Row(children: [
              Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 10,
                  color: isPositive ? AppColors.success : AppColors.error),
              const SizedBox(width: 2),
              Text('${isPositive ? '+' : ''}${percentual.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 10,
                      color: isPositive ? AppColors.success : AppColors.error)),
            ]),
          const SizedBox(height: 2),
          Text(titulo,
              style: TextStyle(
                  fontSize: 9, color: AppColors.textSecondary(context))),
        ]),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
      ]),
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
      'Acoes',
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
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border(context))),
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
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: _buildDistribuicaoCard()),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: _buildTop5Card()),
        ]),
        const SizedBox(height: 16),
        _buildUltimasTransacoesCard(),
        const SizedBox(height: 20),
      ]),
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
            border: Border.all(
                color: AppColors.border(context).withValues(alpha: 0.5))),
        child: Center(
            child: Text('Nenhum investimento cadastrado',
                style: TextStyle(color: AppColors.textSecondary(context)))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.border(context).withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          const Text('Distribuicao por Tipo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
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
                  child: Row(children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(categoria,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Container(height: 2, width: 30, color: cor),
                          ]),
                    ),
                    Expanded(
                        flex: 1,
                        child: Text('${percentual.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context)))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 1,
                        child: Text(Formatador.moeda(valor),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cor))),
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ]),
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
            border: Border.all(
                color: AppColors.border(context).withValues(alpha: 0.5))),
        child: Center(
            child: Text('Nenhum investimento',
                style: TextStyle(color: AppColors.textSecondary(context)))),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.border(context).withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      gradient: index == 0
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)])
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
                                          .withValues(alpha: 0.7)
                                    ]),
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                      child: Text('${index + 1}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.ticker,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary(context))),
                        const SizedBox(height: 2),
                        Text(
                            '${inv.quantidade.toStringAsFixed(0)} cotas - PM ${Formatador.moeda(inv.precoMedio)}',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary(context))),
                        Text('Inv: ${Formatador.moeda(inv.valorInvestido)}',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary(context))),
                      ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(Formatador.moeda(inv.valorAtual),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cor)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(
                          isPositive
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 8,
                          color: cor),
                      const SizedBox(width: 2),
                      Text('${inv.variacaoPercentual.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 9, color: cor)),
                    ]),
                  ),
                ]),
              ]),
            ),
            if (index < top5.length - 1)
              Divider(
                  height: 1, thickness: 0.5, color: AppColors.border(context)),
          ]);
        }),
      ]),
    );
  }

  Widget _buildUltimasTransacoesCard() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.border(context).withValues(alpha: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.info, Color(0xFF0284C7)]),
                      borderRadius: BorderRadius.circular(14)),
                  child:
                      const Icon(Icons.history, size: 18, color: Colors.white)),
              const SizedBox(width: 12),
              const Text('Ultimas Movimentacoes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TransacoesScreen()));
                if (result == true) {
                  await _carregarUltimasTransacoes();
                  await _carregarDados();
                }
              },
              child: const Text('Ver todas ->', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 16),
          if (_carregandoTransacoes)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()))
          else if (_ultimasTransacoes.isEmpty)
            Column(children: [
              Icon(Icons.receipt, size: 48, color: AppColors.muted(context)),
              const SizedBox(height: 8),
              Text('Nenhuma movimentacao ainda',
                  style: TextStyle(color: AppColors.textSecondary(context))),
            ])
          else
            ..._ultimasTransacoes.take(3).map((t) => _buildTransacaoCard(t)),
        ]),
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
    final data = DateTime.parse(t['data'].toString());

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TransacoesScreen(ticker: t['ticker'])));
        if (result == true) {
          await _carregarUltimasTransacoes();
          await _carregarDados();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: AppColors.border(context).withValues(alpha: 0.5)))),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(isCompra ? Icons.trending_up : Icons.trending_down,
                  color: cor, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t['ticker'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                    '${quantidade.toStringAsFixed(2)} cotas x ${Formatador.moeda(preco)}',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary(context))),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Formatador.moeda(total),
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12, color: cor)),
            Text(Formatador.diaMes(data),
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary(context))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildListaAtivos() {
    if (_investimentosFiltrados.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _investimentosFiltrados.length,
      itemBuilder: (context, index) {
        final inv = _investimentosFiltrados[index];
        final isPositive = inv.variacaoPercentual >= 0;
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
                        .withValues(alpha: 0.3))),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: TipoInvestimento.getCor(inv.tipo)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                      child: Text(
                          inv.ticker.substring(
                              0, inv.ticker.length > 2 ? 2 : inv.ticker.length),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: TipoInvestimento.getCor(inv.tipo))))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(inv.ticker,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _mostrarModalEditar(inv),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit,
                                    size: 10, color: AppColors.info),
                                SizedBox(width: 2),
                                Text('Editar',
                                    style: TextStyle(
                                        fontSize: 9, color: AppColors.info)),
                              ]),
                        ),
                      ),
                    ]),
                    Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary(context))),
                    const SizedBox(height: 2),
                    Text(
                        '${inv.quantidade.toStringAsFixed(0)} cotas - PM ${Formatador.moeda(inv.precoMedio)}',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary(context))),
                    Text('Inv: ${Formatador.moeda(inv.valorInvestido)}',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary(context))),
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Formatador.moeda(inv.valorAtual),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color:
                            isPositive ? AppColors.success : AppColors.error)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: (isPositive ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward,
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
            ]),
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
                  color:
                      TipoInvestimento.getCor(inv.tipo).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(
                      inv.ticker.substring(
                          0, inv.ticker.length > 2 ? 2 : inv.ticker.length),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TipoInvestimento.getCor(inv.tipo))))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(inv.ticker,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ])),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildDetalheLinha('Quantidade',
              '${inv.quantidade.toStringAsFixed(0)} cotas', Icons.numbers),
          _buildDetalheLinha('Preco Medio', Formatador.moeda(inv.precoMedio),
              Icons.monetization_on),
          _buildDetalheLinha(
              'Preco Atual',
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
              'Variacao',
              '${isPositive ? '+' : ''}${inv.variacaoPercentual.toStringAsFixed(2)}%',
              Icons.trending_up,
              cor: isPositive ? Colors.green : Colors.red),
        ]),
        actions: [
          TextButton(
              onPressed: () => _mostrarModalEditar(inv),
              child: const Text('Editar')),
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
}
