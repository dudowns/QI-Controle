// lib/utils/currency_formatter.dart
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double? value) {
    if (value == null || value.isNaN || value == 0) {
      return 'R\$ 0,00';
    }
    final format = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return format.format(value);
  }

  static String formatCompact(double? value) {
    if (value == null || value.isNaN || value == 0) {
      return 'R\$ 0';
    }
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return format(value);
  }
}

