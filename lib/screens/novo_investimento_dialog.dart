// lib/screens/novo_investimento_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/renda_fixa_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../utils/formatters.dart';
import '../widgets/gradient_button.dart';

class NovoInvestimentoDialog extends StatefulWidget {
  final Function(RendaFixaModel)? onSalvar;

  const NovoInvestimentoDialog({super.key, this.onSalvar});

  @override
  State<NovoInvestimentoDialog> createState() => _NovoInvestimentoDialogState();
}

class _NovoInvestimentoDialogState extends State<NovoInvestimentoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DBHelper();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _taxaController = TextEditingController();

  DateTime _dataAplicacao = DateTime.now();
  DateTime _dataVencimento = DateTime.now().add(const Duration(days: 365));

  String _tipoRenda = 'CDB';
  String _indexador = 'posFixadoCDI';
  String _liquidez = 'Diária';
  bool _isLCI = false;

  final List<String> _tiposRenda = [
    'CDB',
    'LCI',
    'LCA',
    'Tesouro Direto',
    'Debênture',
    'CRI',
    'CRA',
    'Outros',
  ];

  final List<Map<String, dynamic>> _indexadores = const [
    {'valor': 'preFixado', 'label': 'Prefixado'},
    {'valor': 'posFixadoCDI', 'label': 'Pós-fixado (% CDI)'},
    {'valor': 'ipca', 'label': 'IPCA+'},
  ];

  final List<String> _liquidezOpcoes = [
    'Diária',
    'D+30',
    'D+60',
    'D+90',
    'No vencimento',
  ];

  double _valorFinal = 0;
  double _rendimentoLiquido = 0;
  double _iof = 0;
  double _ir = 0;

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _taxaController.dispose();
    super.dispose();
  }

  Future<void> _selecionarDataAplicacao() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataAplicacao,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _dataAplicacao = picked;
        _calcularSimulacao();
      });
    }
  }

  Future<void> _selecionarDataVencimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataVencimento,
      firstDate: _dataAplicacao,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _dataVencimento = picked;
        _calcularSimulacao();
      });
    }
  }

  void _calcularSimulacao() {
    final valor =
        double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    final taxa =
        double.tryParse(_taxaController.text.replaceAll(',', '.')) ?? 0;

    if (valor <= 0 || taxa <= 0) return;

    final dias = _dataVencimento.difference(_dataAplicacao).inDays;

    double rendimentoBruto;

    switch (_indexador) {
      case 'preFixado':
        rendimentoBruto = valor * (taxa / 100) * (dias / 365);
        break;
      case 'posFixadoCDI':
        rendimentoBruto = valor * (taxa / 100) * (dias / 365) * 0.1365;
        break;
      case 'ipca':
        rendimentoBruto = valor * (taxa / 100) * (dias / 365) * 0.045;
        break;
      default:
        rendimentoBruto = valor * (taxa / 100) * (dias / 365);
    }

    double ir = 0;
    if (!_isLCI) {
      if (dias <= 180) {
        ir = rendimentoBruto * 0.225;
      } else if (dias <= 360) {
        ir = rendimentoBruto * 0.20;
      } else if (dias <= 720) {
        ir = rendimentoBruto * 0.175;
      } else {
        ir = rendimentoBruto * 0.15;
      }
    }

    double iof = 0;
    if (dias < 30 && !_isLCI) {
      iof = rendimentoBruto * (30 - dias) / 30 * 0.96;
    }

    setState(() {
      _rendimentoLiquido = rendimentoBruto - iof - ir;
      _valorFinal = valor + _rendimentoLiquido;
      _iof = iof;
      _ir = ir;
    });
  }

  Future<void> _salvarInvestimento() async {
    if (!_formKey.currentState!.validate()) return;

    final valor =
        double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    final taxa =
        double.tryParse(_taxaController.text.replaceAll(',', '.')) ?? 0;
    final dias = _dataVencimento.difference(_dataAplicacao).inDays;

    // ✅ CONSTRUTOR CORRETO com todos os parâmetros
    final investimento = RendaFixaModel(
      id: null,
      nome: _nomeController.text,
      tipoRenda: _tipoRenda, // ← AGORA TEM ESTE PARÂMETRO!
      valorAplicado: valor,
      taxa: taxa,
      dataAplicacao: _dataAplicacao,
      dataVencimento: _dataVencimento,
      diasUteis: dias,
      rendimentoBruto: _rendimentoLiquido + _iof + _ir,
      iof: _iof,
      ir: _ir,
      rendimentoLiquido: _rendimentoLiquido,
      valorFinal: _valorFinal,
      indexador: _getIndexadorEnum(),
      liquidezDiaria: _liquidez == 'Diária',
      isIsento: _isLCI,
      status: 'ativo',
    );

    try {
      if (widget.onSalvar != null) {
        await widget.onSalvar!(investimento);
      } else {
        await _dbHelper.insertRendaFixa(investimento.toJson());
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Investimento adicionado!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Indexador _getIndexadorEnum() {
    switch (_indexador) {
      case 'preFixado':
        return Indexador.preFixado;
      case 'posFixadoCDI':
        return Indexador.posFixadoCDI;
      case 'ipca':
        return Indexador.ipca;
      default:
        return Indexador.preFixado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Investimento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Investimento',
                  hintText: 'Ex: CDB Banco XYZ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipoRenda,
                items: _tiposRenda.map<DropdownMenuItem<String>>((String tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _tipoRenda = value!),
                decoration: const InputDecoration(
                  labelText: 'Tipo de Renda',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(
                  labelText: 'Valor Aplicado',
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'R\$ ',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calcularSimulacao(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  final val = double.tryParse(value.replaceAll(',', '.'));
                  if (val == null || val <= 0) {
                    return 'Digite um valor válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _taxaController,
                decoration: InputDecoration(
                  labelText: _indexador == 'posFixadoCDI'
                      ? 'Taxa (% do CDI)'
                      : 'Taxa (% a.a.)',
                  hintText: '0,00',
                  border: OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.percent),
                  suffixText: _indexador == 'posFixadoCDI' ? '% CDI' : '% a.a.',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calcularSimulacao(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo obrigatório';
                  }
                  final val = double.tryParse(value.replaceAll(',', '.'));
                  if (val == null || val <= 0) {
                    return 'Digite uma taxa válida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _indexador,
                items: _indexadores
                    .map<DropdownMenuItem<String>>((Map<String, dynamic> item) {
                  return DropdownMenuItem<String>(
                    value: item['valor'] as String,
                    child: Text(item['label'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _indexador = value!;
                    _calcularSimulacao();
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Indexador',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _selecionarDataAplicacao,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        'Aplic: ${Formatador.data(_dataAplicacao)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _selecionarDataVencimento,
                      icon: const Icon(Icons.event),
                      label: Text(
                        'Venc: ${Formatador.data(_dataVencimento)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _liquidez,
                items: _liquidezOpcoes
                    .map<DropdownMenuItem<String>>((String opcao) {
                  return DropdownMenuItem<String>(
                    value: opcao,
                    child: Text(opcao),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _liquidez = value!),
                decoration: const InputDecoration(
                  labelText: 'Liquidez',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isLCI,
                    onChanged: (value) {
                      setState(() {
                        _isLCI = value!;
                        _calcularSimulacao();
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Text('Isento (LCI/LCA)'),
                ],
              ),
              if (_valorFinal > 0) ...[
                const Divider(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor Final:'),
                          Text(
                            Formatador.moeda(_valorFinal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Rend. Líquido:'),
                          Text(
                            Formatador.moeda(_rendimentoLiquido),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (_iof > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('IOF:', style: TextStyle(fontSize: 12)),
                            Text(
                              Formatador.moeda(_iof),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_ir > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('IR:', style: TextStyle(fontSize: 12)),
                            Text(
                              Formatador.moeda(_ir),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        GradientButton(
          text: 'Salvar',
          onPressed: _salvarInvestimento,
        ),
      ],
    );
  }
}
