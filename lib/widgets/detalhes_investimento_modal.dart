// lib/widgets/detalhes_investimento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class DetalhesInvestimentoModal extends StatelessWidget {
  final Investimento investimento;

  const DetalhesInvestimentoModal({
    super.key,
    required this.investimento,
  });

  static Future<void> show({
    required BuildContext context,
    required Investimento investimento,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: DetalhesInvestimentoModal(investimento: investimento),
      ),
    );
  }

  String _formatarData(String? data) {
    if (data == null || data.isEmpty) return 'Não informada';
    try {
      final date = DateTime.parse(data);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return data;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = investimento;
    final variacao = inv.variacaoTotal;
    final percentual = inv.variacaoPercentual;
    final isPositive = variacao >= 0;

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPositive ? AppColors.success : AppColors.error,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        inv.ticker,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        TipoInvestimento.getNomeAmigavel(inv.tipo),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isPositive ? '+' : ''}${percentual.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${isPositive ? '+' : ''}${Formatador.moeda(variacao)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        'Valor Investido',
                        Formatador.moeda(inv.valorInvestido),
                        Icons.attach_money,
                        AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        context,
                        'Valor Atual',
                        Formatador.moeda(inv.valorAtual),
                        Icons.trending_up,
                        isPositive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetalheItem(
                  context,
                  'Quantidade',
                  '${inv.quantidade.toStringAsFixed(0)} cotas',
                  Icons.numbers,
                ),
                const SizedBox(height: 12),
                _buildDetalheItem(
                  context,
                  'Preço Médio',
                  Formatador.moeda(inv.precoMedio),
                  Icons.monetization_on,
                ),
                const SizedBox(height: 12),
                if (inv.precoAtual != null)
                  _buildDetalheItem(
                    context,
                    'Preço Atual',
                    Formatador.moeda(inv.precoAtual!),
                    Icons.trending_up,
                  ),
                const SizedBox(height: 12),
                if (inv.dataCompra != null && inv.dataCompra!.isNotEmpty)
                  _buildDetalheItem(
                    context,
                    'Data da Compra',
                    _formatarData(inv.dataCompra),
                    Icons.calendar_today,
                  ),
                const SizedBox(height: 12),
                if (inv.corretora != null && inv.corretora!.isNotEmpty)
                  _buildDetalheItem(
                    context,
                    'Corretora',
                    inv.corretora!,
                    Icons.business,
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('FECHAR'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String titulo,
    String valor,
    IconData icone,
    Color cor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cor,
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
    return Row(
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
    );
  }
}
