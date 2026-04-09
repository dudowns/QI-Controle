// lib/widgets/detalhes_investimento_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class DetalhesInvestimentoModal extends StatelessWidget {
  final Investimento investimento;

  const DetalhesInvestimentoModal({super.key, required this.investimento});

  static Future<void> show(
      {required BuildContext context, required Investimento investimento}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: DetalhesInvestimentoModal(investimento: investimento),
      ),
    );
  }

  String _formatarData(String? data) {
    if (data == null || data.isEmpty) return 'Não informada';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(data));
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
    final cor = isPositive ? Colors.green : Colors.red;

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
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: isPositive ? Colors.green : Colors.red,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(inv.ticker,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold))),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(TipoInvestimento.getNomeAmigavel(inv.tipo),
                        style: const TextStyle(color: Colors.white))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: _buildInfoCard(
                          context,
                          'Valor Investido',
                          Formatador.moeda(inv.valorInvestido),
                          Icons.attach_money,
                          Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildInfoCard(
                          context,
                          'Valor Atual',
                          Formatador.moeda(inv.valorAtual),
                          Icons.trending_up,
                          isPositive ? Colors.green : Colors.red)),
                ]),
                const SizedBox(height: 16),
                _buildDetalheItem(
                    context,
                    'Quantidade',
                    '${inv.quantidade.toStringAsFixed(0)} cotas',
                    Icons.numbers),
                _buildDetalheItem(context, 'Preço Médio',
                    Formatador.moeda(inv.precoMedio), Icons.monetization_on),
                if (inv.precoAtual != null)
                  _buildDetalheItem(context, 'Preço Atual',
                      Formatador.moeda(inv.precoAtual!), Icons.trending_up),
                if (inv.dataCompra != null && inv.dataCompra!.isNotEmpty)
                  _buildDetalheItem(context, 'Data da Compra',
                      _formatarData(inv.dataCompra), Icons.calendar_today),
                if (inv.corretora != null && inv.corretora!.isNotEmpty)
                  _buildDetalheItem(
                      context, 'Corretora', inv.corretora!, Icons.business),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: const Text('FECHAR'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B2CBF),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: const Text('OK'))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String titulo, String valor,
      IconData icone, Color cor) {
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cor.withValues(alpha: 0.3))),
        child: Column(children: [
          Icon(icone, color: cor),
          const SizedBox(height: 8),
          Text(titulo, style: const TextStyle(fontSize: 11)),
          Text(valor,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: cor))
        ]));
  }

  Widget _buildDetalheItem(
      BuildContext context, String label, String value, IconData icon) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: const Color(0xFF7B2CBF))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: const TextStyle(fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500))
              ]))
        ]));
  }
}
