// lib/widgets/adicionar_lancamento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import 'gradient_button.dart';

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
  final _observacaoController = TextEditingController();

  String _tipoSelecionado = 'receita';
  String _categoriaSelecionada = 'Outros';
  DateTime _dataLancamento = DateTime.now();
  bool _carregando = false;

  final DBHelper _dbHelper = DBHelper();

  List<String> get _categoriasDisponiveis {
    return _tipoSelecionado == 'receita'
        ? AppCategories.receitas
        : AppCategories.gastos;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // CABEÇALHO
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
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // FORMULÁRIO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipoSelector(),
                  const SizedBox(height: 20),
                  _buildTextField(_descricaoController, 'Descrição',
                      hint: 'Ex: Salário, Mercado, etc'),
                  const SizedBox(height: 16),
                  _buildValorField(),
                  const SizedBox(height: 16),
                  _buildCategoriaSelector(),
                  const SizedBox(height: 16),
                  _buildDatePickerField(),
                  const SizedBox(height: 16),
                  _buildTextField(
                      _observacaoController, 'Observação (opcional)',
                      maxLines: 3),
                  const SizedBox(height: 24),
                  _buildButtons(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipoSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildTipoButton(
                  '💰 Receita', 'receita', Icons.arrow_upward, Colors.green)),
          Expanded(
              child: _buildTipoButton(
                  '📉 Despesa', 'gasto', Icons.arrow_downward, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildTipoButton(
      String label, String value, IconData icon, Color color) {
    final isSelected = _tipoSelecionado == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoSelecionado = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? color : AppColors.textSecondary(context),
                size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint ?? label,
        prefixIcon: const Icon(Icons.description, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surface(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Digite $label' : null,
    );
  }

  Widget _buildValorField() {
    return TextFormField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: 'R\$ 0,00',
        prefixIcon: const Icon(Icons.attach_money, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surface(context),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Digite o valor';
        if (double.tryParse(value.replaceAll(',', '.')) == null) {
          return 'Valor inválido';
        }
        return null;
      },
    );
  }

  Widget _buildCategoriaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categoria',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
            onChanged: (value) =>
                setState(() => _categoriaSelecionada = value!),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _dataLancamento,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) setState(() => _dataLancamento = date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(DateFormat('dd/MM/yyyy').format(_dataLancamento)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _carregando
              ? const Center(
                  child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator()))
              : GradientButton(
                  text: 'SALVAR',
                  icon: Icons.check,
                  onPressed: _salvarLancamento),
        ),
      ],
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
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }
}
