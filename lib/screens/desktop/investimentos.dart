// lib/screens/desktop/investimentos.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/repositories.dart';
import '../../models/investimento_model.dart';
import '../../services/renda_fixa_diaria.dart';
import '../../constants/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/adicionar_investimento_modal.dart';
import '../../widgets/toast.dart';
import '../../services/b3_service.dart';
import '../../services/services.dart';
import '../shared/transacoes_screen.dart'; // ✅ Para navegar para tela completa

class InvestimentosScreen extends StatefulWidget {
  const InvestimentosScreen({super.key});

  @override
  State<InvestimentosScreen> createState() => _InvestimentosScreenState();
}

class _InvestimentosScreenState extends State<InvestimentosScreen> {
  final RendaFixaRepository _rendaFixaRepo = RendaFixaRepository();
  final _supabase = Supabase.instance.client;
  final InvestmentInsightService _insightService = InvestmentInsightService();
  final SyncServiceImproved _syncImproved = SyncServiceImproved();

  List<Investimento> _investimentos = [];
  List<Map<String, dynamic>> _movimentacoes = []; // ✅ LISTA DE MOVIMENTAÇÕES
  bool _isLoading = true;
  bool _atualizandoCotacoes = false;
  bool _mostrarInsights = true;

  double _patrimonioTotal = 0;
  double _valorInvestido = 0;
  double _lucroTotal = 0;
  double _percentualGanho = 0;
  final double _proventosExemplo = 63.68;

  List<InvestmentInsight> _insights = [];

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
          await db.query('investments', orderBy: 'data_compra DESC');

      // ✅ CARREGA MOVIMENTAÇÕES (últimas 5)
      _movimentacoes = transacoes
          .take(5)
          .map((tx) => {
                'id': tx['id'],
                'remote_id': tx['remote_id'],
                'ticker': tx['ticker']?.toString().toUpperCase() ?? '',
                'tipo': tx['tipo_transacao']?.toString() ?? 'COMPRA',
                'tipo_investimento': tx['tipo']?.toString() ?? 'ACAO',
                'quantidade': (tx['quantidade'] as num?)?.toDouble() ?? 0,
                'preco': (tx['preco_medio'] as num?)?.toDouble() ?? 0,
                'data': tx['data_compra'] ?? DateTime.now().toIso8601String(),
              })
          .toList();

      // AGRUPA PARA CARTEIRA
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
      _gerarInsights();

      _syncImproved.syncAllData();
    } catch (e) {
      Toast.error(context, 'Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _gerarInsights() {
    _insights = _insightService.gerarInsights(_investimentos);
    setState(() {});
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

  // ✅ NAVEGA PARA TELA DE MOVIMENTAÇÕES COMPLETA
  void _irParaMovimentacoes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransacoesScreen(),
      ),
    ).then((_) => _carregarDados());
  }

  // ✅ EDITAR MOVIMENTAÇÃO
  Future<void> _editarMovimentacao(Map<String, dynamic> mov) async {
    final db = await _rendaFixaRepo.getDatabase();

    // Busca a transação completa
    final result = await db.query(
      'investments',
      where: 'id = ?',
      whereArgs: [mov['id']],
    );

    if (result.isEmpty) {
      Toast.error(context, 'Movimentação não encontrada');
      return;
    }

    final transacao = result.first;
    final quantidadeController = TextEditingController(
        text: (transacao['quantidade'] as num?)?.toString() ?? '');
    final precoController = TextEditingController(
        text: (transacao['preco_medio'] as num?)?.toString() ?? '');
    String tipoSelecionado =
        transacao['tipo_transacao']?.toString() ?? 'COMPRA';
    DateTime dataSelecionada =
        DateTime.tryParse(transacao['data_compra']?.toString() ?? '') ??
            DateTime.now();

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Editar Movimentação',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTipoButton(
                            '📈 COMPRA',
                            tipoSelecionado == 'COMPRA',
                            () => setStateDialog(
                                () => tipoSelecionado = 'COMPRA'),
                            Colors.green,
                            isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildTipoButton(
                            '📉 VENDA',
                            tipoSelecionado == 'VENDA',
                            () =>
                                setStateDialog(() => tipoSelecionado = 'VENDA'),
                            Colors.red,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantidadeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: precoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Preço Unitário',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dataSelecionada,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setStateDialog(() => dataSelecionada = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(Formatador.data(dataSelecionada)),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final quantidade = double.tryParse(quantidadeController.text);
                  final preco = double.tryParse(precoController.text);
                  if (quantidade == null || preco == null) {
                    Toast.error(context, 'Dados inválidos');
                    return;
                  }
                  Navigator.pop(context, {
                    'quantidade': quantidade,
                    'preco': preco,
                    'tipo': tipoSelecionado,
                    'data': dataSelecionada.toIso8601String(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado != null && mounted) {
      try {
        await db.update(
          'investments',
          {
            'quantidade': resultado['quantidade'],
            'preco_medio': resultado['preco'],
            'preco_atual': resultado['preco'],
            'tipo_transacao': resultado['tipo'],
            'data_compra': resultado['data'].toString().split('T')[0],
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [mov['id']],
        );

        // Tenta atualizar no Supabase
        try {
          final user = _supabase.auth.currentUser;
          if (user != null && mov['remote_id'] != null) {
            await _supabase
                .from('investments')
                .update({
                  'quantidade': resultado['quantidade'],
                  'preco_medio': resultado['preco'],
                  'preco_atual': resultado['preco'],
                  'tipo_transacao': resultado['tipo'],
                  'data_compra': resultado['data'].toString().split('T')[0],
                })
                .eq('id', mov['remote_id'])
                .eq('user_id', user.id);
          }
        } catch (e) {
          debugPrint('Erro ao atualizar Supabase: $e');
        }

        Toast.success(context, '✅ Movimentação atualizada!');
        _carregarDados();
      } catch (e) {
        Toast.error(context, 'Erro ao editar: $e');
      }
    }
  }

  // ✅ EXCLUIR MOVIMENTAÇÃO
  Future<void> _excluirMovimentacao(Map<String, dynamic> mov) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Movimentação'),
        content: Text(
          'Deseja excluir a movimentação de ${mov['ticker']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final db = await _rendaFixaRepo.getDatabase();

      // Exclui do banco local
      await db.delete(
        'investments',
        where: 'id = ?',
        whereArgs: [mov['id']],
      );

      // Exclui do Supabase se tiver remote_id
      if (mov['remote_id'] != null) {
        try {
          await _supabase
              .from('investments')
              .delete()
              .eq('id', mov['remote_id']);
        } catch (e) {
          debugPrint('Erro ao excluir do Supabase: $e');
        }
      }

      Toast.success(context, '✅ Movimentação excluída!');
      _carregarDados();
    } catch (e) {
      Toast.error(context, 'Erro ao excluir: $e');
    }
  }

  Widget _buildTipoButton(
    String label,
    bool selected,
    VoidCallback onTap,
    Color color,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? color
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInsightsSection(isDark),
                    const SizedBox(height: 16),
                    _buildSummarySection(isDark),
                    const SizedBox(height: 20),
                    _buildAtivosSection(isDark),
                    const SizedBox(height: 20),
                    _buildMovimentacoesSection(isDark),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // ✅ SEÇÃO DE MOVIMENTAÇÕES
  // ============================================================
  Widget _buildMovimentacoesSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Últimas Movimentações',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${_movimentacoes.length} movimentações recentes',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_movimentacoes.isNotEmpty)
                TextButton.icon(
                  onPressed: _irParaMovimentacoes,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label:
                      const Text('VER TODAS', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_movimentacoes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 40,
                        color: isDark ? Colors.grey[600] : Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma movimentação',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _mostrarModalAdicionar,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Adicionar compra/venda'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._movimentacoes.map((mov) => _buildMovimentacaoItem(mov, isDark)),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ ITEM DE MOVIMENTAÇÃO
  // ============================================================
  Widget _buildMovimentacaoItem(Map<String, dynamic> mov, bool isDark) {
    final isCompra = mov['tipo'] == 'COMPRA';
    final cor = isCompra ? AppColors.success : AppColors.error;
    final valorTotal = (mov['quantidade'] as double) * (mov['preco'] as double);
    final data = DateTime.parse(mov['data']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.grey[800]!.withValues(alpha: 0.3) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCompra ? Icons.trending_up : Icons.trending_down,
              color: cor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mov['ticker'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCompra ? 'COMPRA' : 'VENDA',
                        style: TextStyle(
                          fontSize: 9,
                          color: cor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${mov['quantidade']} × ${Formatador.moeda(mov['preco'])} = ${Formatador.moeda(valorTotal)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Text(
                  Formatador.data(data),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: () => _editarMovimentacao(mov),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.edit,
                      size: 16, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _excluirMovimentacao(mov),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INSIGHTS SECTION
  // ============================================================
  Widget _buildInsightsSection(bool isDark) {
    if (_insights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Insights da Carteira',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'IA',
                      style: TextStyle(
                        fontSize: 10,
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
                    '${_insights.length} insights',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _mostrarInsights ? Icons.expand_less : Icons.expand_more,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () =>
                        setState(() => _mostrarInsights = !_mostrarInsights),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          if (_mostrarInsights)
            ..._insights.map((insight) => _buildInsightCard(insight, isDark)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(InvestmentInsight insight, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[700]!.withValues(alpha: 0.3)
                  : insight.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(insight.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : insight.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.3,
                  ),
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

  Widget _buildSummarySection(bool isDark) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _cardIndicador("Patrimônio", _patrimonioTotal, _percentualGanho,
              AppColors.primary, isDark),
          _cardIndicador("Lucro", _lucroTotal, _percentualGanho,
              _lucroTotal >= 0 ? AppColors.success : AppColors.error, isDark),
          _cardIndicador("Rentabilidade", _percentualGanho, _percentualGanho,
              Colors.indigo, isDark,
              isPercent: true),
          _cardIndicador("Proventos (12M)", _proventosExemplo, 12.5,
              const Color(0xFF4CAF50), isDark),
        ],
      ),
    );
  }

  Widget _cardIndicador(
      String label, double val, double varPerc, Color cor, bool isDark,
      {String? infoExtra, bool isPercent = false}) {
    bool isPos = varPerc >= 0;

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
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
                        fontSize: 10,
                        color: isPos ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          if (infoExtra != null)
            Text(infoExtra,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAtivosSection(bool isDark) {
    if (_investimentos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded,
                size: 64, color: isDark ? Colors.grey[600] : Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Nenhum investimento cadastrado',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[500])),
            const SizedBox(height: 16),
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
        ..._investimentos.map((inv) => _buildAtivoItem(inv, isDark)),
      ],
    );
  }

  Widget _buildAtivoItem(Investimento inv, bool isDark) {
    bool isPos = inv.variacaoPercentual >= 0;
    final cor = isPos ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
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
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87)),
                Text("Qtd: ${inv.quantidade.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatador.moeda(inv.valorAtual),
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPos ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPos ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: isPos ? AppColors.success : AppColors.error),
                    const SizedBox(width: 2),
                    Text(
                      "${isPos ? '+' : ''}${inv.variacaoPercentual.toStringAsFixed(2)}%",
                      style: TextStyle(
                          fontSize: 11,
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
    );
  }
}
