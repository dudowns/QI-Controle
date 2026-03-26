// lib/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // ========== CORES PRINCIPAIS (NÃO MUDAM) ==========
  static const Color primary = Color(0xFF7B2CBF);
  static const Color primaryLight = Color(0xFFB084D9);
  static const Color primaryDark = Color(0xFF5A1E8A);
  static const Color secondary = Color(0xFFB084D9);

  // ========== CORES DE FUNDO (DINÂMICAS) ==========
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF8F9FA) // Claro
        : const Color(0xFF121212); // Escuro
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1E1E1E);
  }

  static Color cardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1E1E1E);
  }

  static Color muted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFCED4DA)
        : Colors.grey[700]!;
  }

  // ========== TEXTOS (DINÂMICOS) ==========
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF343A40) // Quase preto
        : Colors.white; // Branco
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF6C757D) // Cinza médio
        : Colors.white70; // Branco com 70%
  }

  static Color textHint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFADB5BD) // Cinza claro
        : Colors.white38; // Branco com 38%
  }

  static Color textDisabled(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFCED4DA) // Cinza muito claro
        : Colors.white24; // Branco com 24%
  }

  // ========== BORDAS (DINÂMICAS) ==========
  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFDEE2E6) // Cinza claro
        : Colors.grey[800]!; // Cinza escuro
  }

  static Color borderDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFCED4DA) // Cinza médio
        : Colors.grey[700]!; // Cinza mais escuro
  }

  static Color divider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFE9ECEF) // Quase branco
        : Colors.grey[900]!; // Quase preto
  }

  // ========== STATUS (NÃO MUDAM) ==========
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFFF8F00);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color info = Color(0xFF1976D2);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ========== CATEGORIAS (NÃO MUDAM) ==========
  static const Map<String, Color> categoryColors = {
    // ===== RECEITAS =====
    'Salário': Color(0xFF2E7D32),
    'Bico ou Extra': Color(0xFFFBC02D),
    'Venda de Ativos': Color(0xFF7E57C2),

    // ===== GASTOS =====
    'Transporte': Color(0xFF42A5F5),
    'Alimentação': Color(0xFFFF7043),
    'Moradia': Color(0xFF66BB6A),
    'Lazer': Color(0xFFFFA726),
    'Saúde': Color(0xFFEF5350),
    'Educação': Color(0xFFAB47BC),
    'Cartão': Color(0xFFFF9800),
    'Investimentos': Color(0xFF7E57C2),
    'Cuidados Pessoais': Color(0xFF9C27B0),

    // ===== CONTAS =====
    'Água': Color(0xFF00ACC1),
    'Luz': Color(0xFFFFD54F),
    'Internet': Color(0xFF42A5F5),
    'Telefone': Color(0xFF7E57C2),
    'Aluguel': Color(0xFF4CAF50),
    'IPVA': Color(0xFFFF7043),
    'IPTU': Color(0xFFFF5722),
    'Academia': Color(0xFF9C27B0),
    'Streaming': Color(0xFFE91E63),
    'Empréstimo': Color(0xFFF44336),
    'Financiamento': Color(0xFFD32F2F),
    'Cartão de Crédito': Color(0xFFFF9800),

    // ===== DEFAULT =====
    'Outros': Color(0xFF9E9E9E),
  };

  // ========== GRADIENTS (NÃO MUDAM) ==========
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ========== MÉTODOS ÚTEIS ==========
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? categoryColors['Outros']!;
  }

  // ========== MÉTODO PARA PEGAR COR DE FUNDO DOS CARDS ==========
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : const Color(0xFF1E1E1E);
  }
}
