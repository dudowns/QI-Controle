// lib/widgets/nova_transacao_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';

class NovaTransacaoModal extends StatefulWidget {
  final Function? onSalvo;

  const NovaTransacaoModal({super.key, this.onSalvo});

  @override
  State<NovaTransacaoModal> createState() => _NovaTransacaoModalState();

  static Future<void> show({
    required BuildContext context,
    Function? onSalvo,
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
        child: NovaTransacaoModal(onSalvo: onSalvo),
      ),
    );
  }
}

class _NovaTransacaoModalState extends State<NovaTransacaoModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  final _descricaoController = TextEditingController();
  final _observacaoController = TextEditingController();

  String _tipoSelecionado = 'gasto';
  String _categoriaSelecionada = 'Outros';
  DateTime _dataSelecionada = DateTime.now();
  double _valor = 0.0;
  bool _carregando = false;

  // 🔥 REMOVIDO: final List<String> _tipos = ['receita', 'gasto']; (não usado)

  // Listas dinâmicas baseadas no tipo
  List<String> get _categoriasDisponiveis {
    return _tipoSelecionado == 'receita'
        ? AppCategories.receitas
        : AppCategories.gastos;
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _dataSelecionada) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _carregando = true);

      final novoLancamento = {
        'descricao': _descricaoController.text,
        'valor': _valor,
        'tipo': _tipoSelecionado,
        'categoria': _categoriaSelecionada,
        'data': _dataSelecionada.toIso8601String(),
        'observacao': _observacaoController.text,
      };

      try {
        await _dbHelper.insertLancamento(novoLancamento);

        if (mounted) {
          widget.onSalvo?.call();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${_tipoSelecionado == 'receita' ? 'Receita' : 'Gasto'} adicionado!',
              ),
              backgroundColor: _tipoSelecionado == 'receita'
                  ? AppColors.success
                  : AppColors.error,
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
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _carregando = false);
      }
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
                'Nova Transação',
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
                  Text(
                    'Tipo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.muted(context).withValues(alpha:0.1),
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
                            label: '💸 Gasto',
                            value: 'gasto',
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
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary(context)),
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
                        return 'Digite um valor';
                      }
                      final val = double.tryParse(value.replaceAll(',', '.'));
                      if (val == null || val <= 0) {
                        return 'Digite um valor válido';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _valor = double.parse(value!.replaceAll(',', '.'));
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
                      dropdownColor: AppColors.surface(context),
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
                              Text(
                                categoria,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _categoriaSelecionada = value!;
                        });
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
                    onTap: _selecionarData,
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
                            Formatador.data(_dataSelecionada),
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Detalhes adicionais...',
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
                                text: 'SALVAR',
                                icon: Icons.check,
                                onPressed: _salvar,
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
          color: isSelected ? color.withValues(alpha:0.1) : Colors.transparent,
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
}

