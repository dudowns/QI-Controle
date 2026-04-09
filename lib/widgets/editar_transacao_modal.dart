// lib/widgets/editar_transacao_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';

class EditarTransacaoModal extends StatefulWidget {
  final Map<String, dynamic> lancamento;
  final Function? onAtualizado;

  const EditarTransacaoModal(
      {super.key, required this.lancamento, this.onAtualizado});

  @override
  State<EditarTransacaoModal> createState() => _EditarTransacaoModalState();

  static Future<void> show(
      {required BuildContext context,
      required Map<String, dynamic> lancamento,
      Function? onAtualizado}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: EditarTransacaoModal(
            lancamento: lancamento, onAtualizado: onAtualizado),
      ),
    );
  }
}

class _EditarTransacaoModalState extends State<EditarTransacaoModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descricaoController;
  late TextEditingController _observacaoController;
  late String _tipoSelecionado;
  late String _categoriaSelecionada;
  late DateTime _dataSelecionada;
  late double _valor;
  bool _isLoading = false;

  List<String> get _categoriasDisponiveis => _tipoSelecionado == 'receita'
      ? AppCategories.receitas
      : AppCategories.gastos;

  @override
  void initState() {
    super.initState();
    _descricaoController =
        TextEditingController(text: widget.lancamento['descricao']);
    _observacaoController =
        TextEditingController(text: widget.lancamento['observacao'] ?? '');
    _tipoSelecionado = widget.lancamento['tipo'];
    _categoriaSelecionada = widget.lancamento['categoria'];
    _dataSelecionada = DateTime.parse(widget.lancamento['data']);
    _valor = (widget.lancamento['valor'] ?? 0).toDouble();
  }

  Future<void> _atualizar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _dbHelper.updateLancamento({
        'id': widget.lancamento['id'],
        'descricao': _descricaoController.text,
        'valor': _valor,
        'tipo': _tipoSelecionado,
        'categoria': _categoriaSelecionada,
        'data': _dataSelecionada.toIso8601String(),
        'observacao': _observacaoController.text
      });
      widget.onAtualizado?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('Editar Transação', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
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
      ),
    );
  }

  Widget _buildHeader(String title, BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 20, color: Colors.grey[500]))
        ]));
  }

  Widget _buildTipoSelector() {
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30)),
        child: Row(children: [
          Expanded(
              child: _buildTipoButton(
                  '💰 Receita', 'receita', Icons.arrow_upward, Colors.green)),
          Expanded(
              child: _buildTipoButton(
                  '💸 Gasto', 'gasto', Icons.arrow_downward, Colors.red))
        ]));
  }

  Widget _buildTipoButton(
      String label, String value, IconData icon, Color color) {
    final isSelected = _tipoSelecionado == value;
    return GestureDetector(
        onTap: () => setState(() => _tipoSelecionado = value),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: isSelected ? color : Colors.transparent)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: isSelected ? color : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.grey[600],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal))
            ])));
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
              hintText: hint ?? label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          validator: (v) => v == null || v.isEmpty ? 'Digite $label' : null)
    ]);
  }

  Widget _buildValorField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Valor',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
          initialValue: _valor.toStringAsFixed(2).replaceAll('.', ','),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              hintText: '0,00',
              prefixText: 'R\$ ',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Digite o valor';
            final val = double.tryParse(v.replaceAll(',', '.'));
            if (val == null || val <= 0) return 'Valor inválido';
            return null;
          },
          onSaved: (v) => _valor = double.parse(v!.replaceAll(',', '.')))
    ]);
  }

  Widget _buildCategoriaSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Categoria',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10)),
          child: DropdownButton<String>(
              value: _categoriaSelecionada,
              isExpanded: true,
              underline: const SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
              items: _categoriasDisponiveis
                  .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: AppCategories.getColor(cat),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(cat)
                      ])))
                  .toList(),
              onChanged: (v) => setState(() => _categoriaSelecionada = v!)))
    ]);
  }

  Widget _buildDatePickerField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Data',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      InkWell(
          onTap: () async {
            final date = await showDatePicker(
                context: context,
                initialDate: _dataSelecionada,
                firstDate: DateTime(2020),
                lastDate: DateTime.now());
            if (date != null) setState(() => _dataSelecionada = date);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(Formatador.data(_dataSelecionada),
                        style: const TextStyle(fontSize: 14)),
                    Icon(Icons.calendar_today,
                        size: 18, color: Colors.grey[500])
                  ])))
    ]);
  }

  Widget _buildButtons(BuildContext context) {
    return Row(children: [
      Expanded(
          child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Cancelar'))),
      const SizedBox(width: 12),
      Expanded(
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator()))
              : ElevatedButton(
                  onPressed: _atualizar,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('ATUALIZAR')))
    ]);
  }
}
