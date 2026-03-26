// lib/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatador {
  // Moeda
  static final NumberFormat _realFormat =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ');

  // Datas
  static final DateFormat _ddMMyyyy = DateFormat('dd/MM/yyyy');
  static final DateFormat _ddMM = DateFormat('dd/MM');
  static final DateFormat _MMMMyyyy = DateFormat('MMMM yyyy', 'pt_BR');
  static final DateFormat _MMMM = DateFormat('MMMM', 'pt_BR');
  static final DateFormat _yyyyMMdd = DateFormat('yyyy-MM-dd');

  // ========== MOEDA ==========
  static String moeda(double valor) {
    return _realFormat.format(valor);
  }

  static String moedaCompacta(double valor) {
    if (valor >= 1000000) {
      return 'R\$ ${(valor / 1000000).toStringAsFixed(1)}M';
    } else if (valor >= 1000) {
      return 'R\$ ${(valor / 1000).toStringAsFixed(1)}K';
    }
    return moeda(valor);
  }

  // ========== DATAS ==========
  static String data(DateTime data) {
    return _ddMMyyyy.format(data);
  }

  static String dataEHora(DateTime data) {
    return '${_ddMMyyyy.format(data)} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  static String diaMes(DateTime data) {
    return _ddMM.format(data);
  }

  static String mesAno(DateTime data) {
    return _MMMMyyyy.format(data).toUpperCase();
  }

  static String mes(DateTime data) {
    return _MMMM.format(data);
  }

  static String paraBanco(DateTime data) {
    return _yyyyMMdd.format(data);
  }

  // ========== RELATIVO ==========
  static String relativo(DateTime data) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(data.year, data.month, data.day);

    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) return 'Hoje';
    if (difference == 1) return 'Ontem';
    if (difference == -1) return 'Amanhã';
    if (difference > 0 && difference < 7) return 'Há $difference dias';
    if (difference < 0 && difference > -7) return 'Em ${-difference} dias';

    return Formatador.data(
        data); // ✅ CORRIGIDO: chama Formatador.data, não data(data)
  }

  // ========== PORCENTAGEM ==========
  static String percentual(double valor) {
    return '${valor.toStringAsFixed(1)}%';
  }

  // ========== NÚMEROS ==========
  static String numero(double valor, {int casas = 2}) {
    return valor.toStringAsFixed(casas);
  }
}
