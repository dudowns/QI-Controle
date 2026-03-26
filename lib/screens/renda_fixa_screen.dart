// lib/screens/renda_fixa_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/renda_fixa_repository.dart';
import '../models/renda_fixa_model.dart';
import '../services/renda_fixa_diaria.dart';
import '../utils/currency_formatter.dart'; // ✅ OK!
import '../utils/date_helper.dart';
import 'novo_investimento_dialog.dart';
import 'detalhes_renda_fixa.dart';
import '../constants/app_colors.dart';

class RendaFixaScreen extends StatefulWidget {
  const RendaFixaScreen({super.key});

  @override
  State<RendaFixaScreen> createState() => _RendaFixaScreenState();
}

class _RendaFixaScreenState extends State<RendaFixaScreen> {
  final RendaFixaRepository _repository = RendaFixaRepository();

  List<RendaFixaModel> _investimentos = [];
  bool _carregando = true;
  String _mensagemStatus = '';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _mensagemStatus = 'Carregando investimentos...';
    });

    try {
      _investimentos = await _repository.getAll();
      _mensagemStatus = 'Carregados ${_investimentos.length} investimentos';
    } catch (e) {
      _mensagemStatus = 'Erro: $e';
      debugPrint('❌ Erro ao carregar renda fixa: $e');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarInvestimento(RendaFixaModel investimento) async {
    try {
      await _repository.insert(investimento);
      await _carregarDados();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Investimento adicionado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getCorTipo(String tipo) {
    switch (tipo) {
      case 'CDB':
        return Colors.blue;
      case 'LCI':
      case 'LCA':
        return Colors.green;
      case 'Tesouro Prefixado':
      case 'Tesouro Selic':
      case 'Tesouro IPCA+':
        return Colors.orange;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconeTipo(String tipo) {
    switch (tipo) {
      case 'CDB':
        return Icons.account_balance;
      case 'LCI':
      case 'LCA':
        return Icons.apartment;
      case 'Tesouro Prefixado':
      case 'Tesouro Selic':
      case 'Tesouro IPCA+':
        return Icons.attach_money;
      default:
        return Icons.savings;
    }
  }

  String _getTipoDescricao(RendaFixaModel inv) {
    return inv.tipoRenda;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renda Fixa'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      body: _carregando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_mensagemStatus),
                ],
              ),
            )
          : _investimentos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.savings_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum investimento em renda fixa',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toque no + para adicionar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _investimentos.length,
                  itemBuilder: (context, index) {
                    final inv = _investimentos[index];
                    final hoje = DateHelper.agoraBrasilia();
                    final valorHoje =
                        RendaFixaDiaria.calcularValorEm(inv, hoje);
                    final rendimento = valorHoje - inv.valorAplicado;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getCorTipo(inv.tipoRenda).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getIconeTipo(inv.tipoRenda),
                            color: _getCorTipo(inv.tipoRenda),
                          ),
                        ),
                        title: Text(
                          inv.nome,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getTipoDescricao(inv)} • ${DateFormat('dd/MM/yyyy').format(inv.dataVencimento)}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  rendimento >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 12,
                                  color: rendimento >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  CurrencyFormatter.format(rendimento), // ✅ OK!
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: rendimento >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: SizedBox(
                          width: 100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(valorHoje), // ✅ OK!
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'aplicado ${CurrencyFormatter.format(inv.valorAplicado)}', // ✅ OK!
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetalhesRendaFixaScreen(investimento: inv),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => NovoInvestimentoDialog(
              onSalvar: _salvarInvestimento,
            ),
          );
        },
      ),
    );
  }
}
