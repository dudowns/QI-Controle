// lib/models/provento_model.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TipoProvento {
  dividendo,
  jcp,
  rendaFixa,
  outros,
}

extension TipoProventoExtension on TipoProvento {
  String get nome {
    switch (this) {
      case TipoProvento.dividendo:
        return 'Dividendo';
      case TipoProvento.jcp:
        return 'JCP';
      case TipoProvento.rendaFixa:
        return 'Renda Fixa';
      case TipoProvento.outros:
        return 'Outros';
    }
  }

  static TipoProvento fromString(String? tipo) {
    switch (tipo) {
      case 'Dividendo':
        return TipoProvento.dividendo;
      case 'JCP':
        return TipoProvento.jcp;
      case 'Renda Fixa':
        return TipoProvento.rendaFixa;
      default:
        return TipoProvento.outros;
    }
  }

  Color get cor {
    switch (this) {
      case TipoProvento.dividendo:
        return const Color(0xFF4CAF50);
      case TipoProvento.jcp:
        return Colors.orange;
      case TipoProvento.rendaFixa:
        return Colors.teal;
      case TipoProvento.outros:
        return Colors.purple;
    }
  }

  IconData get icone {
    switch (this) {
      case TipoProvento.dividendo:
        return Icons.monetization_on;
      case TipoProvento.jcp:
        return Icons.receipt;
      case TipoProvento.rendaFixa:
        return Icons.savings;
      case TipoProvento.outros:
        return Icons.category;
    }
  }
}

class Provento {
  final String? id; // 🔥 Alterado de int? para String? (UUID)
  final String ticker;
  final TipoProvento tipo;
  final double valorPorCota;
  final double quantidade;
  final DateTime dataPagamento;
  final DateTime? dataCom;
  final double totalRecebido;
  final bool syncAutomatico;

  Provento({
    this.id,
    required this.ticker,
    required this.tipo,
    required this.valorPorCota,
    required this.quantidade,
    required this.dataPagamento,
    this.dataCom,
    double? totalRecebido,
    this.syncAutomatico = false,
  }) : totalRecebido = totalRecebido ?? (valorPorCota * quantidade);

  // Getters
  bool get isFuturo => dataPagamento.isAfter(DateTime.now());

  bool get isPassado => dataPagamento.isBefore(DateTime.now());

  int get diasRestantes {
    if (!isFuturo) return 0;
    return dataPagamento.difference(DateTime.now()).inDays;
  }

  factory Provento.fromJson(Map<String, dynamic> json) {
    return Provento(
      // 🔥 Forçamos String para o ID
      id: json['id']?.toString(),
      ticker: json['ticker']?.toString() ?? '',
      tipo: TipoProventoExtension.fromString(
          json['tipo_provento']?.toString() ?? 'Dividendo'),
      // 🔥 Conversão robusta de num para double
      valorPorCota: (json['valor_por_cota'] as num?)?.toDouble() ?? 0.0,
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 1.0,
      dataPagamento: json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'] as String)
          : DateTime.now(),
      dataCom: json['data_com'] != null
          ? DateTime.parse(json['data_com'] as String)
          : null,
      totalRecebido: (json['total_recebido'] as num?)?.toDouble(),
      // 🔥 No Supabase booleano é bool nativo
      syncAutomatico: json['sync_automatico'] is bool
          ? json['sync_automatico']
          : (json['sync_automatico'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'ticker': ticker.toUpperCase().trim(),
      'tipo_provento': tipo.nome,
      'valor_por_cota': valorPorCota,
      'quantidade': quantidade,
      'data_pagamento': dataPagamento.toIso8601String(),
      'data_com': dataCom?.toIso8601String(),
      'total_recebido': totalRecebido,
      'sync_automatico': syncAutomatico,
    };

    if (id != null) map['id'] = id;
    return map;
  }

  Provento copyWith({
    String? id, // 🔥 Alterado para String?
    String? ticker,
    TipoProvento? tipo,
    double? valorPorCota,
    double? quantidade,
    DateTime? dataPagamento,
    DateTime? dataCom,
    double? totalRecebido,
    bool? syncAutomatico,
  }) {
    return Provento(
      id: id ?? this.id,
      ticker: ticker ?? this.ticker,
      tipo: tipo ?? this.tipo,
      valorPorCota: valorPorCota ?? this.valorPorCota,
      quantidade: quantidade ?? this.quantidade,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      dataCom: dataCom ?? this.dataCom,
      totalRecebido: totalRecebido ?? this.totalRecebido,
      syncAutomatico: syncAutomatico ?? this.syncAutomatico,
    );
  }
}
