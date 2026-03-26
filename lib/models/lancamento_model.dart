// lib/models/lancamento_model.dart

import 'package:flutter/material.dart'; // 🔥 IMPORT ADICIONADO para Colors
import 'package:intl/intl.dart'; // 🔥 IMPORT ADICIONADO para formatação

enum TipoLancamento {
  receita,
  gasto,
}

extension TipoLancamentoExtension on TipoLancamento {
  String get nome {
    switch (this) {
      case TipoLancamento.receita:
        return 'receita';
      case TipoLancamento.gasto:
        return 'gasto';
    }
  }

  static TipoLancamento fromString(String tipo) {
    if (tipo.toLowerCase() == 'receita' || tipo.toLowerCase() == 'receitas') {
      return TipoLancamento.receita;
    }
    return TipoLancamento.gasto;
  }

  Color get cor {
    switch (this) {
      case TipoLancamento.receita:
        return const Color(0xFF2E7D32);
      case TipoLancamento.gasto:
        return const Color(0xFFC62828);
    }
  }

  IconData get icone {
    switch (this) {
      case TipoLancamento.receita:
        return Icons.arrow_upward;
      case TipoLancamento.gasto:
        return Icons.arrow_downward;
    }
  }
}

class Lancamento {
  final int? id;
  final String descricao;
  final TipoLancamento tipo;
  final String categoria;
  final double valor;
  final DateTime data;
  final String? observacao;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Lancamento({
    this.id,
    required this.descricao,
    required this.tipo,
    required this.categoria,
    required this.valor,
    required this.data,
    this.observacao,
    this.createdAt,
    this.updatedAt,
  });

  // Para converter do JSON do banco
  factory Lancamento.fromJson(Map<String, dynamic> json) {
    return Lancamento(
      id: json['id'] as int?,
      descricao: json['descricao'] as String,
      tipo: TipoLancamentoExtension.fromString(json['tipo'] as String),
      categoria: json['categoria'] as String,
      valor: (json['valor'] as num).toDouble(),
      data: DateTime.parse(json['data'] as String),
      observacao: json['observacao'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Para converter para JSON (salvar no banco)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'descricao': descricao,
      'tipo': tipo.nome,
      'categoria': categoria,
      'valor': valor,
      'data': data.toIso8601String(),
      'observacao': observacao,
    };
  }

  // Cópia com alterações (útil para edição)
  Lancamento copyWith({
    int? id,
    String? descricao,
    TipoLancamento? tipo,
    String? categoria,
    double? valor,
    DateTime? data,
    String? observacao,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lancamento(
      id: id ?? this.id,
      descricao: descricao ?? this.descricao,
      tipo: tipo ?? this.tipo,
      categoria: categoria ?? this.categoria,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      observacao: observacao ?? this.observacao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Validações
  bool get isValido {
    return descricao.isNotEmpty &&
        valor > 0 &&
        categoria.isNotEmpty &&
        data.isBefore(DateTime.now().add(const Duration(days: 365)));
  }
}
