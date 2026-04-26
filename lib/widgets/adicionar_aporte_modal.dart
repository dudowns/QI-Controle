// lib/widgets/adicionar_aporte_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class AdicionarAporteModal extends StatefulWidget {
  final String investimentoNome;
  final double valorAtual;
  final Function(double, DateTime) onConfirm;

  const AdicionarAporteModal({
    super.key,
    required this.investimentoNome,
    required this.valorAtual,
    required this.onConfirm,
  });

  @override
  State<AdicionarAporteModal> createState() => _AdicionarAporteModalState();

  static Future<void> show({
    required BuildContext context,
    required String investimentoNome,
    required double valorAtual,
    required Function(double, DateTime) onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: AdicionarAporteModal(
          investimentoNome: investimentoNome,
          valorAtual: valorAtual,
          onConfirm: onConfirm,
        ),
      ),
    );
  }
}

class _AdicionarAporteModalState extends State<AdicionarAporteModal> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  DateTime _dataAplicacao = DateTime.now();
  bool _isLoading = false;

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataAplicacao,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dataAplicacao = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 450, maxHeight: 480),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildHeader('Adicionar Aporte', context),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.2))),
                          child: Column(children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Investimento:'),
                                  Text(widget.investimentoNome,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ]),
                            const SizedBox(height: 8),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Valor atual:'),
                                  Text(Formatador.moeda(widget.valorAtual),
                                      style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold)), // ✅ CORRIGIDO
                                ]),
                          ])),
                      const SizedBox(height: 20),
                      const Text('Valor do aporte',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _valorController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            hintText: '0,00',
                            prefixText: 'R\$ ',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10))),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Digite o valor';
                          final valor = double.tryParse(v.replaceAll(',', '.'));
                          if (valor == null || valor <= 0)
                            return 'Valor invalido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Data do aporte',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selecionarData,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(_dataAplicacao),
                                      style: const TextStyle(fontSize: 14)),
                                  Icon(Icons.calendar_today,
                                      size: 18, color: Colors.grey[500]),
                                ])),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    side: BorderSide(color: Colors.grey[400]!)),
                                child: const Text('Cancelar'))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : ElevatedButton(
                                    onPressed: _confirmar,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12)),
                                    child: const Text('ADICIONAR'))),
                      ]),
                    ])),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A))),
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, size: 20, color: Colors.grey[500])),
      ]),
    );
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    final valor = double.parse(_valorController.text.replaceAll(',', '.'));
    setState(() => _isLoading = true);
    await widget.onConfirm(valor, _dataAplicacao);
    if (mounted) Navigator.pop(context);
  }
}
