// lib/screens/adicionar_provento.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/provento_repository.dart';
import '../models/provento_model.dart';
import '../services/notification_service.dart';

class AdicionarProventoScreen extends StatefulWidget {
  final String? tickerInicial;

  const AdicionarProventoScreen({super.key, this.tickerInicial});

  @override
  State<AdicionarProventoScreen> createState() =>
      _AdicionarProventoScreenState();
}

class _AdicionarProventoScreenState extends State<AdicionarProventoScreen> {
  final ProventoRepository _proventoRepo = ProventoRepository();

  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _valorCotaController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  DateTime _dataPagamento = DateTime.now();
  DateTime _dataCom = DateTime.now();
  String _tipoProvento = 'Dividendo';

  bool _salvando = false;
  String? _erroValidacao;

  final List<String> _tiposProvento = [
    'Dividendo',
    'JCP',
    'Renda Fixa',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.tickerInicial != null) {
      _tickerController.text = widget.tickerInicial!;
    }

    _quantidadeController.addListener(_calcularTotal);
    _valorCotaController.addListener(_calcularTotal);
  }

  void _calcularTotal() {
    try {
      String qtdText = _quantidadeController.text.replaceAll(',', '.');
      String valorText = _valorCotaController.text.replaceAll(',', '.');

      if (qtdText.isEmpty || valorText.isEmpty) {
        _totalController.text = '0,00';
        return;
      }

      double quantidade = double.parse(qtdText);
      double valorCota = double.parse(valorText);
      double total = quantidade * valorCota;

      _totalController.text = total.toStringAsFixed(2).replaceAll('.', ',');
      setState(() {});
    } catch (e) {
      _totalController.text = '0,00';
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

    if (_valorCotaController.text.isEmpty) {
      setState(() => _erroValidacao = 'Digite o valor por cota');
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
      double valor =
          double.parse(_valorCotaController.text.replaceAll(',', '.'));
      if (valor <= 0) {
        setState(() => _erroValidacao = 'Valor deve ser maior que zero');
        return false;
      }
    } catch (e) {
      setState(() => _erroValidacao = 'Valor inválido');
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Provento'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ticker
                TextField(
                  controller: _tickerController,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    labelText: 'Ticker',
                    hintText: 'Ex: PETR4, MXRF11',
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
                const SizedBox(height: 16),

                // Tipo de Provento
                DropdownButtonFormField<String>(
                  value: _tipoProvento,
                  decoration: InputDecoration(
                    labelText: 'Tipo de Provento',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  items: _tiposProvento.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo),
                    );
                  }).toList(),
                  onChanged: _salvando
                      ? null
                      : (value) {
                          setState(() {
                            _tipoProvento = value!;
                          });
                        },
                ),
                const SizedBox(height: 16),

                // Quantidade de Cotas
                TextField(
                  controller: _quantidadeController,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    labelText: 'Quantidade de Cotas',
                    hintText: 'Ex: 100',
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
                const SizedBox(height: 16),

                // Valor por Cota
                TextField(
                  controller: _valorCotaController,
                  enabled: !_salvando,
                  decoration: InputDecoration(
                    labelText: 'Valor por Cota',
                    hintText: '0,00',
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
                const SizedBox(height: 16),

                // Datas
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datas do Provento',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDataField(
                              'Data Pagamento',
                              _dataPagamento,
                              (date) => setState(() => _dataPagamento = date),
                              _salvando,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDataField(
                              'Data COM',
                              _dataCom,
                              (date) => setState(() => _dataCom = date),
                              _salvando,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Card do Total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'R\$ ${_totalController.text.isEmpty ? '0,00' : _totalController.text}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

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
                          style: TextStyle(
                            color: Color(0xFF6A1B9A),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _salvando ? null : _salvar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
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
                            : const Text(
                                'Salvar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
                        Text('Adicionando provento...'),
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

  Widget _buildDataField(String label, DateTime date,
      Function(DateTime) onChanged, bool salvando) {
    return InkWell(
      onTap: salvando
          ? null
          : () async {
              final DateTime? newDate = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('pt', 'BR'),
              );
              if (newDate != null) {
                onChanged(newDate);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
          color: salvando ? Colors.grey[100] : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_validarCampos()) return;

    setState(() => _salvando = true);

    try {
      double quantidade =
          double.parse(_quantidadeController.text.replaceAll(',', '.'));
      double valorCota =
          double.parse(_valorCotaController.text.replaceAll(',', '.'));
      double total = quantidade * valorCota;

      final provento = {
        'ticker': _tickerController.text.toUpperCase(),
        'tipo_provento': _tipoProvento,
        'valor_por_cota': valorCota,
        'quantidade': quantidade,
        'data_pagamento': _dataPagamento.toIso8601String(),
        'data_com': _dataCom.toIso8601String(),
        'total_recebido': total,
      };

      final id = await _proventoRepo.insertProvento(provento);

      if (_dataPagamento.isAfter(DateTime.now())) {
        try {
          await NotificationService().scheduleProventoNotification(
            ticker: _tickerController.text.toUpperCase(),
            dataPagamento: _dataPagamento,
            valor: valorCota,
            id: id,
          );
        } catch (e) {
          debugPrint('⚠️ Erro ao agendar notificação: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Provento adicionado!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _erroValidacao = 'Erro ao salvar: $e';
      });
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
    _tickerController.removeListener(_calcularTotal);
    _quantidadeController.removeListener(_calcularTotal);
    _valorCotaController.removeListener(_calcularTotal);
    _tickerController.dispose();
    _quantidadeController.dispose();
    _valorCotaController.dispose();
    _totalController.dispose();
    super.dispose();
  }
}
