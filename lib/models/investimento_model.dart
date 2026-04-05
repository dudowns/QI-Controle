// lib/models/investimento_model.dart
import 'package:flutter/material.dart';

class Investimento {
  final String? id; // UUID do Supabase
  final String ticker;
  final String tipo;
  final double quantidade;
  final double precoMedio;
  double? precoAtual;
  final String? dataCompra;
  final String? corretora;
  final String? setor;
  final double? dividendYield;

  double get valorInvestido => quantidade * precoMedio;
  double get valorAtual => quantidade * (precoAtual ?? precoMedio);
  double get variacaoTotal => valorAtual - valorInvestido;
  double get variacaoPercentual =>
      valorInvestido > 0 ? (variacaoTotal / valorInvestido) * 100 : 0;

  Investimento({
    this.id,
    required this.ticker,
    required this.tipo,
    required this.quantidade,
    required this.precoMedio,
    this.precoAtual,
    this.dataCompra,
    this.corretora,
    this.setor,
    this.dividendYield,
  });

  factory Investimento.fromJson(Map<String, dynamic> json) {
    return Investimento(
      // 🔥 Forçamos a conversão para String para evitar erro de UUID/int
      id: json['id']?.toString(),
      ticker: json['ticker']?.toString().toUpperCase() ?? '',
      tipo: json['tipo']?.toString().toUpperCase() ?? '',
      // 🔥 Usamos (as num?) antes do toDouble() para aceitar int ou double do Supabase
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0.0,
      precoMedio: (json['preco_medio'] as num?)?.toDouble() ?? 0.0,
      precoAtual: (json['preco_atual'] as num?)?.toDouble(),
      dataCompra: json['data_compra']?.toString(),
      corretora: json['corretora']?.toString(),
      setor: json['setor']?.toString(),
      dividendYield: (json['dividend_yield'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'ticker': ticker.toUpperCase(),
      'tipo': tipo.toUpperCase(),
      'quantidade': quantidade,
      'preco_medio': precoMedio,
      'preco_atual': precoAtual,
      'data_compra': dataCompra,
      'corretora': corretora,
      'setor': setor,
      'dividend_yield': dividendYield,
    };

    // Adiciona o id apenas se ele existir (para updates)
    if (id != null) map['id'] = id;

    return map;
  }

  Investimento copyWith({
    String? id,
    String? ticker,
    String? tipo,
    double? quantidade,
    double? precoMedio,
    double? precoAtual,
    String? dataCompra,
    String? corretora,
    String? setor,
    double? dividendYield,
  }) {
    return Investimento(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      tipo: tipo ?? this.tipo,
      quantidade: quantidade ?? this.quantidade,
      precoMedio: precoMedio ?? this.precoMedio,
      precoAtual: precoAtual ?? this.precoAtual,
      dataCompra: dataCompra ?? this.dataCompra,
      corretora: corretora ?? this.corretora,
      setor: setor ?? this.setor,
      dividendYield: dividendYield ?? this.dividendYield,
    );
  }
}

// 🔥 CLASSE TIPO INVESTIMENTO
class TipoInvestimento {
  static const String acao = 'ACAO';
  static const String fii = 'FII';
  static const String etf = 'ETF';
  static const String bdr = 'BDR';
  static const String cripto = 'CRIPTO';

  static String getNomeAmigavel(String tipo) {
    switch (tipo.toUpperCase()) {
      case acao:
        return 'Ações';
      case fii:
        return 'FIIs';
      case etf:
        return 'ETFs';
      case bdr:
        return 'BDRs';
      case cripto:
        return 'Cripto';
      default:
        return tipo;
    }
  }

  static Color getCor(String tipo) {
    switch (tipo.toUpperCase()) {
      case acao:
        return const Color(0xFF3B82F6);
      case fii:
        return const Color(0xFF10B981);
      case etf:
        return const Color(0xFFF59E0B);
      case bdr:
        return const Color(0xFF8B5CF6);
      case cripto:
        return const Color(0xFFEC489A);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
