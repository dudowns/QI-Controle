// lib/widgets/adicionar_conta_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/conta_repository.dart';
import '../constants/app_colors.dart';
import '../constants/app_categories.dart';
import 'gradient_button.dart';

class AdicionarContaModal extends StatefulWidget {
  final Function? onSalvo;
  final Map<String, dynamic>? conta;

  const AdicionarContaModal({super.key, this.onSalvo, this.conta});

  @override
  State<AdicionarContaModal> createState() => _AdicionarContaModalState();

  static Future<void> show({
    required BuildContext context,
    Map<String, dynamic>? conta,
    Function? onSalvo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: AdicionarContaModal(conta: conta, onSalvo: onSalvo),
      ),
    );
  }
}

class _AdicionarContaModalState extends State<AdicionarContaModal> {
  final ContaRepository _repository = ContaRepository();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _parcelasController = TextEditingController();

  String _tipo = 'mensal';
  String _categoria = 'Outros';
  int _diaVencimento = DateTime.now().day;
  DateTime _dataInicio = DateTime.now();
  bool _isLoading = false;

  final List<int> _dias = List.generate(31, (i) => i + 1);
  List<String> get _categorias => _repository.getCategorias();

  @override
  void initState() {
    super.initState();
    if (widget.conta != null) {
      _nomeController.text = widget.conta!['nome'] ?? '';
      _valorController.text = widget.conta!['valor'].toString();
      _tipo = widget.conta!['tipo'] ?? 'mensal';
      _categoria = widget.conta!['categoria'] ?? 'Outros';
      _diaVencimento = widget.conta!['dia_vencimento'] ?? DateTime.now().day;
      if (widget.conta!['data_inicio'] != null) {
        _dataInicio = DateTime.parse(widget.conta!['data_inicio']);
      }
      if (widget.conta!['parcelas_total'] != null) {
        _parcelasController.text = widget.conta!['parcelas_total'].toString();
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    _parcelasController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final conta = {
        'nome': _nomeController.text,
        'valor': double.parse(_valorController.text.replaceAll(',', '.')),
        'dia_vencimento': _diaVencimento,
        'tipo': _tipo,
        'categoria': _categoria,
        'data_inicio': _dataInicio.toIso8601String(),
        'ativa': 1,
      };

      if (_tipo == 'parcelada') {
        conta['parcelas_total'] = int.parse(_parcelasController.text);
        conta['parcelas_pagas'] = 0;
      }

      if (widget.conta != null) {
        conta['id'] = widget.conta!['id'];
        await _repository.atualizarConta(conta);
      } else {
        await _repository.adicionarConta(conta);
      }

      if (mounted) {
        widget.onSalvo?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ${_nomeController.text} ${widget.conta != null ? 'atualizada' : 'adicionada'}!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho
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
                      const Text('Contas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text(
                          widget.conta != null
                              ? 'Editar conta'
                              : 'Adicionar nova conta',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          // Formulário
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    const Text('Nome da conta',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                          hintText: 'Ex: Netflix, Aluguel',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Digite o nome' : null,
                    ),
                    const SizedBox(height: 16),

                    // Tipo
                    const Text('Tipo',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTipoButton(
                                'Mensal', 'mensal', Icons.repeat)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildTipoButton('Parcelada', 'parcelada',
                                Icons.format_list_numbered)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Valor e Dia
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Valor',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _valorController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    hintText: '0,00',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    prefixText: 'R\$ '),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Digite o valor'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dia',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(12)),
                                child: DropdownButton<int>(
                                  value: _diaVencimento,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  items: _dias
                                      .map((d) => DropdownMenuItem(
                                          value: d, child: Text(d.toString())))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _diaVencimento = v!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Categoria
                    const Text('Categoria',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: _categoria,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _categorias
                            .map((cat) =>
                                DropdownMenuItem(value: cat, child: Text(cat)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoria = v!),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Data início
                    const Text('Data de início',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selecionarData,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(_dataInicio),
                                style: const TextStyle(fontSize: 16)),
                            Icon(Icons.calendar_today,
                                color: Colors.grey[600], size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Parcelas (se parcelada)
                    if (_tipo == 'parcelada') ...[
                      const Text('Total de parcelas',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _parcelasController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            hintText: 'Ex: 12',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Digite o número de parcelas'
                            : null,
                      ),
                      const SizedBox(height: 16),
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
                                  text: widget.conta != null
                                      ? 'ATUALIZAR'
                                      : 'SALVAR',
                                  onPressed: _salvar),
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

  Widget _buildTipoButton(String label, String value, IconData icon) {
    final isSelected = _tipo == value;
    return GestureDetector(
      onTap: () => setState(() => _tipo = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[300]!,
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : Colors.grey[600],
                size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey[600],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
