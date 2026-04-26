// lib/widgets/adicionar_conta_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../repositories/conta_repository.dart';
import '../constants/app_colors.dart';
import '../services/logger_service.dart';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  List<String> get _categorias => _repository.getCategorias().toSet().toList();

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
                '${_nomeController.text} ${widget.conta != null ? 'atualizada' : 'adicionada'}!'),
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
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(
              widget.conta != null ? 'Editar Conta' : 'Nova Conta', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_nomeController, 'Nome da conta',
                        hint: 'Ex: Netflix, Aluguel'),
                    const SizedBox(height: 16),
                    _buildTipoSelector(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildValorField()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDiaSelector()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCategoriaSelector(),
                    const SizedBox(height: 16),
                    _buildDatePickerField(),
                    const SizedBox(height: 16),
                    if (_tipo == 'parcelada') _buildParcelasField(),
                    const SizedBox(height: 24),
                    _buildButtons(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 20, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint ?? label,
            hintStyle: const TextStyle(color: Color(0xFF999999)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF7B2CBF), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Digite o $label' : null,
        ),
      ],
    );
  }

  Widget _buildTipoSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildTipoButton('Mensal', 'mensal', Icons.repeat)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildTipoButton(
                    'Parcelada', 'parcelada', Icons.format_list_numbered)),
          ],
        ),
      ],
    );
  }

  Widget _buildTipoButton(String label, String value, IconData icon) {
    final isSelected = _tipo == value;
    return GestureDetector(
      onTap: () => setState(() => _tipo = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7B2CBF).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected ? const Color(0xFF7B2CBF) : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF7B2CBF)
                        : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildValorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Valor',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _valorController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0,00',
            prefixText: 'R\$ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Digite o valor' : null,
        ),
      ],
    );
  }

  Widget _buildDiaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dia',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<int>(
            value: _diaVencimento,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            items: _dias
                .map((d) =>
                    DropdownMenuItem(value: d, child: Text(d.toString())))
                .toList(),
            onChanged: (v) => setState(() => _diaVencimento = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriaSelector() {
    final categorias = _categorias;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categoria',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value:
                categorias.contains(_categoria) ? _categoria : categorias.first,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            items: categorias
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (v) => setState(() => _categoria = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data de inicio',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selecionarData,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('dd/MM/yyyy').format(_dataInicio),
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF333333))),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParcelasField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total de parcelas',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF333333))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _parcelasController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ex: 12',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) =>
              v == null || v.isEmpty ? 'Digite o numero de parcelas' : null,
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.grey[400]!),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(widget.conta != null ? 'ATUALIZAR' : 'SALVAR',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
