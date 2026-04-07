import 'package:flutter/material.dart';

class LogoService {
  static IconData getDefaultIcon(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'ACAO':
        return Icons.trending_up;
      case 'FII':
        return Icons.apartment;
      case 'ETF':
        return Icons.bubble_chart;
      case 'CRIPTO':
        return Icons.currency_bitcoin;
      default:
        return Icons.show_chart;
    }
  }
}

