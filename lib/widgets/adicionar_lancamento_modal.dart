// lib/widgets/adicionar_lancamento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../widgets/gradient_button.dart';

class AdicionarLancamentoModal extends StatefulWidget {
  final Function? onSalvo;

  const AdicionarLancamentoModal({super.key, this.onSalvo});

  @override
  State<AdicionarLancamentoModal> createState() =>
      _AdicionarLancamentoModalState();

  static Future<void> show({
    required BuildContext context,
    Function? onSalvo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AdicionarLancamentoModal(onSalvo: onSalvo),
      ),
    );
  }
}

class _AdicionarLancamentoModalState extends State<AdicionarLancamentoModal> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();

  String _tipoSelecionado = 'receita';
  String _categoriaSelecionada = 'Outros';
  DateTime _dataLancamento = DateTime.now();
  bool _carregando = false;

  final DBHelper _dbHelper = DBHelper();

  // ✅ CORRIGIDO: usando as listas corretas do AppCategories
  List<String> get _categoriasDisponiveis {
    if (_tipoSelecionado == 'receita') {
      return AppCategories.receitas;
    } else {
      return AppCategories.gastos;
    }
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
                'Novo Lançamento',
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
                  // Tipo (Receita/Despesa)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.muted(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTipoButton(
                            label: '💰 Receita',
                            value: 'receita',
                            icon: Icons.arrow_upward,
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildTipoButton(
                            label: '📉 Despesa',
                            value: 'despesa',
                            icon: Icons.arrow_downward,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Descrição
                  Text(
                    'Descrição',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descricaoController,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Ex: Salário, Mercado, etc',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon: const Icon(Icons.description,
                          color: AppColors.primary),
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
                        return 'Digite uma descrição';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Valor
                  Text(
                    'Valor',
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
                      prefixIcon: const Icon(Icons.attach_money,
                          color: AppColors.primary),
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

                  // Categoria
                  Text(
                    'Categoria',
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
                      value: _categoriaSelecionada,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      items: _categoriasDisponiveis.map((categoria) {
                        return DropdownMenuItem(
                          value: categoria,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppCategories.getColor(categoria),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(categoria),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _categoriaSelecionada = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data
                  Text(
                    'Data',
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
                        initialDate: _dataLancamento,
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
                        setState(() => _dataLancamento = date);
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
                          const Icon(Icons.calendar_today,
                              color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dataLancamento),
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
                                icon: Icons.check,
                                onPressed: _salvarLancamento,
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

  Widget _buildTipoButton({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _tipoSelecionado == value;

    return GestureDetector(
      onTap: () => setState(() => _tipoSelecionado = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? color : AppColors.textSecondary(context),
                size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarLancamento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final lancamento = {
        'descricao': _descricaoController.text,
        'valor': double.parse(_valorController.text.replaceAll(',', '.')),
        'tipo': _tipoSelecionado,
        'categoria': _categoriaSelecionada,
        'data': DateFormat('yyyy-MM-dd').format(_dataLancamento),
      };

      await _dbHelper.insertLancamento(lancamento);

      if (mounted) {
        widget.onSalvo?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Lançamento adicionado!'),
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
