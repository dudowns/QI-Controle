// lib/utils/currency_formatter.dart
import 'package:intl/intl.dart'; // 🔥 ESSENCIAL!

class CurrencyFormatter {
  static String format(double value) {
    final format = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return format.format(value);
  }

  static String formatCompact(double value) {
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return format(value);
  }
}
