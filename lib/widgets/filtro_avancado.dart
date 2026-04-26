// lib/widgets/filtro_avancado.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class FiltroAvancado extends StatefulWidget {
  final Function(Map<String, dynamic>) onAplicar;
  final Map<String, dynamic>? filtrosIniciais;

  const FiltroAvancado({
    super.key,
    required this.onAplicar,
    this.filtrosIniciais,
  });

  @override
  State<FiltroAvancado> createState() => _FiltroAvancadoState();
}

class _FiltroAvancadoState extends State<FiltroAvancado> {
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String? _tipo;
  String? _categoria;
  double? _valorMin;
  double? _valorMax;

  final List<String> _tipos = ['Todos', 'Receita', 'Despesa'];
  final List<String> _categorias = [
    'Todos',
    'Salário',
    'Alimentação',
    'Transporte',
    'Lazer',
    'Saúde',
    'Educação'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.filtrosIniciais != null) {
      _dataInicio = widget.filtrosIniciais!['data_inicio'];
      _dataFim = widget.filtrosIniciais!['data_fim'];
      _tipo = widget.filtrosIniciais!['tipo'];
      _categoria = widget.filtrosIniciais!['categoria'];
      _valorMin = widget.filtrosIniciais!['valor_min'];
      _valorMax = widget.filtrosIniciais!['valor_max'];
    }
  }

  void _aplicar() {
    final filtros = <String, dynamic>{};
    if (_dataInicio != null) filtros['data_inicio'] = _dataInicio;
    if (_dataFim != null) filtros['data_fim'] = _dataFim;
    if (_tipo != null && _tipo != 'Todos') filtros['tipo'] = _tipo;
    if (_categoria != null && _categoria != 'Todos')
      filtros['categoria'] = _categoria;
    if (_valorMin != null) filtros['valor_min'] = _valorMin;
    if (_valorMax != null) filtros['valor_max'] = _valorMax;
    widget.onAplicar(filtros);
    Navigator.pop(context);
  }

  void _limpar() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
      _tipo = null;
      _categoria = null;
      _valorMin = null;
      _valorMax = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filtros Avançados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Período
          const Text('Período', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker('Início', _dataInicio, (date) {
                  setState(() => _dataInicio = date);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePicker('Fim', _dataFim, (date) {
                  setState(() => _dataFim = date);
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tipo
          const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildDropdown(
              _tipos, _tipo, (value) => setState(() => _tipo = value)),
          const SizedBox(height: 16),

          // Categoria
          const Text('Categoria',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildDropdown(_categorias, _categoria,
              (value) => setState(() => _categoria = value)),
          const SizedBox(height: 16),

          // Valor
          const Text('Valor', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildValorField('Mínimo', _valorMin, (value) {
                  setState(() => _valorMin = value);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildValorField('Máximo', _valorMax, (value) {
                  setState(() => _valorMax = value);
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _limpar,
                  child: const Text('Limpar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _aplicar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? date, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(date != null ? _formatDate(date) : label),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      List<String> items, String? selected, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        value: selected ?? items.first,
        isExpanded: true,
        underline: const SizedBox(),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: (value) => onChanged(value!),
      ),
    );
  }

  Widget _buildValorField(
      String label, double? value, Function(double?) onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (text) {
        final val = double.tryParse(text.replaceAll(',', '.'));
        onChanged(val);
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
