// lib/utils/mask_formatters.dart
import 'package:flutter/services.dart';

class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String cleaned = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return newValue;

    double value = double.parse(cleaned) / 100;
    String formatted = value.toStringAsFixed(2).replaceAll('.', ',');

    return TextEditingValue(
      text: 'R\$ $formatted',
      selection: TextSelection.collapsed(offset: formatted.length + 3),
    );
  }
}
