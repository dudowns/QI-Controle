// lib/widgets/detalhes_provento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class DetalhesProventoModal extends StatelessWidget {
  final Map<String, dynamic> provento;

  const DetalhesProventoModal({super.key, required this.provento});

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> provento,
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
        child: DetalhesProventoModal(provento: provento),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = provento; // 🔥 USAR 'provento' diretamente, não 'widget.provento'
    final ticker = p['ticker'] ?? '---';
    final valorPorCota = (p['valor_por_cota'] ?? 0).toDouble();
    final quantidade = (p['quantidade'] ?? 1).toDouble();
    final total = (p['total_recebido'] ?? 0).toDouble();
    final dataPagamento = DateTime.parse(p['data_pagamento']);
    final dataCom =
        p['data_com'] != null ? DateTime.parse(p['data_com']) : null;

    final hoje = DateTime.now();
    final isFuturo = dataPagamento.isAfter(hoje);
    final diasParaPagamento = dataPagamento.difference(hoje).inDays;

    Color statusColor;
    String statusText;

    if (isFuturo) {
      if (diasParaPagamento <= 7) {
        statusColor = Colors.orange;
        statusText = '⚠️ Próximo';
      } else {
        statusColor = const Color(0xFF7B2CBF);
        statusText = '⏳ Futuro';
      }
    } else {
      statusColor = Colors.green;
      statusText = '✅ Recebido';
    }

    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 400),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ticker,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Recebido',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF666666)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Formatador.moeda(total),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildDetalheItem(
                  context,
                  'Valor por cota',
                  Formatador.moeda(valorPorCota),
                  Icons.attach_money,
                ),
                _buildDetalheItem(
                  context,
                  'Quantidade',
                  quantidade.toStringAsFixed(0),
                  Icons.numbers,
                ),
                _buildDetalheItem(
                  context,
                  'Data de pagamento',
                  DateFormat('dd/MM/yyyy').format(dataPagamento),
                  Icons.calendar_today,
                ),
                if (dataCom != null)
                  _buildDetalheItem(
                    context,
                    'Data COM',
                    DateFormat('dd/MM/yyyy').format(dataCom),
                    Icons.event,
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[400]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('FECHAR',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CBF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('OK',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalheItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7B2CBF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF7B2CBF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
