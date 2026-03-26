// lib/screens/adicionar_investimento.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/investimento_repository.dart';
import '../models/investimento_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../widgets/gradient_button.dart';
import '../services/notification_service.dart';

class AdicionarInvestimentoScreen extends StatefulWidget {
  const AdicionarInvestimentoScreen({super.key});

  @override
  State<AdicionarInvestimentoScreen> createState() =>
      _AdicionarInvestimentoScreenState();
}

class _AdicionarInvestimentoScreenState
    extends State<AdicionarInvestimentoScreen> {
  final InvestimentoRepository _investimentoRepo = InvestimentoRepository();

  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _precoController = TextEditingController();

  String _tipoSelecionado = 'ACAO';
  DateTime _dataSelecionada = DateTime.now();

  bool _salvando = false;
  String? _erroValidacao;

  final List<String> _tipos = ['ACAO', 'FII', 'ETF', 'BDR', 'CRIPTO'];

  @override
  void dispose() {
    _tickerController.dispose();
    _quantidadeController.dispose();
    _precoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null && mounted) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  bool _validarCampos() {
    setState(() => _erroValidacao = null);

    if (_tickerController.text.isEmpty) {
      setState(() => _erroValidacao = 'Digite o ticker');
      return false;
    }

    if (_quantidadeController.text.isEmpty) {
      setState(() => _erroValidacao = 'Digite a quantidade');
      return false;
    }

    if (_precoController.text.isEmpty) {
      setState(() => _erroValidacao = 'Digite o preço');
      return false;
    }

    try {
      double quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
      if (quantidade <= 0) {
        setState(() => _erroValidacao = 'Quantidade deve ser maior que zero');
        return false;
      }
    } catch (e) {
      setState(() => _erroValidacao = 'Quantidade inválida');
      return false;
    }

    try {
      double preco = double.parse(_precoController.text.replaceAll(',', '.'));
      if (preco <= 0) {
        setState(() => _erroValidacao = 'Preço deve ser maior que zero');
        return false;
      }
    } catch (e) {
      setState(() => _erroValidacao = 'Preço inválido');
      return false;
    }

    return true;
  }

  Future<void> _salvar() async {
    if (!_validarCampos()) return;

    setState(() => _salvando = true);

    try {
      double quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
      double preco = double.parse(_precoController.text.replaceAll(',', '.'));

      final investimento = {
        'ticker': _tickerController.text.toUpperCase(),
        'tipo': _tipoSelecionado,
        'quantidade': quantidade,
        'preco_medio': preco,
        'preco_atual': preco,
        'data_compra': _dataSelecionada.toIso8601String(),
      };

      await _investimentoRepo.insertInvestimento(investimento);

      await NotificationService().addNotification(
        titulo: '📈 Novo Investimento',
        mensagem:
            '${_tickerController.text.toUpperCase()} - $quantidade cotas a R\$ ${preco.toStringAsFixed(2)}',
        ticker: _tickerController.text.toUpperCase(),
        valor: preco,
      );

      if (context.mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ ${_tickerController.text.toUpperCase()} adicionado!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _erroValidacao = 'Erro ao salvar: $e';
      });
      _mostrarErro('Erro: $e');
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
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Investimento'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Novo Investimento',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSizes.paddingL),
                TextField(
                  controller: _tickerController,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    labelText: 'Ticker',
                    hintText: 'Ex: PETR4, MXRF11, BTC',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                    errorText: _erroValidacao,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) {
                    if (_erroValidacao != null) {
                      setState(() => _erroValidacao = null);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.paddingL),
                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  decoration: InputDecoration(
                    labelText: 'Tipo de Ativo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _tipos.map((tipo) {
                    String emoji;
                    switch (tipo) {
                      case 'ACAO':
                        emoji = '📈';
                        break;
                      case 'FII':
                        emoji = '🏢';
                        break;
                      case 'ETF':
                        emoji = '📊';
                        break;
                      case 'BDR':
                        emoji = '🌎';
                        break;
                      case 'CRIPTO':
                        emoji = '🪙';
                        break;
                      default:
                        emoji = '';
                    }
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text('$emoji $tipo'),
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
                const SizedBox(height: AppSizes.paddingL),
                TextField(
                  controller: _quantidadeController,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    labelText: 'Quantidade de Cotas',
                    hintText: 'Ex: 10',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_erroValidacao != null) {
                      setState(() => _erroValidacao = null);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.paddingL),
                TextField(
                  controller: _precoController,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    labelText: 'Preço por Cota',
                    hintText: '5,00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) {
                    if (_erroValidacao != null) {
                      setState(() => _erroValidacao = null);
                    }
                  },
                ),
                const SizedBox(height: AppSizes.paddingL),
                InkWell(
                  onTap: _salvando ? null : _selecionarData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(12),
                      color: _salvando ? Colors.grey[100] : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data da Compra',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_dataSelecionada),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXL),
                GradientButton(
                  text: 'ADICIONAR INVESTIMENTO',
                  icon: Icons.add,
                  onPressed: _salvar,
                  isLoading: _salvando,
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
                        Text('Adicionando investimento...'),
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
}
