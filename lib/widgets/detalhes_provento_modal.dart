// lib/widgets/detalhes_provento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class DetalhesProventoModal extends StatefulWidget {
  final Map<String, dynamic> provento;

  const DetalhesProventoModal({
    super.key,
    required this.provento,
  });

  @override
  State<DetalhesProventoModal> createState() => _DetalhesProventoModalState();

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> provento,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DetalhesProventoModal(provento: provento),
      ),
    );
  }
}

class _DetalhesProventoModalState extends State<DetalhesProventoModal> {
  String _formatarValor(double valor) {
    return Formatador.moeda(valor);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provento;
    final ticker = p['ticker'] ?? '---';
    final valorPorCota = (p['valor_por_cota'] ?? 0).toDouble();
    final quantidade = (p['quantidade'] ?? 1).toDouble();
    final total = (p['total_recebido'] ?? 0).toDouble();
    final dataPagamento = DateTime.parse(p['data_pagamento']);
    final dataCom =
        p['data_com'] != null ? DateTime.parse(p['data_com']) : null;
    final tipo = p['tipo_provento'] ?? 'Dividendo';

    final hoje = DateTime.now();
    final isFuturo = dataPagamento.isAfter(hoje);
    final diasParaPagamento = dataPagamento.difference(hoje).inDays;

    Color statusColor = isFuturo
        ? diasParaPagamento <= 7
            ? Colors.orange
            : AppColors.primary
        : AppColors.success;

    String statusText = isFuturo
        ? diasParaPagamento == 0
            ? 'Hoje'
            : diasParaPagamento == 1
                ? 'Amanhã'
                : 'Em $diasParaPagamento dias'
        : 'Pago';

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
              Expanded(
                child: Text(
                  ticker,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 📝 CONTEÚDO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Card principal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    children: [
                      // Tipo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tipo,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Total
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Total Recebido',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatarValor(total),
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

                      // Detalhes
                      _buildDetalheItem(
                        context,
                        'Valor por cota',
                        _formatarValor(valorPorCota),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
