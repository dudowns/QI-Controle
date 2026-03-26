// lib/constants/app_categories.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppCategories {
  // ========== CATEGORIAS DE RECEITAS ==========
  static const List<String> receitas = [
    'Salário',
    'Bico ou Extra',
    'Venda de Ativos',
    'Outros',
  ];

  // ========== CATEGORIAS DE GASTOS (DESPESAS) ==========
  static const List<String> gastos = [
    'Transporte',
    'Alimentação',
    'Moradia',
    'Lazer',
    'Saúde',
    'Educação',
    'Cartão',
    'Investimentos',
    'Cuidados Pessoais',
    'Outros',
  ];

  // ========== CONTAS DO MÊS (FIXAS) ==========
  static const List<String> contas = [
    'Água',
    'Luz',
    'Internet',
    'Telefone',
    'Aluguel',
    'IPVA',
    'IPTU',
    'Academia',
    'Streaming',
    'Empréstimo',
    'Financiamento',
    'Cartão de Crédito',
    'Outros',
  ];

  // ========== MÉTODO PARA OBTER COR ==========
  static Color getColor(String categoria) {
    return AppColors.categoryColors[categoria] ??
        AppColors.categoryColors['Outros']!;
  }

  // ========== VERIFICAR SE CATEGORIA EXISTE ==========
  static bool existe(String categoria) {
    return AppColors.categoryColors.containsKey(categoria);
  }
}
