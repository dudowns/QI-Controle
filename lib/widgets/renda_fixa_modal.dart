// lib/widgets/renda_fixa_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/renda_fixa_model.dart';
import '../constants/app_colors.dart';

class RendaFixaModal extends StatefulWidget {
  final RendaFixaModel? investimento;
  final Function(RendaFixaModel)? onSalvar;

  const RendaFixaModal({
    super.key,
    this.investimento,
    this.onSalvar,
  });

  @override
  State<RendaFixaModal> createState() => _RendaFixaModalState();

  static Future<void> show({
    required BuildContext context,
    RendaFixaModel? investimento,
    required Function(RendaFixaModel) onSalvar,
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
        child: RendaFixaModal(
          investimento: investimento,
          onSalvar: onSalvar,
        ),
      ),
    );
  }
}

class _RendaFixaModalState extends State<RendaFixaModal> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();
  final _taxaController = TextEditingController();

  DateTime _dataAplicacao = DateTime.now();
  DateTime _dataVencimento = DateTime.now().add(const Duration(days: 365));
  String _tipoRenda = 'CDB';
  String _indexador = 'posFixadoCDI';
  String _liquidez = 'Diária';
  bool _isIsento = false;
  bool _isLoading = false;

  final List<String> _tiposRenda = [
    'CDB',
    'LCI',
    'LCA',
    'Tesouro Direto',
    'Debênture',
    'CRI',
    'CRA',
    'Outros'
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
    'No vencimento'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.investimento != null) {
      _nomeController.text = widget.investimento!.nome;
      _valorController.text = widget.investimento!.valorAplicado
          .toStringAsFixed(2)
          .replaceAll('.', ',');
      _taxaController.text =
          widget.investimento!.taxa.toStringAsFixed(2).replaceAll('.', ',');
      _tipoRenda = widget.investimento!.tipoRenda;
      _dataAplicacao = widget.investimento!.dataAplicacao;
      _dataVencimento = widget.investimento!.dataVencimento;
      _liquidez =
          widget.investimento!.liquidezDiaria ? 'Diária' : 'No vencimento';
      _isIsento = widget.investimento!.isIsento;
      _indexador = _getIndexadorString(widget.investimento!.indexador);
    }
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

  Indexador _getIndexadorEnum(String value) {
    switch (value) {
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

  Future<void> _selecionarDataAplicacao() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataAplicacao,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dataAplicacao = picked);
  }

  Future<void> _selecionarDataVencimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataVencimento,
      firstDate: _dataAplicacao,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _dataVencimento = picked);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final valor = double.parse(_valorController.text.replaceAll(',', '.'));
      final taxa = double.parse(_taxaController.text.replaceAll(',', '.'));
      final dias = _dataVencimento.difference(_dataAplicacao).inDays;

      final investimento = RendaFixaModel(
        id: widget.investimento?.id,
        nome: _nomeController.text,
        tipoRenda: _tipoRenda,
        valorAplicado: valor,
        taxa: taxa,
        dataAplicacao: _dataAplicacao,
        dataVencimento: _dataVencimento,
        diasUteis: dias,
        indexador: _getIndexadorEnum(_indexador),
        liquidezDiaria: _liquidez == 'Diária',
        isIsento: _isIsento,
        status: 'ativo',
      );

      widget.onSalvar?.call(investimento);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.investimento != null;

    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
              isEditing ? 'Editar Renda Fixa' : 'Nova Renda Fixa', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(_nomeController, 'Nome',
                        hint: 'Ex: CDB Banco X'),
                    const SizedBox(height: 16),
                    _buildTipoSelector(),
                    const SizedBox(height: 16),
                    _buildTextField(_valorController, 'Valor',
                        isNumber: true, prefix: 'R\$ '),
                    const SizedBox(height: 16),
                    _buildTextField(_taxaController, 'Taxa',
                        isNumber: true,
                        suffix:
                            _indexador == 'posFixadoCDI' ? '% CDI' : '% a.a.'),
                    const SizedBox(height: 16),
                    _buildIndexadorSelector(),
                    const SizedBox(height: 16),
                    _buildDatePickers(),
                    const SizedBox(height: 16),
                    _buildLiquidezSelector(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _isIsento,
                          onChanged: (value) =>
                              setState(() => _isIsento = value ?? false),
                          activeColor: const Color(0xFF7B2CBF),
                        ),
                        const Text('Isento (LCI/LCA)'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildButtons(context, isEditing),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, size: 20, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint,
      bool isNumber = false,
      String prefix = '',
      String suffix = ''}) {
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
            prefixText: prefix.isEmpty ? null : prefix,
            suffixText: suffix.isEmpty ? null : suffix,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: _tipoRenda,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            items: _tiposRenda
                .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                .toList(),
            onChanged: (value) => setState(() => _tipoRenda = value!),
          ),
        ),
      ],
    );
  }

  Widget _buildIndexadorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Indexador',
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
            value: _indexador,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            items: _indexadores
                .map((item) => DropdownMenuItem(
                      value: item['valor'] as String,
                      child: Text(item['label'] as String),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _indexador = value!),
          ),
        ),
      ],
    );
  }

  Widget _buildLiquidezSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Liquidez',
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
            value: _liquidez,
            isExpanded: true,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            items: _liquidezOpcoes
                .map((opcao) =>
                    DropdownMenuItem(value: opcao, child: Text(opcao)))
                .toList(),
            onChanged: (value) => setState(() => _liquidez = value!),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickers() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aplicação',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              InkWell(
                onTap: _selecionarDataAplicacao,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_dataAplicacao)),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              InkWell(
                onTap: _selecionarDataVencimento,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_dataVencimento)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context, bool isEditing) {
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
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton(
                  onPressed: _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(isEditing ? 'ATUALIZAR' : 'SALVAR',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
        ),
      ],
    );
  }
}
