// lib/screens/renda_fixa_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../widgets/renda_fixa_modal.dart';
import '../widgets/detalhes_renda_fixa_modal.dart';
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
      debugPrint('❌ Erro ao carregar renda fixa: $e');
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

  Future<void> _adicionarInvestimento() async {
    await RendaFixaModal.show(
      context: context,
      onSalvar: (investimento) async {
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
            // 🔥 CORREÇÃO: Não tentar converter para int, manter como String
            json['id'] = investimento.id;
            await _dbHelper.updateRendaFixa(json);
          } else {
            await _dbHelper.insertRendaFixa(json);
          }

          await _carregarDados();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✏️ Investimento atualizado!'),
                backgroundColor: Colors.blue,
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
      },
    );
  }

  // 🔥 MÉTODO PARA ADICIONAR VALOR AO INVESTIMENTO (COM DATA)
  Future<void> _adicionarValorInvestimento(RendaFixaModel inv) async {
    final valorController = TextEditingController();
    DateTime dataDeposito = DateTime.now();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  Text(
                    'Investimento: ${inv.nome}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Valor atual:'),
                        Text(
                          CurrencyFormatter.format(inv.valorAplicado),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                    decoration: InputDecoration(
                      hintText: '0,00',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
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
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(dataDeposito),
                            style: const TextStyle(fontSize: 14),
                          ),
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey[500]),
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

        // 🔥 Salvar a data do depósito na observação (histórico)
        final dataFormatada = DateFormat('dd/MM/yyyy').format(dataDeposito);
        final observacaoAtual = inv.observacao ?? '';
        final novaObservacao = observacaoAtual.isEmpty
            ? 'Aporte: R\$ ${valorAdicional.toStringAsFixed(2)} em $dataFormatada'
            : '$observacaoAtual\nAporte: R\$ ${valorAdicional.toStringAsFixed(2)} em $dataFormatada';

        final investimentoAtualizado = inv.copyWith(
          valorAplicado: novoValorTotal,
          observacao: novaObservacao,
        );

        final json = investimentoAtualizado.toJson();
        if (inv.id != null && inv.id!.isNotEmpty) {
          json['id'] = inv.id; // 🔥 Manter como String
        }

        await _dbHelper.updateRendaFixa(json);
        await _carregarDados();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '✅ Adicionado R\$ ${valorAdicional.toStringAsFixed(2)} em $dataFormatada!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _excluirInvestimento(RendaFixaModel inv) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          // 🔥 CORREÇÃO: Converter String para int apenas se for necessário
          // O método deleteRendaFixa espera int, mas o ID pode ser String
          // Vamos usar o método genérico delete
          final db = await _dbHelper.database;
          await db.delete(
            'renda_fixa',
            where: 'id = ? OR remote_id = ?',
            whereArgs: [inv.id, inv.id],
          );
        }
        await _carregarDados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Investimento excluído!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _verDetalhes(RendaFixaModel inv) {
    DetalhesRendaFixaModal.show(
      context: context,
      investimento: inv,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary(context),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textPrimary(context)),
            onPressed: _carregarDados,
            tooltip: 'Atualizar',
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _adicionarInvestimento,
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
                                    _excluirInvestimento(inv);
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
                  color: _getCorTipo(inv.tipoRenda).withValues(alpha: 0.1),
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
                            color: _getCorTipo(inv.tipoRenda)
                                .withValues(alpha: 0.1),
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
                        color: cor.withValues(alpha: 0.1),
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
              // 🔥 BOTÕES: DEPÓSITO, EDITAR, EXCLUIR
              Row(
                children: [
                  // Botão Depositar (💰)
                  IconButton(
                    icon: Icon(Icons.account_balance_wallet,
                        size: 18, color: Colors.green[600]),
                    onPressed: () => _adicionarValorInvestimento(inv),
                    tooltip: 'Adicionar valor',
                  ),
                  // Botão Editar (✏️)
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                    onPressed: () => _editarInvestimento(inv),
                    tooltip: 'Editar',
                  ),
                  // Botão Excluir (🗑️)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: Colors.grey[600]),
                    onPressed: () => _excluirInvestimento(inv),
                    tooltip: 'Excluir',
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
}
