// lib/screens/editar_provento.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/provento_repository.dart';
import '../models/provento_model.dart';
import '../services/notification_service.dart';

class EditarProventoScreen extends StatefulWidget {
  final Map<String, dynamic> provento;

  const EditarProventoScreen({super.key, required this.provento});

  @override
  State<EditarProventoScreen> createState() => _EditarProventoScreenState();
}

class _EditarProventoScreenState extends State<EditarProventoScreen> {
  final ProventoRepository _proventoRepo = ProventoRepository();

  late TextEditingController _quantidadeController;
  late TextEditingController _valorCotaController;
  late TextEditingController _totalController;
  late DateTime _dataPagamento;
  late DateTime _dataCom;
  late DateTime _dataAntiga;
  late String _tipoProvento;
  late String _ticker;
  late int _id;

  bool _salvando = false;
  bool _excluindo = false;
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
    final p = widget.provento;
    _id = p['id'] ?? 0;
    _ticker = p['ticker'] ?? '';
    _dataAntiga = DateTime.parse(p['data_pagamento']);

    _quantidadeController = TextEditingController(
      text: (p['quantidade'] ?? 1).toString(),
    );
    _valorCotaController = TextEditingController(
      text: (p['valor_por_cota'] ?? 0).toStringAsFixed(2).replaceAll('.', ','),
    );
    _totalController = TextEditingController(
      text: (p['total_recebido'] ?? 0).toStringAsFixed(2).replaceAll('.', ','),
    );
    _dataPagamento = _dataAntiga;
    _dataCom =
        p['data_com'] != null ? DateTime.parse(p['data_com']) : _dataAntiga;
    _tipoProvento = p['tipo_provento'] ?? 'Dividendo';

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
    final bool processando = _salvando || _excluindo;

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Provento - $_ticker'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (!processando)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmarExclusao,
            ),
          if (_excluindo)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ticker (só leitura)
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Ativo',
                    hintText: _ticker,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag),
                  ),
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
                  onChanged: processando
                      ? null
                      : (value) {
                          setState(() {
                            _tipoProvento = value!;
                          });
                        },
                ),
                const SizedBox(height: 16),

                // Quantidade
                TextField(
                  controller: _quantidadeController,
                  enabled: !processando,
                  decoration: InputDecoration(
                    labelText: 'Quantidade de Cotas',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                    errorText: _erroValidacao,
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
                  enabled: !processando,
                  decoration: InputDecoration(
                    labelText: 'Valor por Cota',
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
                              processando,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildDataField(
                              'Data COM',
                              _dataCom,
                              (date) => setState(() => _dataCom = date),
                              processando,
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
                            processando ? null : () => Navigator.pop(context),
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
                        onPressed: processando ? null : _salvar,
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
          if (processando)
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
                        Text('Processando...'),
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
      Function(DateTime) onChanged, bool processando) {
    return InkWell(
      onTap: processando
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
          color: processando ? Colors.grey[100] : Colors.white,
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

  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Provento'),
        content: const Text('Deseja realmente excluir este provento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _excluir();
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

  Future<void> _excluir() async {
    setState(() => _excluindo = true);

    try {
      await NotificationService().cancelNotification(_id);
      await _proventoRepo.delete(_id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Provento excluído!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _excluindo = false);
      }
    }
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

      if (_dataPagamento != _dataAntiga) {
        try {
          await NotificationService().cancelNotification(_id);
        } catch (e) {
          debugPrint('⚠️ Erro ao cancelar notificação: $e');
        }

        if (_dataPagamento.isAfter(DateTime.now())) {
          try {
            await NotificationService().scheduleProventoNotification(
              ticker: _ticker,
              dataPagamento: _dataPagamento,
              valor: valorCota,
              id: _id,
            );
          } catch (e) {
            debugPrint('⚠️ Erro ao agendar notificação: $e');
          }
        }
      }

      await _proventoRepo.updateProvento({
        'id': _id,
        'ticker': _ticker,
        'tipo_provento': _tipoProvento,
        'valor_por_cota': valorCota,
        'quantidade': quantidade,
        'data_pagamento': _dataPagamento.toIso8601String(),
        'data_com': _dataCom.toIso8601String(),
        'total_recebido': total,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Provento atualizado!'),
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
    _quantidadeController.removeListener(_calcularTotal);
    _valorCotaController.removeListener(_calcularTotal);
    _quantidadeController.dispose();
    _valorCotaController.dispose();
    _totalController.dispose();
    super.dispose();
  }
}
