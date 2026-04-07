import '../services/logger_service.dart';
// lib/screens/renda_fixa_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'novo_investimento_dialog.dart';
import 'detalhes_renda_fixa.dart';
import '../constants/app_colors.dart';

class RendaFixaScreen extends StatefulWidget {
  const RendaFixaScreen({super.key});

  @override
  State<RendaFixaScreen> createState() => _RendaFixaScreenState();
}

class _RendaFixaScreenState extends State<RendaFixaScreen> {
  final DBHelper _dbHelper = DBHelper();

  List<RendaFixaModel> _investimentos = [];
  bool _isLoading = true;

  double _totalAplicado = 0;
  double _totalAtual = 0;
  double _rendimentoTotal = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final dados = await _dbHelper.getAllRendaFixa();
      _investimentos =
          dados.map((json) => RendaFixaModel.fromJson(json)).toList();
      _calcularTotais();
    } catch (e) {
      LoggerService.info('❌ Erro ao carregar renda fixa: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calcularTotais() {
    final hoje = DateTime.now();
    double aplicado = 0;
    double atual = 0;

    for (var inv in _investimentos) {
      aplicado += inv.valorAplicado;
      final valorHoje = RendaFixaDiaria.calcularValorEm(inv, hoje);
      atual += valorHoje;
    }

    _totalAplicado = aplicado;
    _totalAtual = atual;
    _rendimentoTotal = atual - aplicado;
  }

  Future<void> _adicionarInvestimento(RendaFixaModel investimento) async {
    try {
      await _dbHelper.insertRendaFixa(investimento.toJson());
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${investimento.nome} adicionado!'),
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

  Future<void> _excluirInvestimento(int id, String nome) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Investimento'),
        content: Text('Deseja excluir "$nome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _dbHelper.deleteRendaFixa(id);
        await _carregarDados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ $nome excluído!'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () => _mostrarDialogAdicionar(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, size: 16),
                                SizedBox(width: 6),
                                Text('ADICIONAR',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildResumoCard(
                            'Aplicado', _totalAplicado, Colors.blue),
                        const SizedBox(width: 12),
                        _buildResumoCard(
                            'Valor Atual', _totalAtual, AppColors.primary),
                        const SizedBox(width: 12),
                        _buildResumoCard('Rendimento', _rendimentoTotal,
                            _rendimentoTotal >= 0 ? Colors.green : Colors.red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _investimentos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.savings,
                                    size: 64, color: AppColors.muted(context)),
                                const SizedBox(height: 16),
                                Text('Nenhum investimento em renda fixa',
                                    style: TextStyle(
                                        color:
                                            AppColors.textSecondary(context))),
                                const SizedBox(height: 8),
                                Text('Toque em ADICIONAR para começar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            AppColors.textSecondary(context))),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _carregarDados,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              itemCount: _investimentos.length,
                              itemBuilder: (context, index) {
                                final inv = _investimentos[index];
                                return Dismissible(
                                  key: Key(
                                      inv.id?.toString() ?? index.toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete,
                                        color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Excluir'),
                                        content: Text('Excluir "${inv.nome}"?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Excluir',
                                                  style: TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) {
                                    if (inv.id != null) {
                                      _excluirInvestimento(
                                          int.parse(inv.id!), inv.nome);
                                    }
                                  },
                                  child: _buildRendaFixaCard(inv),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildResumoCard(String titulo, double valor, Color cor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary(context))),
            const SizedBox(height: 2),
            Text(CurrencyFormatter.format(valor),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: cor)),
          ],
        ),
      ),
    );
  }

  Widget _buildRendaFixaCard(RendaFixaModel inv) {
    final hoje = DateTime.now();
    final valorHoje = RendaFixaDiaria.calcularValorEm(inv, hoje);
    final rendimento = valorHoje - inv.valorAplicado;
    final isPositive = rendimento >= 0;
    final cor = isPositive ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      elevation: 0,
      child: InkWell(
        onTap: () => _verDetalhes(inv),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getCorTipo(inv.tipoRenda).withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getIconeTipo(inv.tipoRenda),
                    color: _getCorTipo(inv.tipoRenda), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.nome,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCorTipo(inv.tipoRenda).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(inv.tipoRenda,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: _getCorTipo(inv.tipoRenda),
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 6),
                        Text(DateFormatter.formatDate(inv.dataVencimento),
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${_getTaxaFormatada(inv)} • ${inv.liquidezDiaria ? "Liquidez Diária" : "No vencimento"}',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(valorHoje),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cor)),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: cor.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 10,
                            color: cor),
                        const SizedBox(width: 2),
                        Text(
                            '${isPositive ? '+' : ''}${CurrencyFormatter.format(rendimento)}',
                            style: TextStyle(
                                fontSize: 9,
                                color: cor,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCorTipo(String tipo) {
    switch (tipo) {
      case 'CDB':
        return Colors.blue;
      case 'LCI':
        return Colors.green;
      case 'LCA':
        return Colors.green;
      case 'Tesouro Direto':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconeTipo(String tipo) {
    switch (tipo) {
      case 'CDB':
        return Icons.account_balance;
      case 'LCI':
        return Icons.apartment;
      case 'LCA':
        return Icons.apartment;
      case 'Tesouro Direto':
        return Icons.attach_money;
      default:
        return Icons.savings;
    }
  }

  String _getTaxaFormatada(RendaFixaModel inv) {
    switch (inv.indexador) {
      case Indexador.preFixado:
        return '${inv.taxa.toStringAsFixed(2)}% a.a.';
      case Indexador.posFixadoCDI:
        return '${inv.taxa.toStringAsFixed(0)}% do CDI';
      case Indexador.ipca:
        return 'IPCA + ${inv.taxa.toStringAsFixed(2)}%';
    }
  }

  void _mostrarDialogAdicionar() {
    showDialog(
      context: context,
      builder: (_) => NovoInvestimentoDialog(
        onSalvar: (investimento) async {
          await _adicionarInvestimento(investimento);
        },
      ),
    );
  }

  void _verDetalhes(RendaFixaModel inv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetalhesRendaFixaScreen(investimento: inv),
      ),
    ).then((_) => _carregarDados());
  }
}

