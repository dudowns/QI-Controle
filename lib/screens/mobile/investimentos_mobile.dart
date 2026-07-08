// lib/screens/mobile/investimentos_mobile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/app_modals.dart';
import '../../services/sync_service_improved.dart';

class InvestimentosMobileScreen extends StatefulWidget {
  const InvestimentosMobileScreen({super.key});

  @override
  State<InvestimentosMobileScreen> createState() =>
      _InvestimentosMobileScreenState();
}

class _InvestimentosMobileScreenState extends State<InvestimentosMobileScreen> {
  final RendaFixaRepository _rendaFixaRepo = RendaFixaRepository();
  final _supabase = Supabase.instance.client;
  final InvestmentInsightService _insightService = InvestmentInsightService();
  final SyncServiceImproved _syncImproved = SyncServiceImproved();

  List<Investimento> _investimentos = [];
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
      // ✅ 1. PRIMEIRO carrega os dados locais
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
      _gerarInsights();

      // ✅ 2. DEPOIS sincroniza em background
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

  void _mostrarModalAdicionar() {
    AdicionarInvestimentoModal.show(
      context: context,
      onSave: (i, t, d) => _carregarDados(),
    );
  }

  void _editarInvestimento(Investimento investimento) async {
    final result = await AppModals.mostrarModalInvestimento(
      context: context,
      investimento: investimento.toJson(),
    );

    if (result != null) {
      try {
        final db = await _rendaFixaRepo.getDatabase();

        final dados = {
          'ticker': result['ticker'],
          'tipo': result['tipo'],
          'quantidade': result['quantidade'],
          'preco_medio': result['preco_medio'],
          'preco_atual': result['preco_atual'] ?? result['preco_medio'],
          'data_compra': result['data_compra'],
          'updated_at': DateTime.now().toIso8601String(),
          'sync_status': 'pending',
        };

        await db.update(
          'investments',
          dados,
          where: 'id = ?',
          whereArgs: [investimento.id],
        );

        try {
          final user = _supabase.auth.currentUser;
          if (user != null && investimento.id != null) {
            await _supabase
                .from('investments')
                .update({
                  'ticker': result['ticker'],
                  'tipo': result['tipo'],
                  'quantidade': result['quantidade'],
                  'preco_medio': result['preco_medio'],
                  'preco_atual': result['preco_atual'] ?? result['preco_medio'],
                  'data_compra': result['data_compra'],
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', investimento.id!)
                .eq('user_id', user.id);
          }
        } catch (e) {
          debugPrint('Erro ao atualizar no Supabase: $e');
        }

        Toast.success(context, '✅ ${result['ticker']} atualizado!');
        _carregarDados();
      } catch (e) {
        Toast.error(context, 'Erro ao atualizar: $e');
      }
    }
  }

  void _excluirInvestimento(Investimento investimento) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Excluir Investimento'),
        content: Text(
          'Deseja excluir "${investimento.ticker}"?\n\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final db = await _rendaFixaRepo.getDatabase();

        await db.delete(
          'investments',
          where: 'id = ?',
          whereArgs: [investimento.id],
        );

        try {
          final user = _supabase.auth.currentUser;
          if (user != null && investimento.id != null) {
            await _supabase
                .from('investments')
                .delete()
                .eq('id', investimento.id!)
                .eq('user_id', user.id);
          }
        } catch (e) {
          debugPrint('Erro ao excluir no Supabase: $e');
        }

        Toast.success(context, '🗑️ ${investimento.ticker} excluído!');
        _carregarDados();
      } catch (e) {
        Toast.error(context, 'Erro ao excluir: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mensagemMotivacional = _insightService.getMensagemMotivacional();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text("Investimentos",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: _atualizandoCotacoes
                ? const SizedBox(
                    width: 18,
                    height: 18,
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMotivationalMessage(mensagemMotivacional, isDark),
                    const SizedBox(height: 12),
                    _buildInsightsSection(isDark),
                    const SizedBox(height: 12),
                    _buildResultCards(isDark),
                    const SizedBox(height: 16),
                    _buildAtivosSection(isDark),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMotivationalMessage(String mensagem, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
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

  Widget _buildInsightsSection(bool isDark) {
    if (_insights.isEmpty) return const SizedBox.shrink();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Insights da Carteira',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                    '${_insights.length}',
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
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[800]!.withValues(alpha: 0.3)
            : insight.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDark ? Colors.grey[700]! : insight.color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[700]!.withValues(alpha: 0.3)
                  : insight.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(insight.emoji, style: const TextStyle(fontSize: 14)),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : insight.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  insight.description,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: insight.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCards(bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _buildResultCard(
          'Patrimônio',
          _patrimonioTotal,
          _percentualGanho,
          AppColors.primary,
          Icons.account_balance_rounded,
          isDark,
        ),
        _buildResultCard(
          'Lucro/Perda',
          _lucroTotal,
          _percentualGanho,
          _lucroTotal >= 0 ? AppColors.success : AppColors.error,
          Icons.trending_up_rounded,
          isDark,
        ),
        _buildResultCard(
          'Rentabilidade',
          _percentualGanho,
          _percentualGanho,
          Colors.indigo,
          Icons.percent_rounded,
          isDark,
          isPercent: true,
        ),
        _buildResultCard(
          'Proventos (12M)',
          _proventosExemplo,
          12.5,
          const Color(0xFF4CAF50),
          Icons.payments_rounded,
          isDark,
        ),
      ],
    );
  }

  Widget _buildResultCard(
    String label,
    double value,
    double variacao,
    Color color,
    IconData icon,
    bool isDark, {
    bool isPercent = false,
  }) {
    final isPos = variacao >= 0;
    final displayValue = isPercent ? value : value;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const Spacer(),
              if (variacao != 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isPos ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${isPos ? '+' : ''}${variacao.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 8,
                      color: isPos ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isPercent
                ? "${displayValue.toStringAsFixed(2)}%"
                : Formatador.moeda(displayValue),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtivosSection(bool isDark) {
    if (_investimentos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded,
                size: 48, color: isDark ? Colors.grey[600] : Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Nenhum investimento cadastrado',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[500])),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _mostrarModalAdicionar,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Adicionar investimento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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

    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isPos ? AppColors.success : AppColors.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  inv.ticker.substring(
                      0, inv.ticker.length > 2 ? 2 : inv.ticker.length),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPos ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.ticker,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87)),
                  Text("Qtd: ${inv.quantidade.toStringAsFixed(0)}",
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[500])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatador.moeda(inv.valorAtual),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(
                      Icons.edit_rounded,
                      () => _editarInvestimento(inv),
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    _buildActionIcon(
                      Icons.delete_outline_rounded,
                      () => _excluirInvestimento(inv),
                      color: AppColors.error,
                      size: 14,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap,
      {Color? color, double size = 16}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: size, color: color ?? AppColors.primary),
      ),
    );
  }
}
