// lib/screens/editar_investimento.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/investimento_repository.dart'; // NOVO
import '../models/investimento_model.dart'; // NOVO

class EditarInvestimentoScreen extends StatefulWidget {
  final Map<String, dynamic> investimento;
  const EditarInvestimentoScreen({super.key, required this.investimento});

  @override
  State<EditarInvestimentoScreen> createState() =>
      _EditarInvestimentoScreenState();
}

class _EditarInvestimentoScreenState extends State<EditarInvestimentoScreen> {
  // 🔥 Usar o repositório
  final InvestimentoRepository _investimentoRepo = InvestimentoRepository();

  late TextEditingController _quantidadeController;
  late TextEditingController _precoMedioController;
  late DateTime _dataCompra;

  late String _tipoSelecionado;

  bool _salvando = false;

  final List<String> _tipos = ['ACAO', 'FII', 'ETF', 'BDR', 'CRIPTO'];

  @override
  void initState() {
    super.initState();
    final inv = widget.investimento;

    _quantidadeController = TextEditingController(
      text: inv['quantidade'].toString(),
    );
    _precoMedioController = TextEditingController(
      text: (inv['preco_medio'] as num).toStringAsFixed(2).replaceAll('.', ','),
    );
    _dataCompra =
        DateTime.parse(inv['data_compra'] ?? DateTime.now().toIso8601String());
    _tipoSelecionado = inv['tipo'] ?? 'ACAO';
  }

  String _formatarValor(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _selecionarData() async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: _dataCompra,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() {
        _dataCompra = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.investimento;
    final precoAtual = (inv['preco_atual'] ?? inv['preco_medio']).toDouble();

    double quantidade = 0;
    double precoMedio = 0;

    try {
      quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
    } catch (_) {}

    try {
      precoMedio =
          double.parse(_precoMedioController.text.replaceAll(',', '.'));
    } catch (_) {}

    final totalInvestido = quantidade * precoMedio;
    final valorAtual = quantidade * precoAtual;
    final variacao = totalInvestido > 0
        ? ((valorAtual - totalInvestido) / totalInvestido) * 100
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar ${inv['ticker']}'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card de preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: variacao >= 0
                          ? [Colors.green.shade700, Colors.green.shade500]
                          : [Colors.red.shade700, Colors.red.shade500],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PREVIEW - VALOR ATUAL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatarValor(valorAtual),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            variacao >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${variacao >= 0 ? '+' : ''}${variacao.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'vs investido',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Formulário
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
                        'Editar dados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _tipoSelecionado,
                        decoration: InputDecoration(
                          labelText: 'Tipo de ativo',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.category),
                        ),
                        items: _tipos.map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Text(tipo),
                          );
                        }).toList(),
                        onChanged: _salvando
                            ? null
                            : (value) {
                                setState(() {
                                  _tipoSelecionado = value!;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _quantidadeController,
                        enabled: !_salvando,
                        decoration: InputDecoration(
                          labelText: 'Quantidade de cotas',
                          hintText: 'Ex: 100',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _precoMedioController,
                        enabled: !_salvando,
                        decoration: InputDecoration(
                          labelText: 'Preço médio por cota',
                          hintText: '0,00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                          prefixText: 'R\$ ',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _salvando ? null : _selecionarData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                            color: _salvando ? Colors.grey[100] : Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: Color(0xFF6A1B9A)),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Data da compra',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy')
                                        .format(_dataCompra),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
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

                const SizedBox(height: 20),

                // Resumo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildResumoLinha(
                        'Quantidade',
                        '${quantidade.toStringAsFixed(0)} cotas',
                        Colors.grey[700]!,
                      ),
                      const SizedBox(height: 8),
                      _buildResumoLinha(
                        'Preço médio',
                        _formatarValor(precoMedio),
                        Colors.grey[700]!,
                      ),
                      const Divider(height: 16),
                      _buildResumoLinha(
                        'Total investido',
                        _formatarValor(totalInvestido),
                        Colors.grey[700]!,
                      ),
                      const SizedBox(height: 4),
                      _buildResumoLinha(
                        'Valor atual',
                        _formatarValor(valorAtual),
                        variacao >= 0 ? Colors.green[700]! : Colors.red[700]!,
                      ),
                      const SizedBox(height: 4),
                      _buildResumoLinha(
                        'Rentabilidade',
                        '${variacao >= 0 ? '+' : ''}${variacao.toStringAsFixed(2)}%',
                        variacao >= 0 ? Colors.green[700]! : Colors.red[700]!,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _salvando ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF6A1B9A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Color(0xFF6A1B9A)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _salvando ? null : _salvarEdicao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _salvando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Salvar alterações'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_salvando)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Salvando alterações...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumoLinha(String label, String valor, Color cor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
      ],
    );
  }

  Future<void> _salvarEdicao() async {
    if (_quantidadeController.text.isEmpty ||
        _precoMedioController.text.isEmpty) {
      _mostrarErro('Preencha todos os campos!');
      return;
    }

    setState(() => _salvando = true);

    try {
      final quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
      final precoMedio =
          double.parse(_precoMedioController.text.replaceAll(',', '.'));

      await _investimentoRepo.updateInvestimento({
        'id': widget.investimento['id'],
        'ticker': widget.investimento['ticker'],
        'tipo': _tipoSelecionado,
        'quantidade': quantidade,
        'preco_medio': precoMedio,
        'preco_atual': widget.investimento['preco_atual'] ?? precoMedio,
        'data_compra': _dataCompra.toIso8601String(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _mostrarErro('Erro ao salvar: $e');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _precoMedioController.dispose();
    super.dispose();
  }
}
