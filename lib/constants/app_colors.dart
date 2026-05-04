// lib/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // ========== CORES PRINCIPAIS (Extraídas da Imagem) ==========
  static const Color primary = Color(0xFF1B5F8C);
  static const Color primaryLight = Color(0xFF2E86AB);
  static const Color primaryDark = Color(0xFF0077A3);
  static const Color secondary = Color(0xFFFF8C00);

  // ========== FUNDO (TEMA ESCURO) ==========
  static const Color darkBackground = Color(0xFF061229);
  static const Color darkSurface = Color(0xFF0A1E46);
  static const Color darkCard = Color(0xFF0E2855);
  static const Color darkInput = Color(0xFF132D5E);
  static const Color darkBorder = Color(0xFF1B3D7A);

  // ========== FUNDO (TEMA CLARO) ==========
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // ========== BACKGROUND DINÂMICO ==========
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? lightBackground
          : darkBackground;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? lightSurface
          : darkSurface;

  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? lightCard : darkCard;

  static Color inputBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF5F5F5)
          : darkInput;

  // ========== TEXTOS ==========
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF061229)
          : Colors.white;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF6C757D)
          : const Color(0xFF8DA2C0);

  // ========== GRADIENTES ==========
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF061229), Color(0xFF0A1E46)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ========== STATUS ==========
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);
  static const Color warning = Color(0xFFFF8F00);
  static const Color info = Color(0xFF1B5F8C);

  // ========== MUTED / BORDER / DIVIDER ==========
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFCED4DA)
          : Colors.grey[700]!;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFDEE2E6)
          : darkBorder;

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFE9ECEF)
          : Colors.grey[900]!;

  static Color textHint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFADB5BD)
          : Colors.white38;

  // ========== CATEGORIAS ==========
  static const Map<String, Color> categoryColors = {
    // Receitas
    'Salário': Color(0xFF00E676),
    'Bico ou Extra': Color(0xFFFBC02D),
    'Venda de Ativos': Color(0xFF7E57C2),

    // Gastos comuns
    'Transporte': Color(0xFF42A5F5),
    'Alimentação': Color(0xFFFF7043),
    'Moradia': Color(0xFF66BB6A),
    'Lazer': Color(0xFFFF8C00),
    'Saúde': Color(0xFFEF4444),
    'Educação': Color(0xFF8B5CF6),
    'Cartão': Color(0xFFFF9800),
    'Investimentos': Color(0xFF00AEEF),
    'Cuidados Pessoais': Color(0xFFE91E63),
    'Empréstimo': Color(0xFFF44336),

    // Contas do mês
    'Água': Color(0xFF00ACC1),
    'Luz': Color(0xFFFFD54F),
    'Internet': Color(0xFF42A5F5),
    'Telefone': Color(0xFF7E57C2),
    'IPVA': Color(0xFFFF7043),
    'IPTU': Color(0xFFFF5722),
    'Financiamento': Color(0xFFD32F2F),
    'Cartão de Crédito': Color(0xFFFF9800),

    // Default
    'Outros': Color(0xFF6B7280),
  };

  static Color getCategoryColor(String category) =>
      categoryColors[category] ?? categoryColors['Outros']!;
}
