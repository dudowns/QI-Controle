// lib/screens/nova_transacao.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';

class NovaTransacaoScreen extends StatefulWidget {
  const NovaTransacaoScreen({super.key});

  @override
  State<NovaTransacaoScreen> createState() => _NovaTransacaoScreenState();
}

class _NovaTransacaoScreenState extends State<NovaTransacaoScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  final _descricaoController = TextEditingController();
  final _observacaoController = TextEditingController();

  String _tipoSelecionado = 'gasto';
  String _categoriaSelecionada = 'Outros';
  DateTime _dataSelecionada = DateTime.now();
  double _valor = 0.0;

  List<String> get _categoriasDisponiveis {
    return _tipoSelecionado == 'receita'
        ? AppCategories.receitas
        : AppCategories.gastos;
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _observacaoController.dispose();
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
    if (picked != null && picked != _dataSelecionada) {
      setState(() {
        _dataSelecionada = picked;
      });
    }
  }

  Future<void> _salvar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final novoLancamento = {
        'descricao': _descricaoController.text,
        'valor': _valor,
        'tipo': _tipoSelecionado,
        'categoria': _categoriaSelecionada,
        'data': _dataSelecionada.toIso8601String(),
        'observacao': _observacaoController.text,
      };

      try {
        await _dbHelper.insertLancamento(novoLancamento);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_tipoSelecionado == 'receita' ? 'Receita' : 'Gasto'} de ${Formatador.moeda(_valor)} adicionado!',
              ),
              backgroundColor: _tipoSelecionado == 'receita'
                  ? AppColors.success
                  : AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Transacao'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['receita', 'gasto'].map((tipo) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: tipo == 'receita' ? 8 : 0,
                        left: tipo == 'gasto' ? 8 : 0,
                      ),
                      child: FilterChip(
                        label: Text(
                          tipo == 'receita' ? 'Receita' : 'Gasto',
                          style: TextStyle(
                            color: _tipoSelecionado == tipo
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        selected: _tipoSelecionado == tipo,
                        selectedColor: tipo == 'receita'
                            ? AppColors.success
                            : AppColors.error,
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            _tipoSelecionado = tipo;
                            _categoriaSelecionada = 'Outros';
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descricao',
                  hintText: 'Ex: Salario, Mercado, etc',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite uma descricao';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor',
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite um valor';
                  }
                  final val = double.tryParse(value.replaceAll(',', '.'));
                  if (val == null || val <= 0) {
                    return 'Digite um valor valido';
                  }
                  return null;
                },
                onSaved: (value) {
                  _valor = double.parse(value!.replaceAll(',', '.'));
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _categoriaSelecionada, // âœ… CORRIGIDO
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categoriasDisponiveis.map((categoria) {
                  return DropdownMenuItem(
                    value: categoria,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppCategories.getColor(categoria),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(categoria),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoriaSelecionada = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Selecione uma categoria';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Formatador.data(_dataSelecionada)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacaoController,
                decoration: const InputDecoration(
                  labelText: 'Observacao (opcional)',
                  hintText: 'Detalhes adicionais...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'SALVAR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

