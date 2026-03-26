// lib/screens/nova_meta_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../repositories/meta_repository.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../utils/validators.dart';
import '../utils/formatters.dart';
import '../widgets/date_picker_field.dart';

class NovaMetaScreen extends StatefulWidget {
  const NovaMetaScreen({super.key});

  @override
  State<NovaMetaScreen> createState() => _NovaMetaScreenState();
}

class _NovaMetaScreenState extends State<NovaMetaScreen> {
  final MetaRepository _metaRepo = MetaRepository();

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorObjetivoController =
      TextEditingController();
  final TextEditingController _valorAtualController = TextEditingController();

  DateTime _dataFim = DateTime.now().add(const Duration(days: 365));
  String _iconeSelecionado = 'flag';
  String _corSelecionada = 'viagem';

  bool _salvando = false;

  final List<Map<String, dynamic>> _icones = const [
    {'valor': 'flag', 'icone': Icons.flag, 'label': 'Geral'},
    {'valor': 'viagem', 'icone': Icons.flight, 'label': 'Viagem'},
    {'valor': 'carro', 'icone': Icons.directions_car, 'label': 'Carro'},
    {'valor': 'casa', 'icone': Icons.home, 'label': 'Casa'},
    {'valor': 'estudo', 'icone': Icons.school, 'label': 'Estudo'},
    {
      'valor': 'investimento',
      'icone': Icons.trending_up,
      'label': 'Investimento'
    },
  ];

  final List<Map<String, dynamic>> _cores = const [
    {'valor': 'viagem', 'cor': Colors.blue, 'label': 'Viagem'},
    {'valor': 'carro', 'cor': Colors.red, 'label': 'Carro'},
    {'valor': 'casa', 'cor': Colors.green, 'label': 'Casa'},
    {'valor': 'estudo', 'cor': Colors.orange, 'label': 'Estudo'},
    {'valor': 'investimento', 'cor': Colors.purple, 'label': 'Investimento'},
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _valorObjetivoController.dispose();
    _valorAtualController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: _dataFim,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('pt', 'BR'),
    );
    if (data != null) {
      setState(() {
        _dataFim = data;
      });
    }
  }

  double _parseValor(String texto) {
    try {
      return double.parse(texto.replaceAll(',', '.'));
    } catch (e) {
      return 0;
    }
  }

  bool _validarCampos() {
    if (_tituloController.text.isEmpty) {
      _mostrarErro('Digite o título da meta');
      return false;
    }

    if (_valorObjetivoController.text.isEmpty) {
      _mostrarErro('Digite o valor da meta');
      return false;
    }

    final valor = _parseValor(_valorObjetivoController.text);
    if (valor <= 0) {
      _mostrarErro('O valor deve ser maior que zero');
      return false;
    }

    if (valor > 999999999) {
      _mostrarErro('Valor muito alto');
      return false;
    }

    return true;
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: AppColors.error, // 🔥 Usando AppColors!
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _salvarMeta() async {
    if (!_validarCampos()) return;

    setState(() => _salvando = true);

    try {
      final valorObjetivo = _parseValor(_valorObjetivoController.text);
      final valorAtual = _parseValor(_valorAtualController.text);

      final metaId = await _metaRepo.insertMeta({
        'titulo': _tituloController.text,
        'descricao': _descricaoController.text,
        'valor_objetivo': valorObjetivo,
        'valor_atual': valorAtual,
        'data_inicio': DateTime.now().toIso8601String(),
        'data_fim': _dataFim.toIso8601String(),
        'icone': _iconeSelecionado,
        'cor': _corSelecionada,
        'concluida': 0,
      });

      if (mounted) {
        if (valorAtual > 0) {
          await _metaRepo.insertDepositoMeta({
            'meta_id': metaId,
            'valor': valorAtual,
            'data_deposito': DateTime.now().toIso8601String(),
            'observacao': 'Depósito inicial',
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Meta "${_tituloController.text}" criada!'),
            backgroundColor: AppColors.success, // 🔥 Usando AppColors!
            behavior: SnackBarBehavior.floating,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Meta'),
        backgroundColor: AppColors.primary, // 🔥 Usando AppColors!
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                TextField(
                  controller: _tituloController,
                  decoration: InputDecoration(
                    labelText: 'Título da Meta',
                    hintText: 'Ex: Comprar um carro',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),

                // Descrição
                TextField(
                  controller: _descricaoController,
                  decoration: InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Ex: Quero comprar um carro até o final do ano',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Valor Objetivo
                TextField(
                  controller: _valorObjetivoController,
                  decoration: InputDecoration(
                    labelText: 'Valor da Meta',
                    hintText: '0,00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Valor Inicial (opcional)
                TextField(
                  controller: _valorAtualController,
                  decoration: InputDecoration(
                    labelText: 'Valor Inicial (opcional)',
                    hintText: '0,00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Data Fim
                InkWell(
                  onTap: _selecionarData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary), // 🔥 AppColors!
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data Limite',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_dataFim),
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
                const SizedBox(height: 16),

                // Ícone
                const Text(
                  'Ícone da Meta',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _icones.map((icone) {
                      bool isSelected = _iconeSelecionado == icone['valor'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _iconeSelecionado = icone['valor'];
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                    .withOpacity(0.1) // 🔥 AppColors!
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icone['icone'],
                                color: isSelected
                                    ? AppColors.primary // 🔥 AppColors!
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                icone['label'],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary // 🔥 AppColors!
                                      : Colors.grey[800],
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 20), // 🔥 AppColors!
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Cor
                const Text(
                  'Cor da Meta',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _cores.map((cor) {
                    bool isSelected = _corSelecionada == cor['valor'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _corSelecionada = cor['valor'];
                        });
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: cor['cor'],
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
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
                          side: BorderSide(
                              color: AppColors.primary), // 🔥 AppColors!
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                              color: AppColors.primary), // 🔥 AppColors!
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _salvando ? null : _salvarMeta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, // 🔥 AppColors!
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
                            : const Text('Criar Meta'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overlay de carregamento
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
                        Text('Criando meta...'),
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
