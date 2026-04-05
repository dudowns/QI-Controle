// lib/widgets/editar_provento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/provento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';

class EditarProventoModal extends StatefulWidget {
  final Map<String, dynamic> provento;
  final Function? onAtualizado;

  const EditarProventoModal({
    super.key,
    required this.provento,
    this.onAtualizado,
  });

  @override
  State<EditarProventoModal> createState() => _EditarProventoModalState();

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> provento,
    Function? onAtualizado,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: EditarProventoModal(
          provento: provento,
          onAtualizado: onAtualizado,
        ),
      ),
    );
  }
}

class _EditarProventoModalState extends State<EditarProventoModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _tickerController;
  late TextEditingController _valorController;
  late TextEditingController _quantidadeController;
  late TextEditingController _observacaoController;

  late DateTime _dataPagamento;
  late DateTime? _dataCom;
  bool _carregando = false;
  bool _temDataCom = false;

  @override
  void initState() {
    super.initState();
    _tickerController = TextEditingController(text: widget.provento['ticker']);
    _valorController = TextEditingController(
      text: (widget.provento['valor_por_cota'] ?? 0)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    _quantidadeController = TextEditingController(
      text: (widget.provento['quantidade'] ?? 1).toString(),
    );
    _observacaoController = TextEditingController(
      text: widget.provento['observacao'] ?? '',
    );

    _dataPagamento = DateTime.parse(widget.provento['data_pagamento']);

    if (widget.provento['data_com'] != null) {
      _dataCom = DateTime.parse(widget.provento['data_com']);
      _temDataCom = true;
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _valorController.dispose();
    _quantidadeController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataPagamento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataPagamento,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _dataPagamento = picked);
    }
  }

  Future<void> _selecionarDataCom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataCom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _dataCom = picked);
    }
  }

  Future<void> _atualizarProvento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final valor = double.parse(_valorController.text.replaceAll(',', '.'));
      final quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
      final total = valor * quantidade;

      final proventoAtualizado = {
        'id': widget.provento['id'],
        'ticker': _tickerController.text.toUpperCase(),
        'valor_por_cota': valor,
        'quantidade': quantidade,
        'total_recebido': total,
        'data_pagamento': _dataPagamento.toIso8601String(),
        'data_com': _temDataCom ? _dataCom?.toIso8601String() : null,
        'observacao': _observacaoController.text,
      };

      await _dbHelper.updateProvento(proventoAtualizado);

      if (mounted) {
        widget.onAtualizado?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Provento atualizado!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _mostrarErro('Erro ao atualizar: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _excluirProvento() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(
              'Excluir Provento',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja realmente excluir este provento?',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _carregando = true);
      try {
        await _dbHelper.deleteProvento(widget.provento['id']);
        widget.onAtualizado?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Provento excluído!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        _mostrarErro('Erro ao excluir: $e');
      } finally {
        if (mounted) setState(() => _carregando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔝 CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Editar Provento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: _excluirProvento,
                  tooltip: 'Excluir provento',
                ),
              ),
            ],
          ),
        ),

        // 📝 FORMULÁRIO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticker
                  Text(
                    'Ativo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tickerController,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Ex: PETR4, VALE3',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon: const Icon(Icons.trending_up,
                          color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite o ticker';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Valor e Quantidade (lado a lado)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Valor por cota',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _valorController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  color: AppColors.textPrimary(context)),
                              decoration: InputDecoration(
                                hintText: '0,00',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint(context)),
                                prefixIcon: const Icon(Icons.attach_money,
                                    color: AppColors.primary),
                                prefixText: 'R\$ ',
                                filled: true,
                                fillColor: AppColors.surface(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.border(context)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Digite o valor';
                                }
                                if (double.tryParse(
                                        value.replaceAll(',', '.')) ==
                                    null) {
                                  return 'Valor inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quantidade',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _quantidadeController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  color: AppColors.textPrimary(context)),
                              decoration: InputDecoration(
                                hintText: '1',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint(context)),
                                prefixIcon: const Icon(Icons.numbers,
                                    color: AppColors.primary),
                                filled: true,
                                fillColor: AppColors.surface(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.border(context)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Digite a quantidade';
                                }
                                if (double.tryParse(
                                        value.replaceAll(',', '.')) ==
                                    null) {
                                  return 'Quantidade inválida';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data de pagamento
                  Text(
                    'Data de pagamento',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selecionarDataPagamento,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dataPagamento),
                            style: TextStyle(
                                color: AppColors.textPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data COM (opcional)
                  Row(
                    children: [
                      Checkbox(
                        value: _temDataCom,
                        onChanged: (value) {
                          setState(() => _temDataCom = value!);
                        },
                        activeColor: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Possui data COM'),
                    ],
                  ),

                  if (_temDataCom) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selecionarDataCom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              _dataCom != null
                                  ? DateFormat('dd/MM/yyyy').format(_dataCom!)
                                  : 'Selecionar data COM',
                              style: TextStyle(
                                color: _dataCom != null
                                    ? AppColors.textPrimary(context)
                                    : AppColors.textHint(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Observação
                  Text(
                    'Observação (opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _observacaoController,
                    maxLines: 2,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Observações adicionais...',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon:
                          const Icon(Icons.note, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botões
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                                color: AppColors.textSecondary(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _carregando
                            ? const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : GradientButton(
                                text: 'ATUALIZAR',
                                onPressed: _atualizarProvento,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
