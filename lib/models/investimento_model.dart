// lib/models/investimento_model.dart

import 'package:flutter/material.dart'; // 🔥 IMPORT ADICIONADO para Colors

enum TipoInvestimento {
  acao,
  fii,
  etf,
  bdr,
  cripto,
}

extension TipoInvestimentoExtension on TipoInvestimento {
  String get nome {
    switch (this) {
      case TipoInvestimento.acao:
        return 'ACAO';
      case TipoInvestimento.fii:
        return 'FII';
      case TipoInvestimento.etf:
        return 'ETF';
      case TipoInvestimento.bdr:
        return 'BDR';
      case TipoInvestimento.cripto:
        return 'CRIPTO';
    }
  }

  static TipoInvestimento fromString(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'ACAO':
        return TipoInvestimento.acao;
      case 'FII':
        return TipoInvestimento.fii;
      case 'ETF':
        return TipoInvestimento.etf;
      case 'BDR':
        return TipoInvestimento.bdr;
      case 'CRIPTO':
        return TipoInvestimento.cripto;
      default:
        return TipoInvestimento.acao;
    }
  }

  Color get cor {
    switch (this) {
      case TipoInvestimento.acao:
        return Colors.blue;
      case TipoInvestimento.fii:
        return Colors.green;
      case TipoInvestimento.etf:
        return Colors.purple;
      case TipoInvestimento.bdr:
        return Colors.orange;
      case TipoInvestimento.cripto:
        return Colors.amber;
    }
  }

  IconData get icone {
    switch (this) {
      case TipoInvestimento.acao:
        return Icons.trending_up;
      case TipoInvestimento.fii:
        return Icons.apartment;
      case TipoInvestimento.etf:
        return Icons.show_chart;
      case TipoInvestimento.bdr:
        return Icons.public;
      case TipoInvestimento.cripto:
        return Icons.currency_bitcoin;
    }
  }

  String get nomeAmigavel {
    switch (this) {
      case TipoInvestimento.acao:
        return 'Ações';
      case TipoInvestimento.fii:
        return 'FIIs';
      case TipoInvestimento.etf:
        return 'ETFs';
      case TipoInvestimento.bdr:
        return 'BDRs';
      case TipoInvestimento.cripto:
        return 'Criptomoedas';
    }
  }
}

class Investimento {
  final int? id;
  final String ticker;
  final TipoInvestimento tipo;
  final double quantidade;
  final double precoMedio;
  final double? precoAtual;
  final DateTime dataCompra;
  final String? corretora;
  final String? setor;
  final double? dividendYield;
  final DateTime? ultimaAtualizacao;

  Investimento({
    this.id,
    required this.ticker,
    required this.tipo,
    required this.quantidade,
    required this.precoMedio,
    this.precoAtual,
    required this.dataCompra,
    this.corretora,
    this.setor,
    this.dividendYield,
    this.ultimaAtualizacao,
  });

  // Getters calculados
  double get valorInvestido => quantidade * precoMedio;

  double get valorAtual => quantidade * (precoAtual ?? precoMedio);

  double get variacaoTotal => valorAtual - valorInvestido;

  double get variacaoPercentual {
    if (valorInvestido == 0) return 0;
    return ((valorAtual - valorInvestido) / valorInvestido) * 100;
  }

  bool get temPrecoAtualizado => precoAtual != null && precoAtual! > 0;

  factory Investimento.fromJson(Map<String, dynamic> json) {
    return Investimento(
      id: json['id'] as int?,
      ticker: json['ticker'] as String,
      tipo: TipoInvestimentoExtension.fromString(json['tipo'] as String),
      quantidade: (json['quantidade'] as num).toDouble(),
      precoMedio: (json['preco_medio'] as num).toDouble(),
      precoAtual: (json['preco_atual'] as num?)?.toDouble(),
      dataCompra: DateTime.parse(json['data_compra'] as String),
      corretora: json['corretora'] as String?,
      setor: json['setor'] as String?,
      dividendYield: (json['dividend_yield'] as num?)?.toDouble(),
      ultimaAtualizacao: json['ultima_atualizacao'] != null
          ? DateTime.parse(json['ultima_atualizacao'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticker': ticker,
      'tipo': tipo.nome,
      'quantidade': quantidade,
      'preco_medio': precoMedio,
      'preco_atual': precoAtual,
      'data_compra': dataCompra.toIso8601String(),
      'corretora': corretora,
      'setor': setor,
      'dividend_yield': dividendYield,
      'ultima_atualizacao': ultimaAtualizacao?.toIso8601String(),
    };
  }

  Investimento copyWith({
    int? id,
    String? ticker,
    TipoInvestimento? tipo,
    double? quantidade,
    double? precoMedio,
    double? precoAtual,
    DateTime? dataCompra,
    String? corretora,
    String? setor,
    double? dividendYield,
    DateTime? ultimaAtualizacao,
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
      ultimaAtualizacao: ultimaAtualizacao ?? this.ultimaAtualizacao,
    );
  }
}
