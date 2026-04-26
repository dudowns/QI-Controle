// lib/widgets/cotacao_card.dart
import 'package:flutter/material.dart';
import '../services/b3_service.dart';
import '../utils/formatters.dart';

class CotacaoCard extends StatelessWidget {
  final Map<String, dynamic> cotacao;
  final VoidCallback? onTap;

  const CotacaoCard({
    super.key,
    required this.cotacao,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preco = cotacao['preco'] as double;
    final variacao = cotacao['variacao_percentual'] as double;
    final isPositive = variacao >= 0;
    final cor = isPositive ? Colors.green : Colors.red;
    final icone = isPositive ? Icons.trending_up : Icons.trending_down;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cor.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logo do ticker
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    cotacao['ticker'].toString().substring(0, 4),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cotacao['ticker'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      cotacao['nome'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Preço e variação
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatador.moeda(preco),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icone, size: 12, color: cor),
                        const SizedBox(width: 2),
                        Text(
                          '${isPositive ? '+' : ''}${variacao.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: cor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
