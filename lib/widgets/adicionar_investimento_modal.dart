// lib/widgets/adicionar_investimento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/investimento_model.dart';
import '../services/investimento_service.dart';
import '../constants/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../utils/formatters.dart';

class AdicionarInvestimentoModal extends StatefulWidget {
  final Function(Investimento)? onSalvo;

  const AdicionarInvestimentoModal({super.key, this.onSalvo});

  @override
  State<AdicionarInvestimentoModal> createState() =>
      _AdicionarInvestimentoModalState();

  static Future<void> show({
    required BuildContext context,
    Function(Investimento)? onSalvo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AdicionarInvestimentoModal(onSalvo: onSalvo),
      ),
    );
  }
}

class _AdicionarInvestimentoModalState
    extends State<AdicionarInvestimentoModal> {
  final _formKey = GlobalKey<FormState>();
  final _tickerController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _precoController = TextEditingController();

  TipoInvestimento _tipoSelecionado = TipoInvestimento.acao;
  DateTime _dataCompra = DateTime.now();
  bool _carregando = false;

  final InvestimentoService _investimentoService = InvestimentoService();

  @override
  Widget build(BuildContext context) {
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
                'Adicionar Investimento',
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
                    'Ticker',
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
                      hintText: 'Ex: PETR4, VALE3, BBAS3',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon:
                          Icon(Icons.trending_up, color: AppColors.primary),
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

                  // Tipo
                  Text(
                    'Tipo',
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
                    child: DropdownButton<TipoInvestimento>(
                      value: _tipoSelecionado,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      items: TipoInvestimento.values.map((tipo) {
                        return DropdownMenuItem(
                          value: tipo,
                          child: Row(
                            children: [
                              Icon(
                                tipo.icone,
                                color: tipo.cor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(tipo.nomeAmigavel),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _tipoSelecionado = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantidade e Preço (lado a lado)
                  Row(
                    children: [
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
                              style: TextStyle(
                                  color: AppColors.textPrimary(context)),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0,00',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint(context)),
                                prefixIcon: Icon(Icons.numbers,
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
                                  return 'Obrigatório';
                                }
                                if (double.tryParse(
                                        value.replaceAll(',', '.')) ==
                                    null) {
                                  return 'Número inválido';
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
                              'Preço médio',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _precoController,
                              style: TextStyle(
                                  color: AppColors.textPrimary(context)),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'R\$ 0,00',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint(context)),
                                prefixIcon: Icon(Icons.attach_money,
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
                                  return 'Obrigatório';
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
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data da compra
                  Text(
                    'Data da compra',
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
                        initialDate: _dataCompra,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
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
                        setState(() => _dataCompra = date);
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
                            DateFormat('dd/MM/yyyy').format(_dataCompra),
                            style: TextStyle(
                                color: AppColors.textPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botões - CORRIGIDO!
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
                                icon: Icons.check,
                                onPressed: _salvarInvestimento,
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

  Future<void> _salvarInvestimento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final investimento = Investimento(
        ticker: _tickerController.text.toUpperCase(),
        tipo: _tipoSelecionado,
        quantidade:
            double.parse(_quantidadeController.text.replaceAll(',', '.')),
        precoMedio: double.parse(_precoController.text.replaceAll(',', '.')),
        dataCompra: _dataCompra,
      );

      await _investimentoService.salvar(investimento);

      if (mounted) {
        widget.onSalvo?.call(investimento);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Investimento adicionado!'),
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
