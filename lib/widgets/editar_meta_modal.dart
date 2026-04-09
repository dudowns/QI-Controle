// lib/widgets/editar_meta_modal.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class EditarMetaModal extends StatefulWidget {
  final Map<String, dynamic> meta;
  final Future<void> Function()? onSalvo;

  const EditarMetaModal({super.key, required this.meta, this.onSalvo});

  @override
  State<EditarMetaModal> createState() => _EditarMetaModalState();

  static Future<void> show(
      {required BuildContext context,
      required Map<String, dynamic> meta,
      Future<void> Function()? onSalvo}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: EditarMetaModal(meta: meta, onSalvo: onSalvo),
      ),
    );
  }
}

class _EditarMetaModalState extends State<EditarMetaModal> {
  final DBHelper _dbHelper = DBHelper();
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorObjetivoController = TextEditingController();
  String _corSelecionada = 'viagem';
  String _iconeSelecionado = 'viagem';
  DateTime? _dataFim;
  bool _isLoading = false;

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
  void initState() {
    super.initState();
    _tituloController.text = widget.meta['titulo'] ?? '';
    _descricaoController.text = widget.meta['descricao'] ?? '';
    final valor = (widget.meta['valor_objetivo'] ?? 0).toDouble();
    _valorObjetivoController.text =
        valor.toStringAsFixed(2).replaceAll('.', ',');
    _corSelecionada = widget.meta['cor'] ?? 'viagem';
    _iconeSelecionado = widget.meta['icone'] ?? 'viagem';
    _dataFim = DateTime.parse(widget.meta['data_fim']);
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
        context: context,
        initialDate: _dataFim ?? DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
    if (data != null) setState(() => _dataFim = data);
  }

  double _parseValor(String texto) =>
      double.tryParse(
          texto.replaceAll(',', '.').replaceAll('R\$', '').trim()) ??
      0;

  Future<void> _salvarMeta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma data limite')));
      return;
    }
    final valorObjetivo = _parseValor(_valorObjetivoController.text);
    if (valorObjetivo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digite um valor válido')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _dbHelper.updateMeta({
        'id': widget.meta['id'],
        'titulo': _tituloController.text,
        'descricao': _descricaoController.text,
        'valor_objetivo': valorObjetivo,
        'data_fim': _dataFim!.toIso8601String(),
        'cor': _corSelecionada,
        'icone': _iconeSelecionado
      });
      if (widget.onSalvo != null) await widget.onSalvo!();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 580),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('Editar Meta', context),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo da meta',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                        height: 60,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _opcoesTipo.length,
                            itemBuilder: (context, index) {
                              final opcao = _opcoesTipo[index];
                              final isSelected =
                                  _corSelecionada == opcao['cor'];
                              return GestureDetector(
                                  onTap: () => setState(() {
                                        _corSelecionada = opcao['cor'];
                                        _iconeSelecionado = opcao['icone'];
                                      }),
                                  child: Container(
                                      width: 70,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                          color: isSelected
                                              ? (opcao['color'] as Color)
                                                  .withValues(alpha: 0.2)
                                              : Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: isSelected
                                                  ? opcao['color'] as Color
                                                  : Colors.grey[300]!,
                                              width: isSelected ? 2 : 1)),
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                _getIconeParaTipo(
                                                    opcao['icone']),
                                                color: isSelected
                                                    ? opcao['color'] as Color
                                                    : Colors.grey[600]),
                                            const SizedBox(height: 4),
                                            Text(opcao['nome'],
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isSelected
                                                        ? opcao['color']
                                                            as Color
                                                        : Colors.grey[600]))
                                          ])));
                            })),
                    const SizedBox(height: 20),
                    _buildTextField(_tituloController, 'Título',
                        hint: 'Ex: Viagem para a praia'),
                    const SizedBox(height: 16),
                    _buildTextField(
                        _descricaoController, 'Descrição (opcional)',
                        maxLines: 2),
                    const SizedBox(height: 16),
                    _buildTextField(_valorObjetivoController, 'Valor da meta',
                        isNumber: true, prefix: 'R\$ '),
                    const SizedBox(height: 16),
                    _buildDatePickerField(),
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
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, size: 20, color: Colors.grey[500]))
        ]));
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {String? hint,
      bool isNumber = false,
      String prefix = '',
      int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
              hintText: hint ?? label,
              prefixText: prefix.isEmpty ? null : prefix,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          validator: (v) => v == null || v.isEmpty ? 'Digite $label' : null)
    ]);
  }

  Widget _buildDatePickerField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Data limite',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      InkWell(
          onTap: _selecionarData,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        _dataFim != null
                            ? Formatador.data(_dataFim!)
                            : 'Selecionar data',
                        style: const TextStyle(fontSize: 14)),
                    Icon(Icons.calendar_today,
                        size: 18, color: Colors.grey[500])
                  ])))
    ]);
  }

  Widget _buildButtons(BuildContext context) {
    return Row(children: [
      Expanded(
          child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Cancelar'))),
      const SizedBox(width: 12),
      Expanded(
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator()))
              : ElevatedButton(
                  onPressed: _salvarMeta,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CBF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('SALVAR')))
    ]);
  }

  IconData _getIconeParaTipo(String tipo) => switch (tipo) {
        'viagem' => Icons.flight,
        'carro' => Icons.directions_car,
        'casa' => Icons.home,
        'estudo' => Icons.school,
        'investimento' => Icons.trending_up,
        _ => Icons.flag
      };
}
