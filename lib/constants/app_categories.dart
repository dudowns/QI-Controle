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
  // 🔥 UNIFICADO: inclui todas as categorias de contas também
  static const List<String> gastos = [
    // Gastos comuns
    'Transporte',
    'Alimentação',
    'Moradia',
    'Lazer',
    'Saúde',
    'Educação',
    'Cartão',
    'Investimentos',
    'Cuidados Pessoais',
    'Empréstimo',
    // Contas do mês (fixas)
    'Água',
    'Luz',
    'Internet',
    'Telefone',
    'IPVA',
    'IPTU',
    'Financiamento',
    'Cartão de Crédito',
    'Outros',
  ];

  // ========== CONTAS DO MÊS (FIXAS) ==========
  static const List<String> contas = [
    // Gastos comuns
    'Transporte',
    'Alimentação',
    'Moradia',
    'Lazer',
    'Saúde',
    'Educação',
    'Cartão',
    'Investimentos',
    'Cuidados Pessoais',
    'Empréstimo',
    'Água',
    'Luz',
    'Internet',
    'Telefone',
    'IPVA',
    'IPTU',
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

