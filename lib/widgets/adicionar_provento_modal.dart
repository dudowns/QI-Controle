// lib/widgets/adicionar_provento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../widgets/gradient_button.dart';

class AdicionarProventoModal extends StatefulWidget {
  final Function? onSalvo;
  final List<String> tickersDisponiveis;

  const AdicionarProventoModal({
    super.key,
    this.onSalvo,
    required this.tickersDisponiveis,
  });

  @override
  State<AdicionarProventoModal> createState() => _AdicionarProventoModalState();

  static Future<void> show({
    required BuildContext context,
    required List<String> tickersDisponiveis,
    Function? onSalvo,
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
        child: AdicionarProventoModal(
          tickersDisponiveis: tickersDisponiveis,
          onSalvo: onSalvo,
        ),
      ),
    );
  }
}

class _AdicionarProventoModalState extends State<AdicionarProventoModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();

  String? _tickerSelecionado;
  DateTime _dataPagamento = DateTime.now();
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    if (widget.tickersDisponiveis.isNotEmpty) {
      _tickerSelecionado = widget.tickersDisponiveis.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 VERIFICAÇÃO MELHORADA!
    if (widget.tickersDisponiveis.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Adicionar Provento',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber,
                      size: 64,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nenhum investimento cadastrado',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Adicione um investimento primeiro\npara poder registrar proventos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    text: 'ADICIONAR INVESTIMENTO',
                    icon: Icons.trending_up,
                    onPressed: () {
                      Navigator.pop(context);
                      // Navegar para adicionar investimento
                      Navigator.pushNamed(context, '/add-investimento');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // 🔝 CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Adicionar Provento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: DropdownButton<String>(
                      value: _tickerSelecionado,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: Text(
                        'Selecione um ativo',
                        style: TextStyle(color: AppColors.textHint(context)),
                      ),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      items: widget.tickersDisponiveis.map((ticker) {
                        return DropdownMenuItem(
                          value: ticker,
                          child: Text(ticker),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _tickerSelecionado = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Valor
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
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'R\$ 0,00',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon:
                          Icon(Icons.attach_money, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite o valor';
                      }
                      if (double.tryParse(value.replaceAll(',', '.')) == null) {
                        return 'Valor inválido';
                      }
                      return null;
                    },
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
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _dataPagamento,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() => _dataPagamento = date);
                      }
                    },
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
                          Icon(Icons.calendar_today, color: AppColors.primary),
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
                                text: 'SALVAR',
                                onPressed: _salvarProvento,
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

  Future<void> _salvarProvento() async {
    if (_tickerSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um ativo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final provento = {
        'ticker': _tickerSelecionado,
        'valor_por_cota':
            double.parse(_valorController.text.replaceAll(',', '.')),
        'quantidade': 1,
        'data_pagamento': DateFormat('yyyy-MM-dd').format(_dataPagamento),
        'total_recebido':
            double.parse(_valorController.text.replaceAll(',', '.')),
      };

      await _dbHelper.insertProvento(provento);

      if (mounted) {
        widget.onSalvo?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Provento adicionado!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }
}
