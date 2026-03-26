// lib/widgets/adicionar_conta_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import '../widgets/gradient_button.dart';

class AdicionarContaModal extends StatefulWidget {
  final Function? onSalvo;

  const AdicionarContaModal({super.key, this.onSalvo});

  @override
  State<AdicionarContaModal> createState() => _AdicionarContaModalState();

  static Future<void> show({
    required BuildContext context,
    Function? onSalvo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AdicionarContaModal(onSalvo: onSalvo),
      ),
    );
  }
}

class _AdicionarContaModalState extends State<AdicionarContaModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _parcelasController = TextEditingController();

  String _tipoSelecionado = 'mensal';
  String _categoriaSelecionada = 'Outros';
  int _diaVencimento = 5;
  DateTime _dataInicio = DateTime.now();
  bool _carregando = false;

  final List<int> _dias = List.generate(31, (i) => i + 1);

  // 🔥 CATEGORIAS PARA CONTAS DO MÊS - USA O PADRÃO DO AppCategories!
  List<String> get _categoriasDisponiveis {
    return AppCategories.contas; // ✅ CORRETO!
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _dataInicio = picked);
    }
  }

  // VERIFICAR DUPLICATA
  Future<bool> _verificarDuplicata(String nome, String tipo) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'contas',
        where: 'nome = ? AND tipo = ?',
        whereArgs: [nome, tipo],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Erro ao verificar duplicata: $e');
      return false;
    }
  }

  Future<void> _salvarConta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      // Verificar duplicata
      final existe =
          await _verificarDuplicata(_nomeController.text, _tipoSelecionado);

      if (existe) {
        _mostrarErro(
            'Já existe uma conta com o nome "${_nomeController.text}" e tipo "$_tipoSelecionado"!\n\nUse um nome diferente.');
        setState(() => _carregando = false);
        return;
      }

      final Map<String, dynamic> conta = {
        'nome': _nomeController.text,
        'valor': double.parse(_valorController.text.replaceAll(',', '.')),
        'dia_vencimento': _diaVencimento,
        'tipo': _tipoSelecionado,
        'categoria': _categoriaSelecionada,
        'data_inicio': _dataInicio.toIso8601String(),
        'ativa': 1,
      };

      if (_tipoSelecionado == 'parcelada') {
        final parcelas = int.parse(_parcelasController.text);
        conta['parcelas_total'] = parcelas;
        conta['parcelas_pagas'] = 0;
      }

      await _dbHelper.adicionarConta(conta);

      if (mounted) {
        widget.onSalvo?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Conta "${_nomeController.text}" adicionada!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _mostrarErro('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🔝 CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Adicionar Conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // 📝 FORMULÁRIO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome
                  Text(
                    'Nome da Conta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nomeController,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Ex: Netflix, Aluguel, etc',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon: Icon(Icons.receipt, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite o nome da conta';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tipo
                  Text(
                    'Tipo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: DropdownButton<String>(
                      value: _tipoSelecionado,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      items: const [
                        DropdownMenuItem(
                          value: 'mensal',
                          child: Row(
                            children: [
                              Icon(Icons.repeat, size: 18),
                              SizedBox(width: 8),
                              Text('Mensal (todo mês)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'parcelada',
                          child: Row(
                            children: [
                              Icon(Icons.format_list_numbered, size: 18),
                              SizedBox(width: 8),
                              Text('Parcelada'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'fixa',
                          child: Row(
                            children: [
                              Icon(Icons.lock, size: 18),
                              SizedBox(width: 8),
                              Text('Fixa (uma vez)'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _tipoSelecionado = value!;
                          if (_tipoSelecionado != 'parcelada') {
                            _parcelasController.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Valor e Dia (lado a lado)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Valor',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _valorController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                  color: AppColors.textPrimary(context)),
                              decoration: InputDecoration(
                                hintText: '0,00',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint(context)),
                                prefixIcon: Icon(Icons.attach_money,
                                    color: AppColors.primary),
                                prefixText: 'R\$ ',
                                filled: true,
                                fillColor: AppColors.surface(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: AppColors.border(context)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Digite o valor';
                                }
                                if (double.tryParse(
                                        value.replaceAll(',', '.')) ==
                                    null) {
                                  return 'Valor inválido';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dia',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.border(context)),
                              ),
                              child: DropdownButton<int>(
                                value: _diaVencimento,
                                isExpanded: true,
                                underline: const SizedBox(),
                                style: TextStyle(
                                    color: AppColors.textPrimary(context)),
                                items: _dias.map((dia) {
                                  return DropdownMenuItem(
                                    value: dia,
                                    child: Text(dia.toString()),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => _diaVencimento = value!);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🟢 CATEGORIA - USANDO O PADRÃO CORRETO!
                  Text(
                    'Categoria',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: DropdownButton<String>(
                      value: _categoriaSelecionada,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: TextStyle(color: AppColors.textPrimary(context)),
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
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _categoriaSelecionada = value!);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data de início
                  Text(
                    'Data de início',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selecionarData,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_dataInicio),
                            style: TextStyle(
                                color: AppColors.textPrimary(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Se for parcelada, mostrar campo de total de parcelas
                  if (_tipoSelecionado == 'parcelada') ...[
                    Text(
                      'Total de parcelas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _parcelasController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Ex: 12',
                        hintStyle:
                            TextStyle(color: AppColors.textHint(context)),
                        prefixIcon: Icon(Icons.format_list_numbered,
                            color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surface(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.border(context)),
                        ),
                      ),
                      validator: (value) {
                        if (_tipoSelecionado == 'parcelada') {
                          if (value == null || value.isEmpty) {
                            return 'Digite o número de parcelas';
                          }
                          final parcelas = int.tryParse(value);
                          if (parcelas == null || parcelas <= 1) {
                            return 'Número de parcelas inválido (mínimo 2)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),

                  // Botões
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                                color: AppColors.textSecondary(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _carregando
                            ? const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : GradientButton(
                                text: 'SALVAR',
                                onPressed: _salvarConta,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
