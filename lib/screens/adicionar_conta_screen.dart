// lib/screens/adicionar_conta_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart'; // 🔥 NOVO!
import '../widgets/gradient_button.dart';

enum TipoConta {
  mensal,
  parcelada,
}

class AdicionarContaScreen extends StatefulWidget {
  final Map<String, dynamic>? contaExistente;

  const AdicionarContaScreen({super.key, this.contaExistente});

  @override
  State<AdicionarContaScreen> createState() => _AdicionarContaScreenState();
}

class _AdicionarContaScreenState extends State<AdicionarContaScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();

  TipoConta _tipoSelecionado = TipoConta.mensal;
  int _diaVencimento = DateTime.now().day;
  String? _categoriaSelecionada;
  bool _salvando = false;
  int? _parcelasTotal;
  DateTime _dataInicio = DateTime.now();

  bool _editando = false;

  // 🔥 Categorias de CONTAS (fixas)
  final List<String> _categorias = AppCategories.contas;

  @override
  void initState() {
    super.initState();
    if (widget.contaExistente != null) {
      _editando = true;
      _nomeController.text = widget.contaExistente!['nome'] ?? '';
      _valorController.text = widget.contaExistente!['valor'].toString();
      _diaVencimento =
          widget.contaExistente!['dia_vencimento'] ?? DateTime.now().day;
      _tipoSelecionado = widget.contaExistente!['tipo'] == 'mensal'
          ? TipoConta.mensal
          : TipoConta.parcelada;
      _categoriaSelecionada = widget.contaExistente!['categoria'];

      if (widget.contaExistente!['data_inicio'] != null) {
        _dataInicio = DateTime.parse(widget.contaExistente!['data_inicio']);
      }
      _parcelasTotal = widget.contaExistente!['parcelas_total'];
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  double _parseValor(String texto) {
    try {
      return double.parse(texto.replaceAll(',', '.'));
    } catch (e) {
      return 0;
    }
  }

  Future<void> _selecionarDataInicio() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _dataInicio = picked;
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final valor = _parseValor(_valorController.text);

      final conta = {
        'nome': _nomeController.text,
        'valor': valor,
        'dia_vencimento': _diaVencimento,
        'tipo': _tipoSelecionado == TipoConta.mensal ? 'mensal' : 'parcelada',
        'categoria': _categoriaSelecionada ?? 'Outros',
        'ativa': 1,
        'parcelas_total':
            _tipoSelecionado == TipoConta.parcelada ? _parcelasTotal : null,
        'parcelas_pagas': 0,
        'data_inicio': _dataInicio.toIso8601String(),
      };

      if (_editando) {
        await _dbHelper.update(
            DBHelper.tabelaContas, conta, widget.contaExistente!['id']);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${_nomeController.text} atualizada!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await _dbHelper.adicionarConta(conta);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${_nomeController.text} adicionada!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar Conta' : 'Nova Conta'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo de Conta',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTipoButton(
                      'Mensal',
                      Icons.repeat,
                      TipoConta.mensal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTipoButton(
                      'Parcelada',
                      Icons.calendar_month,
                      TipoConta.parcelada,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome da conta',
                  hintText: 'Ex: IPVA, Netflix, Empréstimo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.receipt),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite o nome da conta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valorController,
                decoration: InputDecoration(
                  labelText: 'Valor',
                  hintText: '0,00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                  prefixText: 'R\$ ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite o valor';
                  }
                  final valor = _parseValor(value);
                  if (valor <= 0) {
                    return 'Valor deve ser maior que zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarDataInicio,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data de início',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dataInicio),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down,
                          color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dia do vencimento',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _diaVencimento,
                              isExpanded: true,
                              items: List.generate(31, (index) {
                                final dia = index + 1;
                                return DropdownMenuItem(
                                  value: dia,
                                  child: Text('Dia $dia'),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _diaVencimento = value!;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categoria',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _categoriaSelecionada,
                              hint: const Text('Selecione'),
                              isExpanded: true,
                              items: _categorias.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: AppCategories.getColor(c),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(c),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _categoriaSelecionada = value;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_tipoSelecionado == TipoConta.parcelada) ...[
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _parcelasTotal?.toString() ?? '',
                  decoration: InputDecoration(
                    labelText: 'Total de parcelas',
                    hintText: 'Ex: 10',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _parcelasTotal = int.tryParse(value);
                  },
                  validator: (value) {
                    if (_tipoSelecionado == TipoConta.parcelada) {
                      if (value == null || value.isEmpty) {
                        return 'Digite o total de parcelas';
                      }
                      final parcelas = int.tryParse(value);
                      if (parcelas == null || parcelas <= 0) {
                        return 'Número inválido';
                      }
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 30),
              GradientButton(
                text: _editando ? 'ATUALIZAR CONTA' : 'ADICIONAR CONTA',
                icon: Icons.save,
                onPressed: _salvar,
                isLoading: _salvando,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoButton(String texto, IconData icone, TipoConta tipo) {
    final isSelecionado = _tipoSelecionado == tipo;
    final cor = isSelecionado ? AppColors.primary : Colors.grey;

    return InkWell(
      onTap: () {
        setState(() {
          _tipoSelecionado = tipo;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelecionado ? cor.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelecionado ? cor : Colors.grey[300]!,
            width: isSelecionado ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: cor, size: 18),
            const SizedBox(width: 8),
            Text(
              texto,
              style: TextStyle(
                color: cor,
                fontWeight: isSelecionado ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
