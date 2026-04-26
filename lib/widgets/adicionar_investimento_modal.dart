// lib/widgets/adicionar_investimento_modal.dart
import 'package:flutter/material.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class AdicionarInvestimentoModal {
  static Future<void> show({
    required BuildContext context,
    required Function(Investimento, String, DateTime) onSave,
    Investimento? investimento,
  }) async {
    final isEditing = investimento != null;
    final formKey = GlobalKey<FormState>();

    final tickerController =
        TextEditingController(text: investimento?.ticker ?? '');
    final quantidadeController = TextEditingController(
      text: investimento?.quantidade.toString() ?? '',
    );
    final precoMedioController = TextEditingController(
      text: investimento?.precoMedio.toString() ?? '',
    );

    final List<String> tipos = ['ACAO', 'FII', 'ETF', 'BDR', 'CRIPTO'];
    String? tipoSelecionado = investimento?.tipo ?? 'ACAO';

    // 🔥 Tipo de transação (COMPRA/VENDA)
    String tipoTransacao = 'COMPRA';

    // 🔥 Data da transação
    DateTime dataTransacao = DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(
                      isEditing ? 'Editar Investimento' : 'Novo Investimento',
                      context),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ticker
                            _buildTextField(tickerController, 'Ticker',
                                hint: 'Ex: PETR4, VISC11'),
                            const SizedBox(height: 16),

                            // Tipo do Investimento
                            _buildTipoSelector(
                                tipos,
                                tipoSelecionado,
                                (value) =>
                                    setState(() => tipoSelecionado = value)),
                            const SizedBox(height: 16),

                            // Tipo de Transação (COMPRA/VENDA) - APENAS PARA NOVO INVESTIMENTO
                            if (!isEditing) ...[
                              const Text(
                                'Tipo de Transação',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTipoTransacaoButton(
                                        label: '📈 COMPRA',
                                        value: 'COMPRA',
                                        selected: tipoTransacao == 'COMPRA',
                                        onTap: () => setState(
                                            () => tipoTransacao = 'COMPRA'),
                                        color: Colors.green,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildTipoTransacaoButton(
                                        label: '📉 VENDA',
                                        value: 'VENDA',
                                        selected: tipoTransacao == 'VENDA',
                                        onTap: () => setState(
                                            () => tipoTransacao = 'VENDA'),
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Quantidade
                            _buildTextField(quantidadeController, 'Quantidade',
                                isNumber: true),
                            const SizedBox(height: 16),

                            // Preço Médio
                            _buildTextField(precoMedioController, 'Preço Médio',
                                isNumber: true, prefix: 'R\$ '),

                            // Data da Transação (apenas para novo investimento)
                            if (!isEditing) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Data da Transação',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: dataTransacao,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                    locale: const Locale('pt', 'BR'),
                                  );
                                  if (date != null) {
                                    setState(() => dataTransacao = date);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 18,
                                              color: Colors.grey[500]),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Data',
                                            style: TextStyle(
                                                color: Color(0xFF666666)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            Formatador.data(dataTransacao),
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      Icon(Icons.arrow_drop_down,
                                          size: 20, color: Colors.grey[500]),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            _buildButtons(context, formKey, isEditing, () {
                              if (formKey.currentState!.validate()) {
                                final novoInvestimento = Investimento(
                                  id: investimento?.id,
                                  ticker: tickerController.text.toUpperCase(),
                                  tipo: tipoSelecionado!,
                                  quantidade: double.parse(quantidadeController
                                      .text
                                      .replaceAll(',', '.')),
                                  precoMedio: double.parse(precoMedioController
                                      .text
                                      .replaceAll(',', '.')),
                                  precoAtual: null, // 🔥 REMOVIDO
                                  corretora: null, // 🔥 REMOVIDO
                                );
                                Navigator.pop(context);
                                onSave(novoInvestimento, tipoTransacao,
                                    dataTransacao);
                              }
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _buildHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, size: 20, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  static Widget _buildTextField(TextEditingController controller, String label,
      {String? hint, bool isNumber = false, String prefix = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint ?? label,
            prefixText: prefix.isEmpty ? null : prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF7B2CBF), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Digite o $label';
            if (isNumber &&
                double.tryParse(value.replaceAll(',', '.')) == null) {
              return 'Valor inválido';
            }
            return null;
          },
        ),
      ],
    );
  }

  static Widget _buildTipoSelector(
      List<String> tipos, String? tipoSelecionado, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de Investimento',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: tipoSelecionado,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            items: tipos.map((tipo) {
              return DropdownMenuItem(
                value: tipo,
                child: Text(_getNomeAmigavel(tipo)),
              );
            }).toList(),
            onChanged: (value) => onChanged(value!),
          ),
        ),
      ],
    );
  }

  static Widget _buildTipoTransacaoButton({
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? color : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : Colors.grey[600],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  static Widget _buildButtons(BuildContext context,
      GlobalKey<FormState> formKey, bool isEditing, VoidCallback onSave) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(isEditing ? 'ATUALIZAR' : 'SALVAR',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  static String _getNomeAmigavel(String tipo) {
    switch (tipo) {
      case 'ACAO':
        return 'Ações';
      case 'FII':
        return 'Fundos Imobiliários (FIIs)';
      case 'ETF':
        return 'ETFs';
      case 'BDR':
        return 'BDRs';
      case 'CRIPTO':
        return 'Criptomoedas';
      default:
        return tipo;
    }
  }
}
