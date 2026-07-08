// lib/screens/mobile/renda_fixa_mobile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repositories/repositories.dart';
import '../../models/renda_fixa_model.dart';
import '../../services/renda_fixa_diaria.dart';
import '../../utils/formatters.dart';
import '../../widgets/renda_fixa_modal.dart';
import '../../widgets/detalhes_renda_fixa_modal.dart';
import '../../constants/app_colors.dart';
import '../../widgets/toast.dart';
import '../../services/sync_service_improved.dart';

class RendaFixaMobileScreen extends StatefulWidget {
  const RendaFixaMobileScreen({super.key});

  @override
  State<RendaFixaMobileScreen> createState() => _RendaFixaMobileScreenState();
}

class _RendaFixaMobileScreenState extends State<RendaFixaMobileScreen> {
  final RendaFixaRepository _repo = RendaFixaRepository();
  final SyncServiceImproved _syncImproved = SyncServiceImproved();

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
      // ✅ 1. PRIMEIRO carrega os dados locais
      _investimentos = await _repo.getAll();
      _calcularTotais();

      // ✅ 2. DEPOIS sincroniza em background
      _syncImproved.syncAllData();
    } catch (e) {
      debugPrint('Erro ao carregar renda fixa: $e');
      if (mounted) {
        Toast.error(context, 'Erro ao carregar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _adicionarInvestimento() async {
    await RendaFixaModal.show(
      context: context,
      onSalvar: (investimento) async {
        try {
          await _repo.insert(investimento);
          await _carregarDados();
          if (mounted) {
            Toast.success(context, '${investimento.nome} adicionado!');
          }
        } catch (e) {
          if (mounted) Toast.error(context, 'Erro: $e');
        }
      },
    );
  }

  Future<void> _editarInvestimento(RendaFixaModel inv) async {
    await RendaFixaModal.show(
      context: context,
      investimento: inv,
      onSalvar: (investimento) async {
        try {
          final json = investimento.toJson();
          if (investimento.id != null && investimento.id!.isNotEmpty) {
            json['id'] = investimento.id;
            await _repo.update(investimento);
          } else {
            await _repo.insert(investimento);
          }
          await _carregarDados();
          if (mounted) Toast.success(context, 'Investimento atualizado!');
        } catch (e) {
          if (mounted) Toast.error(context, 'Erro: $e');
        }
      },
    );
  }

  Future<void> _adicionarValorInvestimento(RendaFixaModel inv) async {
    final valorController = TextEditingController();
    DateTime dataDeposito = DateTime.now();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.attach_money, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text('Adicionar Valor',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Investimento: ${inv.nome}',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Valor atual:'),
                        Text(Formatador.moeda(inv.valorAplicado),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Valor do depósito',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: valorController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text('Data do depósito',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dataDeposito,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() => dataDeposito = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color:
                            isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(dataDeposito),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Icon(Icons.calendar_today,
                              size: 18,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[500]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('ADICIONAR'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar == true && valorController.text.isNotEmpty) {
      try {
        final valorAdicional =
            double.parse(valorController.text.replaceAll(',', '.'));
        if (valorAdicional <= 0) throw Exception('Valor inválido');
        final novoValorTotal = inv.valorAplicado + valorAdicional;
        final dataFormatada = DateFormat('dd/MM/yyyy').format(dataDeposito);
        final observacaoAtual = inv.observacao ?? '';
        final novaObservacao = observacaoAtual.isEmpty
            ? 'Aporte: R\$ ${valorAdicional.toStringAsFixed(2)} em $dataFormatada'
            : '$observacaoAtual\nAporte: R\$ ${valorAdicional.toStringAsFixed(2)} em $dataFormatada';
        final investimentoAtualizado = inv.copyWith(
          valorAplicado: novoValorTotal,
          observacao: novaObservacao,
        );
        await _repo.update(investimentoAtualizado);
        await _carregarDados();
        if (mounted) {
          Toast.success(context,
              'Adicionado R\$ ${valorAdicional.toStringAsFixed(2)} em $dataFormatada!');
        }
      } catch (e) {
        Toast.error(context, 'Erro: $e');
      }
    }
  }

  Future<void> _excluirInvestimento(RendaFixaModel inv) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Excluir Investimento'),
        content: Text('Deseja realmente excluir "${inv.nome}"?'),
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
    if (confirmar == true) {
      try {
        if (inv.id != null && inv.id!.isNotEmpty) {
          await _repo.delete(int.parse(inv.id!));
        }
        await _carregarDados();
        if (mounted) Toast.success(context, 'Investimento excluído!');
      } catch (e) {
        Toast.error(context, 'Erro ao excluir: $e');
      }
    }
  }

  void _verDetalhes(RendaFixaModel inv) {
    DetalhesRendaFixaModal.show(context: context, investimento: inv);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Renda Fixa',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
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
              onPressed: _adicionarInvestimento,
              tooltip: 'Adicionar',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _buildResumoCard(
                            'Aplicado', _totalAplicado, Colors.blue),
                        const SizedBox(width: 8),
                        _buildResumoCard(
                            'Valor Atual', _totalAtual, AppColors.primary),
                        const SizedBox(width: 8),
                        _buildResumoCard('Rendimento', _rendimentoTotal,
                            _rendimentoTotal >= 0 ? Colors.green : Colors.red),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _investimentos.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _carregarDados,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
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
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Excluir',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) =>
                                      _excluirInvestimento(inv),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titulo,
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                )),
            Text(Formatador.moeda(valor),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: cor,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings,
              size: 48, color: isDark ? Colors.grey[600] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Nenhum investimento em renda fixa',
              style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[500])),
          const SizedBox(height: 8),
          Text('Toque em + para começar',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              )),
        ],
      ),
    );
  }

  Widget _buildRendaFixaCard(RendaFixaModel inv) {
    final hoje = DateTime.now();
    final valorHoje = RendaFixaDiaria.calcularValorEm(inv, hoje);
    final rendimento = valorHoje - inv.valorAplicado;
    final isPositive = rendimento >= 0;
    final cor = isPositive ? Colors.green : Colors.red;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () => _verDetalhes(inv),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getCorTipo(inv.tipoRenda).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIconeTipo(inv.tipoRenda),
                    color: _getCorTipo(inv.tipoRenda), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.nome,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _getCorTipo(inv.tipoRenda)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(inv.tipoRenda,
                              style: TextStyle(
                                fontSize: 8,
                                color: _getCorTipo(inv.tipoRenda),
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                        const SizedBox(width: 6),
                        Text(Formatador.data(inv.dataVencimento),
                            style: TextStyle(
                              fontSize: 8,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[500],
                            )),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_getTaxaFormatada(inv)} - ${inv.liquidezDiaria ? "Liquidez Diária" : "No vencimento"}',
                      style: TextStyle(
                        fontSize: 8,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatador.moeda(valorHoje),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cor,
                      )),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
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
                          '${isPositive ? '+' : ''}${Formatador.moeda(rendimento)}',
                          style: TextStyle(
                            fontSize: 8,
                            color: cor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionIcon(
                        Icons.account_balance_wallet,
                        () => _adicionarValorInvestimento(inv),
                        color: Colors.green[600],
                        size: 14,
                      ),
                      const SizedBox(width: 4),
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

  Color _getCorTipo(String tipo) {
    switch (tipo) {
      case 'CDB':
        return Colors.blue;
      case 'LCI':
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
}
