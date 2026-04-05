// lib/widgets/nova_meta_modal.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';

class NovaMetaModal extends StatefulWidget {
  final Future<void> Function()? onSalvo;

  const NovaMetaModal({
    super.key,
    this.onSalvo,
  });

  @override
  State<NovaMetaModal> createState() => _NovaMetaModalState();

  static Future<void> show({
    required BuildContext context,
    Future<void> Function()? onSalvo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: NovaMetaModal(
          onSalvo: onSalvo,
        ),
      ),
    );
  }
}

class _NovaMetaModalState extends State<NovaMetaModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorObjetivoController = TextEditingController();
  final _dataFimController = TextEditingController();

  String _corSelecionada = 'viagem';
  String _iconeSelecionado = 'viagem';
  DateTime? _dataFim;
  bool _carregando = false;

  final List<Map<String, dynamic>> _opcoesTipo = [
    {
      'nome': 'Viagem',
      'cor': 'viagem',
      'icone': 'viagem',
      'color': Colors.blue
    },
    {'nome': 'Carro', 'cor': 'carro', 'icone': 'carro', 'color': Colors.red},
    {'nome': 'Casa', 'cor': 'casa', 'icone': 'casa', 'color': Colors.green},
    {
      'nome': 'Estudo',
      'cor': 'estudo',
      'icone': 'estudo',
      'color': Colors.orange
    },
    {
      'nome': 'Investimento',
      'cor': 'investimento',
      'icone': 'investimento',
      'color': Colors.purple
    },
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _valorObjetivoController.dispose();
    _dataFimController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (data != null) {
      setState(() {
        _dataFim = data;
        _dataFimController.text = Formatador.data(data);
      });
    }
  }

  double _parseValor(String texto) {
    try {
      return double.parse(
          texto.replaceAll(',', '.').replaceAll('R\$', '').trim());
    } catch (e) {
      return 0;
    }
  }

  Future<void> _salvarMeta() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma data limite'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final valorObjetivo = _parseValor(_valorObjetivoController.text);
    if (valorObjetivo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um valor válido para a meta'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      final meta = {
        'titulo': _tituloController.text,
        'descricao': _descricaoController.text,
        'valor_objetivo': valorObjetivo,
        'valor_atual': 0,
        'data_inicio': DateTime.now().toIso8601String(),
        'data_fim': _dataFim!.toIso8601String(),
        'cor': _corSelecionada,
        'icone': _iconeSelecionado,
        'concluida': 0,
      };

      await _dbHelper.insertMeta(meta);

      if (mounted) {
        if (widget.onSalvo != null) {
          await widget.onSalvo!();
        }
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎯 Meta criada com sucesso!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar meta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Nova Meta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // FORMULÁRIO
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipo da meta
                  Text(
                    'Tipo da meta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _opcoesTipo.length,
                      itemBuilder: (context, index) {
                        final opcao = _opcoesTipo[index];
                        final isSelected = _corSelecionada == opcao['cor'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _corSelecionada = opcao['cor'];
                              _iconeSelecionado = opcao['icone'];
                            });
                          },
                          child: Container(
                            width: 70,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (opcao['color'] as Color).withOpacity(0.2)
                                  : AppColors.muted(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? opcao['color'] as Color
                                    : AppColors.border(context),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getIconeParaTipo(opcao['icone']),
                                  color: isSelected
                                      ? opcao['color'] as Color
                                      : AppColors.textSecondary(context),
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  opcao['nome'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? opcao['color'] as Color
                                        : AppColors.textSecondary(context),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Título
                  Text(
                    'Título',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tituloController,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Ex: Viagem para a praia',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon:
                          const Icon(Icons.title, color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Digite um título';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Descrição
                  Text(
                    'Descrição (opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descricaoController,
                    maxLines: 2,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Ex: Guardar dinheiro para viajar em dezembro',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon: const Icon(Icons.description,
                          color: AppColors.primary),
                      filled: true,
                      fillColor: AppColors.surface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.border(context)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Valor objetivo
                  Text(
                    'Valor da meta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _valorObjetivoController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: '0,00',
                      hintStyle: TextStyle(color: AppColors.textHint(context)),
                      prefixIcon: const Icon(Icons.attach_money,
                          color: AppColors.primary),
                      prefixText: 'R\$ ',
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
                        return 'Digite o valor da meta';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Data limite
                  Text(
                    'Data limite',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selecionarData,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _dataFimController,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Selecione uma data',
                          hintStyle:
                              TextStyle(color: AppColors.textHint(context)),
                          prefixIcon: const Icon(Icons.calendar_today,
                              color: AppColors.primary),
                          suffixIcon: Icon(Icons.arrow_drop_down,
                              color: AppColors.textHint(context)),
                          filled: true,
                          fillColor: AppColors.surface(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.border(context)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

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
                                text: 'CRIAR META',
                                onPressed: _salvarMeta,
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

  IconData _getIconeParaTipo(String tipo) {
    switch (tipo) {
      case 'viagem':
        return Icons.flight;
      case 'carro':
        return Icons.directions_car;
      case 'casa':
        return Icons.home;
      case 'estudo':
        return Icons.school;
      case 'investimento':
        return Icons.trending_up;
      default:
        return Icons.flag;
    }
  }
}
