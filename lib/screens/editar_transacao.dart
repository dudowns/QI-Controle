// lib/screens/editar_transacao.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../utils/formatters.dart';

class EditarTransacaoScreen extends StatefulWidget {
  final Map<String, dynamic> lancamento;

  const EditarTransacaoScreen({super.key, required this.lancamento});

  @override
  State<EditarTransacaoScreen> createState() => _EditarTransacaoScreenState();
}

class _EditarTransacaoScreenState extends State<EditarTransacaoScreen> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descricaoController;
  late TextEditingController _observacaoController;

  late String _tipoSelecionado;
  late String _categoriaSelecionada;
  late DateTime _dataSelecionada;
  late double _valor;

  final List<String> _tipos = ['receita', 'gasto'];

  // Listas dinâmicas baseadas no tipo
  List<String> get _categoriasDisponiveis {
    return _tipoSelecionado == 'receita'
        ? AppCategories.receitas
        : AppCategories.gastos;
  }

  @override
  void initState() {
    super.initState();
    _descricaoController =
        TextEditingController(text: widget.lancamento['descricao']);
    _observacaoController =
        TextEditingController(text: widget.lancamento['observacao'] ?? '');
    _tipoSelecionado = widget.lancamento['tipo'];
    _categoriaSelecionada = widget.lancamento['categoria'];
    _dataSelecionada = DateTime.parse(widget.lancamento['data']);
    _valor = (widget.lancamento['valor'] ?? 0).toDouble();
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

  Future<void> _atualizar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final lancamentoAtualizado = {
        'id': widget.lancamento['id'],
        'descricao': _descricaoController.text,
        'valor': _valor,
        'tipo': _tipoSelecionado,
        'categoria': _categoriaSelecionada,
        'data': _dataSelecionada.toIso8601String(),
        'observacao': _observacaoController.text,
      };

      try {
        await _dbHelper.updateLancamento(lancamentoAtualizado);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${_tipoSelecionado == 'receita' ? 'Receita' : 'Gasto'} atualizado!',
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
              content: Text('Erro ao atualizar: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context), // ✅ DINÂMICO!
        title: Text(
          'Excluir Lançamento',
          style:
              TextStyle(color: AppColors.textPrimary(context)), // ✅ DINÂMICO!
        ),
        content: Text(
          'Deseja realmente excluir este lançamento?',
          style:
              TextStyle(color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                  color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _dbHelper.deleteLancamento(widget.lancamento['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Lançamento excluído!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
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
      backgroundColor: AppColors.background(context), // ✅ DINÂMICO!
      appBar: AppBar(
        title: const Text('Editar Transação'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _excluir,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tipo
              Text(
                'Tipo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context), // ✅ DINÂMICO!
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _tipos.map((tipo) {
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: tipo == 'receita' ? 8 : 0,
                        left: tipo == 'gasto' ? 8 : 0,
                      ),
                      child: FilterChip(
                        label: Text(
                          tipo == 'receita' ? '💰 Receita' : '💸 Gasto',
                          style: TextStyle(
                            color: _tipoSelecionado == tipo
                                ? Colors.white
                                : AppColors.textPrimary(context), // ✅ DINÂMICO!
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

              // Descrição
              TextFormField(
                controller: _descricaoController,
                style: TextStyle(
                    color: AppColors.textPrimary(context)), // ✅ DINÂMICO!
                decoration: InputDecoration(
                  labelText: 'Descrição',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.description, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface(context), // ✅ DINÂMICO!
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite uma descrição';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Valor
              TextFormField(
                initialValue: _valor.toStringAsFixed(2).replaceAll('.', ','),
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: AppColors.textPrimary(context)), // ✅ DINÂMICO!
                decoration: InputDecoration(
                  labelText: 'Valor',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  prefixIcon:
                      Icon(Icons.attach_money, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface(context), // ✅ DINÂMICO!
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Digite um valor';
                  }
                  final val = double.tryParse(value.replaceAll(',', '.'));
                  if (val == null || val <= 0) {
                    return 'Digite um valor válido';
                  }
                  return null;
                },
                onSaved: (value) {
                  _valor = double.parse(value!.replaceAll(',', '.'));
                },
              ),

              const SizedBox(height: 16),

              // Categoria - DINÂMICA por tipo!
              DropdownButtonFormField<String>(
                value: _categoriaSelecionada,
                dropdownColor: AppColors.surface(context), // ✅ DINÂMICO!
                style: TextStyle(
                    color: AppColors.textPrimary(context)), // ✅ DINÂMICO!
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.category, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface(context), // ✅ DINÂMICO!
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
                        Text(
                          categoria,
                          style: TextStyle(
                              color: AppColors.textPrimary(
                                  context)), // ✅ DINÂMICO!
                        ),
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

              // Data
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Data',
                    labelStyle: TextStyle(
                        color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
                    border: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(context)), // ✅ DINÂMICO!
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AppColors.border(context)), // ✅ DINÂMICO!
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon:
                        Icon(Icons.calendar_today, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surface(context), // ✅ DINÂMICO!
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatador.data(_dataSelecionada),
                        style: TextStyle(
                            color:
                                AppColors.textPrimary(context)), // ✅ DINÂMICO!
                      ),
                      Icon(Icons.arrow_drop_down,
                          color:
                              AppColors.textSecondary(context)), // ✅ DINÂMICO!
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Observação
              TextFormField(
                controller: _observacaoController,
                style: TextStyle(
                    color: AppColors.textPrimary(context)), // ✅ DINÂMICO!
                decoration: InputDecoration(
                  labelText: 'Observação (opcional)',
                  labelStyle: TextStyle(
                      color: AppColors.textSecondary(context)), // ✅ DINÂMICO!
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(context)), // ✅ DINÂMICO!
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.note, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface(context), // ✅ DINÂMICO!
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            AppColors.textSecondary(context), // ✅ DINÂMICO!
                        side: BorderSide(
                            color: AppColors.border(context)), // ✅ DINÂMICO!
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _atualizar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('ATUALIZAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
