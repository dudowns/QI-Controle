// lib/widgets/editar_provento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/provento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class EditarProventoModal extends StatefulWidget {
  final Map<String, dynamic> provento;
  final Function? onAtualizado;

  const EditarProventoModal(
      {super.key, required this.provento, this.onAtualizado});

  @override
  State<EditarProventoModal> createState() => _EditarProventoModalState();

  static Future<void> show(
      {required BuildContext context,
      required Map<String, dynamic> provento,
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
        child:
            EditarProventoModal(provento: provento, onAtualizado: onAtualizado),
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
  late DateTime _dataPagamento;
  late DateTime? _dataCom;
  bool _isLoading = false;
  bool _temDataCom = false;

  @override
  void initState() {
    super.initState();
    _tickerController = TextEditingController(text: widget.provento['ticker']);
    _valorController = TextEditingController(
        text: (widget.provento['valor_por_cota'] ?? 0)
            .toStringAsFixed(2)
            .replaceAll('.', ','));
    _quantidadeController = TextEditingController(
        text: (widget.provento['quantidade'] ?? 1).toString());
    _dataPagamento = DateTime.parse(widget.provento['data_pagamento']);
    if (widget.provento['data_com'] != null) {
      _dataCom = DateTime.parse(widget.provento['data_com']);
      _temDataCom = true;
    }
  }

  Future<void> _atualizarProvento() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final valor = double.parse(_valorController.text.replaceAll(',', '.'));
      final quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
      await _dbHelper.updateProvento({
        'id': widget.provento['id'],
        'ticker': _tickerController.text.toUpperCase(),
        'valor_por_cota': valor,
        'quantidade': quantidade,
        'total_recebido': valor * quantidade,
        'data_pagamento': _dataPagamento.toIso8601String(),
        'data_com': _temDataCom ? _dataCom?.toIso8601String() : null
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
          _buildHeader('Editar Provento', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_tickerController, 'Ativo',
                        hint: 'Ex: PETR4'),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: _buildTextField(
                              _valorController, 'Valor por cota',
                              isNumber: true, prefix: 'R\$ ')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildTextField(
                              _quantidadeController, 'Quantidade',
                              isNumber: true))
                    ]),
                    const SizedBox(height: 16),
                    _buildDatePickerField('Data de pagamento', _dataPagamento,
                        (date) => setState(() => _dataPagamento = date)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Checkbox(
                          value: _temDataCom,
                          onChanged: (value) =>
                              setState(() => _temDataCom = value!),
                          activeColor: const Color(0xFF7B2CBF)),
                      const Text('Possui data COM')
                    ]),
                    if (_temDataCom) ...[
                      const SizedBox(height: 8),
                      _buildDatePickerField(
                          'Data COM',
                          _dataCom ?? DateTime.now(),
                          (date) => setState(() => _dataCom = date))
                    ],
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

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint, bool isNumber = false, String prefix = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
              hintText: hint ?? label,
              prefixText: prefix.isEmpty ? null : prefix,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          validator: (v) => v == null || v.isEmpty ? 'Digite $label' : null)
    ]);
  }

  Widget _buildDatePickerField(
      String label, DateTime date, Function(DateTime) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      InkWell(
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)));
            if (picked != null) onChanged(picked);
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd/MM/yyyy').format(date),
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
                  onPressed: _atualizarProvento,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('ATUALIZAR')))
    ]);
  }
}
