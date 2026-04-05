// lib/screens/novo_provento_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/gradient_button.dart';
import '../utils/formatters.dart';

class NovoProventoDialog extends StatefulWidget {
  const NovoProventoDialog({super.key});

  @override
  State<NovoProventoDialog> createState() => _NovoProventoDialogState();
}

class _NovoProventoDialogState extends State<NovoProventoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DBHelper();

  final _tickerController = TextEditingController();
  final _valorPorCotaController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _totalRecebidoController = TextEditingController();

  String _tipoProvento = 'Dividendo';
  DateTime? _dataPagamento;
  DateTime? _dataCom;

  final List<String> _tiposProvento = [
    'Dividendo',
    'Juros sobre Capital Próprio',
    'Rendimento',
    'Amortização',
  ];

  @override
  void dispose() {
    _tickerController.dispose();
    _valorPorCotaController.dispose();
    _quantidadeController.dispose();
    _totalRecebidoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(BuildContext context, bool isPagamento) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        if (isPagamento) {
          _dataPagamento = picked;
        } else {
          _dataCom = picked;
        }
      });
    }
  }

  Future<void> _salvarProvento() async {
    if (!_formKey.currentState!.validate()) return;

    final valorPorCota =
        double.tryParse(_valorPorCotaController.text.replaceAll(',', '.')) ?? 0;
    final quantidade = int.tryParse(_quantidadeController.text) ?? 1;
    final totalRecebido =
        double.tryParse(_totalRecebidoController.text.replaceAll(',', '.')) ??
            (valorPorCota * quantidade);

    final provento = {
      'ticker': _tickerController.text.trim().toUpperCase(),
      'tipo_provento': _tipoProvento,
      'valor_por_cota': valorPorCota,
      'quantidade': quantidade,
      'total_recebido': totalRecebido,
      'data_pagamento':
          _dataPagamento?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'data_com': _dataCom?.toIso8601String(),
    };

    try {
      await _dbHelper.insertProvento(provento);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Provento adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Provento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ticker
              TextFormField(
                controller: _tickerController,
                decoration: const InputDecoration(
                  labelText: 'Ticker',
                  hintText: 'Ex: PETR4, BBDC4',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sell),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tipo de Provento
              DropdownButtonFormField<String>(
                initialValue: _tipoProvento,
                items: _tiposProvento.map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _tipoProvento = value!),
                decoration: const InputDecoration(
                  labelText: 'Tipo de Provento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),

              // Valor por Cota
              TextFormField(
                controller: _valorPorCotaController,
                decoration: const InputDecoration(
                  labelText: 'Valor por Cota',
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'R\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  final val = double.tryParse(value.replaceAll(',', '.'));
                  if (val == null || val <= 0) {
                    return 'Digite um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quantidade
              TextFormField(
                controller: _quantidadeController,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  hintText: '1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  final val = int.tryParse(value);
                  if (val == null || val <= 0) {
                    return 'Digite uma quantidade válida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Total Recebido (opcional)
              TextFormField(
                controller: _totalRecebidoController,
                decoration: const InputDecoration(
                  labelText: 'Total Recebido (opcional)',
                  hintText: 'Se vazio, calcula automaticamente',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.summarize),
                  prefixText: 'R\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Data Pagamento
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _selecionarData(context, true),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _dataPagamento == null
                            ? 'Data Pagamento *'
                            : Formatador.data(_dataPagamento!),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Data Com (opcional)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _selecionarData(context, false),
                      icon: const Icon(Icons.event),
                      label: Text(
                        _dataCom == null
                            ? 'Data Com (opcional)'
                            : Formatador.data(_dataCom!),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        GradientButton(
          text: 'Salvar',
          onPressed: _salvarProvento,
        ),
      ],
    );
  }
}
