// lib/widgets/detalhes_investimento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';

class DetalhesInvestimentoModal extends StatefulWidget {
  final Investimento investimento;

  const DetalhesInvestimentoModal({
    super.key,
    required this.investimento,
  });

  @override
  State<DetalhesInvestimentoModal> createState() =>
      _DetalhesInvestimentoModalState();

  static Future<void> show({
    required BuildContext context,
    required Investimento investimento,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DetalhesInvestimentoModal(investimento: investimento),
      ),
    );
  }
}

class _DetalhesInvestimentoModalState extends State<DetalhesInvestimentoModal> {
  @override
  Widget build(BuildContext context) {
    final inv = widget.investimento;
    final variacao = inv.variacaoTotal;
    final percentual = inv.variacaoPercentual;
    final isPositive = variacao >= 0;

    return Column(
      children: [
        // 🔝 CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  inv.ticker,
                  style: TextStyle(
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
                  color: inv.tipo.cor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  inv.tipo.nome,
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
                // Card de valores
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    children: [
                      // Investido vs Atual
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Investido',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatador.moeda(inv.valorInvestido),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Atual',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatador.moeda(inv.valorAtual),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: AppColors.divider(context)),
                      const SizedBox(height: 20),

                      // Variação
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: isPositive ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Variação',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isPositive ? '+' : ''}${percentual.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPositive ? Colors.green : Colors.red,
                                  ),
                                ),
                                Text(
                                  '${isPositive ? '+' : ''}${Formatador.moeda(variacao)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isPositive ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Detalhes
                      _buildDetalheItem(
                        context,
                        'Quantidade',
                        inv.quantidade.toString(),
                        Icons.numbers,
                      ),
                      _buildDetalheItem(
                        context,
                        'Preço médio',
                        Formatador.moeda(inv.precoMedio),
                        Icons.attach_money,
                      ),
                      _buildDetalheItem(
                        context,
                        'Preço atual',
                        inv.precoAtual != null
                            ? Formatador.moeda(inv.precoAtual!)
                            : 'Não disponível',
                        Icons.trending_up,
                      ),
                      _buildDetalheItem(
                        context,
                        'Data da compra',
                        DateFormat('dd/MM/yyyy').format(inv.dataCompra),
                        Icons.calendar_today,
                      ),
                      if (inv.corretora != null)
                        _buildDetalheItem(
                          context,
                          'Corretora',
                          inv.corretora!,
                          Icons.business,
                        ),
                      if (inv.setor != null)
                        _buildDetalheItem(
                          context,
                          'Setor',
                          inv.setor!,
                          Icons.category,
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
