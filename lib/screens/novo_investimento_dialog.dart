// lib/screens/novo_investimento_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/renda_fixa_model.dart';
import '../constants/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../widgets/gradient_button.dart';

class NovoInvestimentoDialog extends StatefulWidget {
  final RendaFixaModel? investimento;
  final Function(RendaFixaModel)? onSalvar;

  const NovoInvestimentoDialog({
    super.key,
    this.investimento,
    this.onSalvar,
  });

  @override
  State<NovoInvestimentoDialog> createState() => _NovoInvestimentoDialogState();

  static Future<void> show({
    required BuildContext context,
    RendaFixaModel? investimento,
    Function(RendaFixaModel)? onSalvar,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: NovoInvestimentoDialog(
          investimento: investimento,
          onSalvar: onSalvar,
        ),
      ),
    );
  }
}

class _NovoInvestimentoDialogState extends State<NovoInvestimentoDialog> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _taxaController = TextEditingController();

  DateTime _dataAplicacao = DateTime.now();
  DateTime _dataVencimento = DateTime.now().add(const Duration(days: 365));

  String _tipoRenda = 'CDB';
  String _indexador = 'posFixadoCDI';
  String _liquidez = 'Diária';
  bool _isLCI = false;
  bool _isLoading = false;
  bool _isEditing = false;

  double _valorFinal = 0.0;
  double _rendimentoLiquido = 0.0;
  double _iof = 0.0;
  double _ir = 0.0;

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

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuário não logado');
    return user.id;
  }

  @override
  void initState() {
    super.initState();
    if (widget.investimento != null) {
      _isEditing = true;
      _preencherDados();
    }
  }

  void _preencherDados() {
    final inv = widget.investimento!;
    _nomeController.text = inv.nome;
    _valorController.text =
        inv.valorAplicado.toStringAsFixed(2).replaceAll('.', ',');
    _taxaController.text = inv.taxa.toStringAsFixed(2).replaceAll('.', ',');
    _tipoRenda = inv.tipoRenda;
    _dataAplicacao = inv.dataAplicacao;
    _dataVencimento = inv.dataVencimento;
    _liquidez = inv.liquidezDiaria ? 'Diária' : 'No vencimento';
    _isLCI = inv.isIsento;
    _indexador = _getIndexadorString(inv.indexador);
    _calcularSimulacao();
  }

  String _getIndexadorString(Indexador indexador) {
    switch (indexador) {
      case Indexador.preFixado:
        return 'preFixado';
      case Indexador.posFixadoCDI:
        return 'posFixadoCDI';
      case Indexador.ipca:
        return 'ipca';
    }
  }

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

    if (valor <= 0 || taxa <= 0) {
      setState(() {
        _valorFinal = 0.0;
        _rendimentoLiquido = 0.0;
        _iof = 0.0;
        _ir = 0.0;
      });
      return;
    }

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

    setState(() => _isLoading = true);

    final valor =
        double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    final taxa =
        double.tryParse(_taxaController.text.replaceAll(',', '.')) ?? 0;
    final dias = _dataVencimento.difference(_dataAplicacao).inDays;

    try {
      // 🔥 CRIA MAPA MANUALMENTE PARA EVITAR PROBLEMAS COM TIPOS
      final Map<String, dynamic> dados = {
        'nome': _nomeController.text,
        'tipo_renda': _tipoRenda,
        'valor': valor,
        'taxa': taxa,
        'data_aplicacao': _dataAplicacao.toIso8601String(),
        'data_vencimento': _dataVencimento.toIso8601String(),
        'dias': dias,
        'rendimento_bruto': _rendimentoLiquido + _iof + _ir,
        'iof': _iof,
        'ir': _ir,
        'rendimento_liquido': _rendimentoLiquido,
        'valor_final': _valorFinal,
        'indexador': _getIndexadorString(_getIndexadorEnum()),
        'liquidez': _liquidez,
        'is_lci': _isLCI ? 1 : 0,
        'status': 'ativo',
      };

      if (_isEditing && widget.investimento?.id != null) {
        // 🔥 EDIÇÃO: Forçamos a leitura do ID como String ou int conforme seu Model
        final idParaEditar = widget.investimento!.id;

        await _supabase.from('renda_fixa').update(dados).eq('id',
            idParaEditar!); // O '!' garante ao Flutter que o ID não é nulo aqui
      } else {
        // 🔥 INSERÇÃO
        dados['user_id'] = _userId;
        await _supabase.from('renda_fixa').insert(dados);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? '✅ ${_nomeController.text} atualizado!'
                : '✅ ${_nomeController.text} adicionado!'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Renda Fixa',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          _isEditing
                              ? 'Editar investimento'
                              : 'Adicionar novo investimento',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        hintText: 'Ex: CDB Banco X',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Tipo',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: _tipoRenda,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _tiposRenda
                            .map((tipo) => DropdownMenuItem(
                                value: tipo, child: Text(tipo)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _tipoRenda = value!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Valor',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _valorController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0,00',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => _calcularSimulacao(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Taxa',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _taxaController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: _indexador == 'posFixadoCDI'
                            ? 'Ex: 120'
                            : 'Ex: 12,5',
                        suffixText:
                            _indexador == 'posFixadoCDI' ? '% CDI' : '% a.a.',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => _calcularSimulacao(),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Indexador',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: _indexador,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _indexadores
                            .map((item) => DropdownMenuItem(
                                value: item['valor'] as String,
                                child: Text(item['label'] as String)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _indexador = value!;
                            _calcularSimulacao();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Aplicação',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: _selecionarDataAplicacao,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(_dataAplicacao),
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Vencimento',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: _selecionarDataVencimento,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                      DateFormat('dd/MM/yyyy')
                                          .format(_dataVencimento),
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Liquidez',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: _liquidez,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _liquidezOpcoes
                            .map((opcao) => DropdownMenuItem(
                                value: opcao, child: Text(opcao)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _liquidez = value!),
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
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Valor Final:'),
                                  Text(CurrencyFormatter.format(_valorFinal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary)),
                                ]),
                            const SizedBox(height: 4),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Rend. Líquido:'),
                                  Text(
                                      CurrencyFormatter.format(
                                          _rendimentoLiquido),
                                      style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)),
                                ]),
                            if (_iof > 0)
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('IOF:',
                                        style: TextStyle(fontSize: 12)),
                                    Text(CurrencyFormatter.format(_iof),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.red)),
                                  ]),
                            if (_ir > 0)
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('IR:',
                                        style: TextStyle(fontSize: 12)),
                                    Text(CurrencyFormatter.format(_ir),
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.red)),
                                  ]),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : GradientButton(
                                  text: _isEditing ? 'ATUALIZAR' : 'SALVAR',
                                  onPressed: _salvarInvestimento,
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
      ),
    );
  }
}
