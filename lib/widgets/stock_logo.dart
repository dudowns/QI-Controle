// lib/widgets/stock_logo.dart
import 'package:flutter/material.dart';

class StockLogo extends StatelessWidget {
  final String ticker;
  final String tipo;
  final double size;

  const StockLogo({
    super.key,
    required this.ticker,
    required this.tipo,
    this.size = 40,
  });

  // Pega as 2 primeiras letras
  String getInitials() {
    if (ticker.length >= 2) {
      return ticker.substring(0, 2);
    }
    return ticker;
  }

  // Cor baseada no ticker (cores diferentes para cada empresa)
  Color getColor() {
    final String code = ticker.substring(0, 2).toUpperCase();

    final colors = {
      'BB': const Color(0xFF2E7D32), // Verde BB
      'PE': const Color(0xFF1976D2), // Azul Petrobras
      'VA': const Color(0xFFC62828), // Vermelho Vale
      'IT': const Color(0xFF1565C0), // Azul Itaú
      'BD': const Color(0xFFFF9800), // Laranja Bradesco
      'AB': const Color(0xFF4CAF50), // Verde Ambev
      'B3': const Color(0xFF9C27B0), // Roxo B3
      'GG': const Color(0xFF00897B), // Teal GGRC11
      'RZ': const Color(0xFF5E35B1), // Índigo RZTR11
      'TA': const Color(0xFF00ACC1), // Ciano TAEE11
      'VG': const Color(0xFFD81B60), // Rosa VGHF11
      'HG': const Color(0xFF7CB342), // Verde HGLG11
      'VI': const Color(0xFFFB8C00), // Laranja VISC11
    };

    return colors[code] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final Color cor = getColor();
    final String iniciais = getInitials();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cor,
            cor.withOpacity(0.7),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          iniciais,
          style: TextStyle(
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
