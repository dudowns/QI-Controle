// lib/utils/formatters.dart
import 'package:intl/intl.dart';

class Formatador {
  static final NumberFormat _realFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormat = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 1,
  );

  static final DateFormat _ddMMyyyy = DateFormat('dd/MM/yyyy');
  static final DateFormat _ddMM = DateFormat('dd/MM');
  static final DateFormat _mmmmYyyy = DateFormat('MMMM yyyy', 'pt_BR');
  static final DateFormat _mmmm = DateFormat('MMMM', 'pt_BR');
  static final DateFormat _yyyyMMdd = DateFormat('yyyy-MM-dd');

  // ========== MOEDA ==========
  static String moeda(double valor) {
    if (valor.isNaN || valor.isInfinite) return 'R\$ 0,00';
    return _realFormat.format(valor);
  }

  static String moedaCompacta(double valor) {
    if (valor.isNaN || valor.isInfinite) return 'R\$ 0';
    if (valor >= 1000000) {
      return 'R\$ ${(valor / 1000000).toStringAsFixed(1)}M';
    } else if (valor >= 1000) {
      return 'R\$ ${(valor / 1000).toStringAsFixed(1)}K';
    }
    return _realFormat.format(valor);
  }

  static String moedaSimples(double valor) {
    if (valor.isNaN || valor.isInfinite) return '0,00';
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String moedaSemSimbolo(double valor) {
    if (valor.isNaN || valor.isInfinite) return '0,00';
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  // ========== DATAS ==========
  static String data(DateTime data) {
    return _ddMMyyyy.format(data);
  }

  static String dataHora(DateTime data) {
    return '${_ddMMyyyy.format(data)} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  static String diaMes(DateTime data) {
    return _ddMM.format(data);
  }

  static String mesAno(DateTime data) {
    return _mmmmYyyy.format(data).toUpperCase();
  }

  static String mes(DateTime data) {
    return _mmmm.format(data);
  }

  static String paraBanco(DateTime data) {
    return _yyyyMMdd.format(data);
  }

  static DateTime fromBanco(String data) {
    return _yyyyMMdd.parse(data);
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

    return Formatador.data(data);
  }

  static String tempoAtras(DateTime data) {
    final diff = DateTime.now().difference(data);
    if (diff.inDays > 30) return Formatador.data(data);
    if (diff.inDays > 7) return '${diff.inDays} dias';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return 'Agora';
  }

  // ========== PORCENTAGEM ==========
  static String percentual(double valor) {
    return '${valor.toStringAsFixed(1)}%';
  }

  static String percentualCor(double valor) {
    final prefix = valor >= 0 ? '+' : '';
    return '$prefix${valor.toStringAsFixed(2)}%';
  }

  // ========== NÚMEROS ==========
  static String numero(double valor, {int casas = 2}) {
    return valor.toStringAsFixed(casas);
  }

  static String numeroComSeparador(double valor) {
    return NumberFormat('#,##0.00', 'pt_BR').format(valor);
  }

  // ========== UTILITÁRIOS ==========
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String limitarTexto(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
