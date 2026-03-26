// lib/screens/detalhes_ativo.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/yahoo_finance_service.dart';
import '../database/db_helper.dart';
import '../repositories/investimento_repository.dart'; // NOVO
import 'editar_investimento.dart';
import 'grafico_ativo.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';
import '../widgets/primary_card.dart';
import '../widgets/info_row.dart';
import '../utils/formatters.dart';

class DetalhesAtivoScreen extends StatefulWidget {
  final Map<String, dynamic> ativo;
  const DetalhesAtivoScreen({super.key, required this.ativo});

  @override
  State<DetalhesAtivoScreen> createState() => _DetalhesAtivoScreenState();
}

class _DetalhesAtivoScreenState extends State<DetalhesAtivoScreen> {
  final YahooFinanceService _service = YahooFinanceService();
  final InvestimentoRepository _investimentoRepo =
      InvestimentoRepository(); // NOVO

  Map<String, dynamic>? dadosYahoo;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosYahoo();
  }

  Future<void> _carregarDadosYahoo() async {
    final dados = await _service.getDadosCompletos(widget.ativo['ticker']);

    if (dados != null) {
      dados['precoAtual'] = (dados['precoAtual'] as num?)?.toDouble() ?? 0.0;
      dados['variacaoDiaria'] =
          (dados['variacaoDiaria'] as num?)?.toDouble() ?? 0.0;
      dados['variacaoPercentual'] =
          (dados['variacaoPercentual'] as num?)?.toDouble() ?? 0.0;
      dados['precoAbertura'] =
          (dados['precoAbertura'] as num?)?.toDouble() ?? 0.0;
      dados['maximaDia'] = (dados['maximaDia'] as num?)?.toDouble() ?? 0.0;
      dados['minimaDia'] = (dados['minimaDia'] as num?)?.toDouble() ?? 0.0;
    }

    setState(() {
      dadosYahoo = dados;
      carregando = false;
    });
  }

  String _formatarValor(double? valor) {
    if (valor == null) return 'R\$ 0,00';
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
    ).format(valor);
  }

  String _formatarPercentual(double? valor) {
    if (valor == null) return '0,00%';
    return '${valor.toStringAsFixed(2).replaceAll('.', ',')}%';
  }

  @override
  Widget build(BuildContext context) {
    final ativo = widget.ativo;
    final precoAtual =
        (ativo['preco_atual'] ?? ativo['preco_medio']).toDouble();
    final precoMedio = ativo['preco_medio'].toDouble();
    final quantidade = ativo['quantidade'].toDouble();
    final totalInvestido = precoMedio * quantidade;
    final valorAtual = precoAtual * quantidade;
    final variacao =
        precoMedio > 0 ? ((precoAtual - precoMedio) / precoMedio) * 100 : 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF6A1B9A),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6A1B9A),
                      const Color(0xFF9C27B0).withOpacity(0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditarInvestimentoScreen(investimento: ativo),
                    ),
                  );
                  if (result == true) {
                    Navigator.pop(context, true);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.show_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GraficoAtivoScreen(ativo: ativo),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmarDelete,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6A1B9A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ativo['tipo'],
                        style: const TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.parse(
                          ativo['data_compra'] ??
                              DateTime.now().toIso8601String())),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatarValor(precoAtual),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: variacao >= 0
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            variacao >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 14,
                            color: variacao >= 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${variacao >= 0 ? '+' : ''}${variacao.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: variacao >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dadosYahoo?['nome'] ?? ativo['ticker'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildInfoCard(
                      'Preço médio',
                      _formatarValor(precoMedio),
                      Icons.calculate_outlined,
                      Colors.blue,
                    ),
                    _buildInfoCard(
                      'Quantidade',
                      quantidade.toStringAsFixed(0),
                      Icons.numbers,
                      Colors.orange,
                    ),
                    _buildInfoCard(
                      'Total investido',
                      _formatarValor(totalInvestido),
                      Icons.account_balance_wallet_outlined,
                      Colors.purple,
                    ),
                    _buildInfoCard(
                      'Valor atual',
                      _formatarValor(valorAtual),
                      Icons.trending_up,
                      variacao >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (dadosYahoo != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dados de Mercado',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'Abertura',
                          _formatarValor((dadosYahoo!['precoAbertura'] as num?)
                              ?.toDouble()),
                        ),
                        _buildInfoRow(
                          'Máxima',
                          _formatarValor(
                              (dadosYahoo!['maximaDia'] as num?)?.toDouble()),
                        ),
                        _buildInfoRow(
                          'Mínima',
                          _formatarValor(
                              (dadosYahoo!['minimaDia'] as num?)?.toDouble()),
                        ),
                        _buildInfoRow(
                          'Volume',
                          (dadosYahoo!['volume'] ?? 0).toString(),
                        ),
                        _buildInfoRow(
                          'Variação',
                          _formatarPercentual(
                              (dadosYahoo!['variacaoPercentual'] as num?)
                                  ?.toDouble()),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color cor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: cor, size: 16),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Ativo'),
        content: const Text('Tem certeza que deseja excluir este ativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _investimentoRepo.deleteInvestimento(
                  widget.ativo['id']); // 🔥 Usando repositório
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
