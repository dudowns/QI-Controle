// lib/widgets/app_modals.dart (VERSÃO COMPACTA)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';

class AppModals {
  // ========== MODAL DE LANÇAMENTO (COMPACTO) ==========
  static Future<Map<String, dynamic>?> mostrarModalLancamento({
    required BuildContext context,
    Map<String, dynamic>? lancamento,
  }) async {
    final isEditing = lancamento != null;

    final descricaoCtrl =
        TextEditingController(text: lancamento?['descricao'] ?? '');
    final valorCtrl = TextEditingController(
      text: lancamento != null
          ? (lancamento['valor'] as num).toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
    final observacaoCtrl =
        TextEditingController(text: lancamento?['observacao'] ?? '');

    String tipo = lancamento?['tipo'] ?? 'gasto';
    String categoria = lancamento?['categoria'] ?? 'Outros';
    DateTime data = lancamento != null
        ? DateTime.parse(lancamento['data'])
        : DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabeçalho compacto
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Editar' : 'Novo Lançamento',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(Icons.close,
                              size: 20, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                  // Corpo compacto
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tipo (Receita/Despesa) - compacto
                          Row(
                            children: [
                              Expanded(
                                child: _buildTipoCompacto(
                                  label: 'Receita',
                                  icon: Icons.trending_up,
                                  selected: tipo == 'receita',
                                  onTap: () => setState(() => tipo = 'receita'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildTipoCompacto(
                                  label: 'Despesa',
                                  icon: Icons.trending_down,
                                  selected: tipo == 'gasto',
                                  onTap: () => setState(() => tipo = 'gasto'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Descrição
                          TextField(
                            controller: descricaoCtrl,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Descrição',
                              hintStyle: TextStyle(
                                  color: Colors.grey[400], fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF7B2CBF), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Valor e Data (lado a lado)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: valorCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Valor',
                                    prefixText: 'R\$ ',
                                    hintStyle: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF7B2CBF), width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: data,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setState(() => data = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          Formatador.diaMes(data),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF333333)),
                                        ),
                                        Icon(Icons.calendar_today,
                                            size: 16, color: Colors.grey[500]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Categoria
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButton<String>(
                              value: categoria,
                              isExpanded: true,
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down,
                                  color: Colors.grey[500]),
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF333333)),
                              items: (tipo == 'receita'
                                      ? AppCategories.receitas
                                      : AppCategories.gastos)
                                  .map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: AppCategories.getColor(cat),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(cat),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => categoria = value!),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Observação (opcional)
                          TextField(
                            controller: observacaoCtrl,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Observação (opcional)',
                              hintStyle: TextStyle(
                                  color: Colors.grey[400], fontSize: 13),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF7B2CBF), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Botões compactos
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    side: BorderSide(color: Colors.grey[400]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Cancelar',
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (descricaoCtrl.text.isEmpty ||
                                        valorCtrl.text.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Preencha descrição e valor'),
                                          behavior: SnackBarBehavior.floating,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                      return;
                                    }
                                    final resultado = {
                                      'descricao': descricaoCtrl.text,
                                      'valor': double.parse(
                                          valorCtrl.text.replaceAll(',', '.')),
                                      'tipo': tipo,
                                      'categoria': categoria,
                                      'data': data.toIso8601String(),
                                      'observacao': observacaoCtrl.text,
                                    };
                                    if (isEditing &&
                                        lancamento?['id'] != null) {
                                      resultado['id'] = lancamento!['id'];
                                    }
                                    Navigator.pop(context, resultado);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B2CBF),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    isEditing ? 'Atualizar' : 'Salvar',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  // Botão tipo compacto
  static Widget _buildTipoCompacto({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7B2CBF).withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF7B2CBF) : Colors.grey[300]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? const Color(0xFF7B2CBF) : Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? const Color(0xFF7B2CBF) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
