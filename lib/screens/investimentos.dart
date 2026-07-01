// lib/screens/investimentos.dart - VERSÃO CLEAN
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/repositories.dart';
import '../models/investimento_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/adicionar_investimento_modal.dart';
import '../widgets/toast.dart';
import '../services/b3_service.dart';

class InvestimentosScreen extends StatefulWidget {
  const InvestimentosScreen({super.key});

  @override
  State<InvestimentosScreen> createState() => _InvestimentosScreenState();
}

class _InvestimentosScreenState extends State<InvestimentosScreen> {
  final RendaFixaRepository _rendaFixaRepo = RendaFixaRepository();
  final _supabase = Supabase.instance.client;

  List<Investimento> _investimentos = [];
  bool _isLoading = true;
  bool _atualizandoCotacoes = false;

  double _patrimonioTotal = 0;
  double _valorInvestido = 0;
  double _lucroTotal = 0;
  double _percentualGanho = 0;
  final double _proventosExemplo = 63.68;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = await _rendaFixaRepo.getDatabase();
      final transacoes =
          await db.query('investments', orderBy: 'data_compra ASC');
      final Map<String, Investimento> agrupados = {};

      for (var tx in transacoes) {
        final ticker = tx['ticker']?.toString().toUpperCase() ?? '';
        final tipoTx = tx['tipo_transacao']?.toString() ?? 'COMPRA';
        final tipoInv = tx['tipo']?.toString() ?? 'ACAO';
        final quantidade = (tx['quantidade'] as num?)?.toDouble() ?? 0.0;
        final preco = (tx['preco_medio'] as num?)?.toDouble() ?? 0.0;

        if (!agrupados.containsKey(ticker)) {
          if (tipoTx == 'COMPRA') {
            agrupados[ticker] = Investimento(
              ticker: ticker,
              tipo: tipoInv,
              quantidade: quantidade,
              precoMedio: preco,
              precoAtual: (tx['preco_atual'] as num?)?.toDouble() ?? preco,
            );
          }
        } else {
          final e = agrupados[ticker]!;
          if (tipoTx == 'COMPRA') {
            final nQtd = e.quantidade + quantidade;
            final nPM = nQtd > 0
                ? ((e.quantidade * e.precoMedio) + (quantidade * preco)) / nQtd
                : 0.0;
            agrupados[ticker] = Investimento(
              ticker: ticker,
              tipo: tipoInv,
              quantidade: nQtd,
              precoMedio: nPM,
              precoAtual: e.precoAtual,
            );
          } else if (tipoTx == 'VENDA') {
            final nQtd =
                (e.quantidade - quantidade).clamp(0.0, double.infinity);
            if (nQtd < 0.001) {
              agrupados.remove(ticker);
            } else {
              agrupados[ticker] = Investimento(
                ticker: ticker,
                tipo: tipoInv,
                quantidade: nQtd,
                precoMedio: e.precoMedio,
                precoAtual: e.precoAtual,
              );
            }
          }
        }
      }
      _investimentos = agrupados.values.toList();
      _calcularMetricas();
    } catch (e) {
      Toast.error(context, 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _atualizarPrecos() async {
    if (_atualizandoCotacoes) return;
    setState(() => _atualizandoCotacoes = true);

    try {
      final tickers = _investimentos.map((inv) => inv.ticker).toList();
      if (tickers.isEmpty) {
        Toast.info(context, 'Nenhum ticker para atualizar');
        return;
      }

      final b3Service = B3Service();
      final resultados = await b3Service.getCotacoesEmLote(tickers);

      int atualizados = 0;
      for (var inv in _investimentos) {
        final cotacao = resultados[inv.ticker];
        if (cotacao != null && cotacao['preco'] != null) {
          final preco = cotacao['preco'] as double;
          if (preco > 0) {
            inv.precoAtual = preco;
            atualizados++;
          }
        }
      }

      _calcularMetricas();
      if (mounted) {
        if (atualizados > 0) {
          Toast.success(context, '✅ $atualizados cotações atualizadas!');
        } else {
          Toast.warning(context, '⚠️ Nenhuma cotação encontrada');
        }
      }
    } catch (e) {
      Toast.error(context, 'Erro ao atualizar cotações');
    } finally {
      if (mounted) setState(() => _atualizandoCotacoes = false);
    }
  }

  void _calcularMetricas() {
    double patrimonio = 0;
    double investido = 0;
    for (var i in _investimentos) {
      patrimonio += i.valorAtual;
      investido += i.valorInvestido;
    }
    _patrimonioTotal = patrimonio;
    _valorInvestido = investido;
    _lucroTotal = _patrimonioTotal - _valorInvestido;
    _percentualGanho =
        _valorInvestido > 0 ? (_lucroTotal / _valorInvestido) * 100 : 0;
  }

  void _mostrarModalAdicionar() {
    AdicionarInvestimentoModal.show(
      context: context,
      onSave: (i, t, d) => _carregarDados(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text("Investimentos",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: _atualizandoCotacoes
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded, size: 20),
            onPressed: _atualizandoCotacoes ? null : _atualizarPrecos,
            tooltip: 'Atualizar cotações',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _carregarDados,
            tooltip: 'Recarregar',
          ),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 22),
              onPressed: _mostrarModalAdicionar,
              tooltip: 'Adicionar',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarDados,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSummarySection(),
                    const SizedBox(height: 20),
                    _buildVisualDataSection(),
                    const SizedBox(height: 16),
                    _buildAtivosSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummarySection() {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _cardIndicador(
            "Patrimônio total",
            _patrimonioTotal,
            _percentualGanho,
            AppColors.primary,
          ),
          _cardIndicador(
            "Lucro total",
            _lucroTotal,
            _percentualGanho,
            _lucroTotal >= 0 ? AppColors.success : AppColors.error,
            infoExtra: "Proventos: R\$ 233",
          ),
          _cardIndicador(
            "Proventos (12M)",
            _proventosExemplo,
            12.5,
            const Color(0xFF4CAF50),
          ),
          _cardIndicador(
            "Rentabilidade",
            _percentualGanho,
            _percentualGanho,
            Colors.indigo,
            isPercent: true,
          ),
        ],
      ),
    );
  }

  Widget _cardIndicador(String label, double val, double varPerc, Color cor,
      {String? infoExtra, bool isPercent = false}) {
    bool isPos = varPerc >= 0;
    return Container(
      width: 175,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
        ],
        border: Border.all(color: cor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context))),
          const Spacer(),
          Row(
            children: [
              Text(
                isPercent
                    ? "${val.toStringAsFixed(2)}%"
                    : Formatador.moeda(val),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: cor),
              ),
              const SizedBox(width: 6),
              if (varPerc != 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPos ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${isPos ? '+' : ''}${varPerc.toStringAsFixed(1)}%",
                    style: TextStyle(
                        fontSize: 9,
                        color: isPos ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (infoExtra != null)
            Text(infoExtra,
                style: TextStyle(
                    fontSize: 9, color: AppColors.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildVisualDataSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Distribuição da Carteira",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 120,
                    child: PieChart(PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 35,
                      sections: _gerarSecoesDistribicao(),
                    )),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _gerarLegendasDistribicao(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAtivosSection() {
    final acoes =
        _investimentos.where((i) => i.tipo.toUpperCase() == 'ACAO').toList();
    final fiis =
        _investimentos.where((i) => i.tipo.toUpperCase() == 'FII').toList();
    final criptos =
        _investimentos.where((i) => i.tipo.toUpperCase() == 'CRIPTO').toList();

    if (_investimentos.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border(context).withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded,
                size: 48, color: AppColors.muted(context)),
            const SizedBox(height: 12),
            Text('Nenhum investimento cadastrado',
                style: TextStyle(color: AppColors.textSecondary(context))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _mostrarModalAdicionar,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar investimento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (acoes.isNotEmpty)
          _buildCategorySection('Ações', acoes, Icons.trending_up_rounded),
        if (fiis.isNotEmpty)
          _buildCategorySection('FIIs', fiis, Icons.apartment_rounded),
        if (criptos.isNotEmpty)
          _buildCategorySection(
              'Cripto', criptos, Icons.currency_bitcoin_rounded),
      ],
    );
  }

  Widget _buildCategorySection(
      String titulo, List<Investimento> ativos, IconData icone) {
    double total = ativos.fold(0, (sum, i) => sum + i.valorAtual);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(icone, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text("Valor total: ${Formatador.moeda(total)}",
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context))),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...ativos.map((inv) => _buildAtivoItem(inv)),
        ],
      ),
    );
  }

  Widget _buildAtivoItem(Investimento inv) {
    bool isPos = inv.variacaoPercentual >= 0;
    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: AppColors.border(context).withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isPos ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  inv.ticker.substring(
                      0, inv.ticker.length > 2 ? 2 : inv.ticker.length),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPos ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.ticker,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("Qtd: ${inv.quantidade.toStringAsFixed(0)}",
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatador.moeda(inv.valorAtual),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPos ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isPos ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 10,
                          color: isPos ? AppColors.success : AppColors.error),
                      const SizedBox(width: 2),
                      Text(
                        "${isPos ? '+' : ''}${inv.variacaoPercentual.toStringAsFixed(2)}%",
                        style: TextStyle(
                            fontSize: 10,
                            color: isPos ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _gerarSecoesDistribicao() {
    final categorias = ['ACAO', 'FII', 'CRIPTO'];
    final cores = [Colors.blue, Colors.green, Colors.orange];
    final nomes = ['Ações', 'FIIs', 'Cripto'];

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < categorias.length; i++) {
      double totalCat = _investimentos
          .where((inv) => inv.tipo.toUpperCase() == categorias[i])
          .fold(0, (sum, inv) => sum + inv.valorAtual);

      if (totalCat > 0) {
        sections.add(PieChartSectionData(
          value: totalCat,
          color: cores[i],
          radius: 14,
          showTitle: false,
        ));
      }
    }

    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        value: 1,
        color: Colors.grey,
        radius: 14,
        showTitle: false,
      ));
    }
    return sections;
  }

  List<Widget> _gerarLegendasDistribicao() {
    final categorias = ['Ações', 'FIIs', 'Cripto'];
    final cores = [Colors.blue, Colors.green, Colors.orange];
    List<Widget> legendas = [];

    for (int i = 0; i < categorias.length; i++) {
      double total = _investimentos
          .where((inv) =>
              {
                'ACAO': 'Ações',
                'FII': 'FIIs',
                'CRIPTO': 'Cripto'
              }[inv.tipo.toUpperCase()] ==
              categorias[i])
          .fold(0, (sum, inv) => sum + inv.valorAtual);

      if (total > 0) {
        legendas.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: cores[i], shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(categorias[i],
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ));
      }
    }
    return legendas;
  }
}
