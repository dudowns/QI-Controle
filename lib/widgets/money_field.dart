// lib/widgets/money_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MoneyField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool autofocus;
  final ValueChanged<double>? onChanged;
  final String? Function(String?)? validator;

  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.autofocus = false,
    this.onChanged,
    this.validator,
  });

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  final List<TextInputFormatter> _formatters = [
    FilteringTextInputFormatter.digitsOnly,
    _MoneyInputFormatter(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: _formatters,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? '0,00',
        prefixText: 'R\$ ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
      onChanged: (value) {
        if (widget.onChanged != null) {
          final parsed = _parseMoney(value);
          if (parsed != null) widget.onChanged!(parsed);
        }
      },
      validator: widget.validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Digite um valor';
            }
            final parsed = _parseMoney(value);
            if (parsed == null || parsed <= 0) {
              return 'Digite um valor válido';
            }
            return null;
          },
    );
  }

  double? _parseMoney(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return double.parse(cleaned) / 100;
  }
}

class _MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final int value = int.parse(text);
    final String formatted =
        (value / 100).toStringAsFixed(2).replaceAll('.', ',');

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
