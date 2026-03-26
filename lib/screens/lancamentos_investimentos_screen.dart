// lib/screens/lancamentos_investimentos_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class LancamentosInvestimentosScreen extends StatefulWidget {
  final List<Investimento> investimentos;

  const LancamentosInvestimentosScreen({
    super.key,
    required this.investimentos,
  });

  @override
  State<LancamentosInvestimentosScreen> createState() =>
      _LancamentosInvestimentosScreenState();
}

class _LancamentosInvestimentosScreenState
    extends State<LancamentosInvestimentosScreen> {
  String _filtroSelecionado = 'Todos';
  final List<String> _filtros = ['Todos', 'Compras', 'Vendas'];

  // 🔥 SIMULAÇÃO DE TIPO DE OPERAÇÃO (substitua pela lógica real do seu app)
  bool _isOperacaoCompra(Investimento inv) {
    // Exemplo: se quantidade > 0 é compra, se < 0 é venda
    // Adapte conforme sua lógica real de banco de dados
    return inv.quantidade > 0; // Simplificado - ajuste conforme necessário
  }

  List<Investimento> get _investimentosFiltrados {
    if (_filtroSelecionado == 'Todos') {
      return widget.investimentos;
    } else if (_filtroSelecionado == 'Compras') {
      return widget.investimentos
          .where((inv) => _isOperacaoCompra(inv))
          .toList();
    } else {
      // Vendas
      return widget.investimentos
          .where((inv) => !_isOperacaoCompra(inv))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final investimentosFiltrados = _investimentosFiltrados;

    if (investimentosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum lançamento',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compre ou venda ativos para ver o histórico',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filtros
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Filtrar: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              ..._filtros.map((filtro) {
                final isSelected = _filtroSelecionado == filtro;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filtro),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _filtroSelecionado = filtro;
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.1),
                    checkmarkColor: AppColors.primary,
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        // Lista de lançamentos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: investimentosFiltrados.length,
            itemBuilder: (context, index) {
              final inv = investimentosFiltrados[index];
              final isCompra =
                  _isOperacaoCompra(inv); // ✅ AGORA USA LÓGICA REAL!

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    // Ícone
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCompra
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCompra ? Icons.trending_up : Icons.trending_down,
                        color: isCompra ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Informações
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.ticker,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${inv.quantidade.toStringAsFixed(0)} cotas x ${Formatador.moeda(inv.precoMedio)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd/MM/yyyy').format(inv.dataCompra),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Valor total
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatador.moeda(inv.valorInvestido),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCompra ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isCompra
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCompra ? 'COMPRA' : 'VENDA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCompra ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
