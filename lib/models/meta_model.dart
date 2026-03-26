// lib/models/meta_model.dart

import 'package:flutter/material.dart'; // 🔥 IMPORT ESSENCIAL!

enum TipoMeta {
  viagem,
  carro,
  casa,
  estudo,
  investimento,
  geral,
}

extension TipoMetaExtension on TipoMeta {
  String get nome {
    switch (this) {
      case TipoMeta.viagem:
        return 'viagem';
      case TipoMeta.carro:
        return 'carro';
      case TipoMeta.casa:
        return 'casa';
      case TipoMeta.estudo:
        return 'estudo';
      case TipoMeta.investimento:
        return 'investimento';
      case TipoMeta.geral:
        return 'geral';
    }
  }

  static TipoMeta fromString(String? tipo) {
    switch (tipo) {
      case 'viagem':
        return TipoMeta.viagem;
      case 'carro':
        return TipoMeta.carro;
      case 'casa':
        return TipoMeta.casa;
      case 'estudo':
        return TipoMeta.estudo;
      case 'investimento':
        return TipoMeta.investimento;
      default:
        return TipoMeta.geral;
    }
  }

  Color get cor {
    switch (this) {
      case TipoMeta.viagem:
        return Colors.blue;
      case TipoMeta.carro:
        return Colors.red;
      case TipoMeta.casa:
        return Colors.green;
      case TipoMeta.estudo:
        return Colors.orange;
      case TipoMeta.investimento:
        return Colors.purple;
      case TipoMeta.geral:
        return const Color(0xFF6A1B9A);
    }
  }

  IconData get icone {
    switch (this) {
      case TipoMeta.viagem:
        return Icons.flight;
      case TipoMeta.carro:
        return Icons.directions_car;
      case TipoMeta.casa:
        return Icons.home;
      case TipoMeta.estudo:
        return Icons.school;
      case TipoMeta.investimento:
        return Icons.trending_up;
      case TipoMeta.geral:
        return Icons.flag;
    }
  }
}

class DepositoMeta {
  final int? id;
  final int metaId;
  final double valor;
  final DateTime dataDeposito;
  final String? observacao;

  DepositoMeta({
    this.id,
    required this.metaId,
    required this.valor,
    required this.dataDeposito,
    this.observacao,
  });

  factory DepositoMeta.fromJson(Map<String, dynamic> json) {
    return DepositoMeta(
      id: json['id'] as int?,
      metaId: json['meta_id'] as int,
      valor: (json['valor'] as num).toDouble(),
      dataDeposito: DateTime.parse(json['data_deposito'] as String),
      observacao: json['observacao'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meta_id': metaId,
      'valor': valor,
      'data_deposito': dataDeposito.toIso8601String(),
      'observacao': observacao,
    };
  }
}

class Meta {
  final int? id;
  final String titulo;
  final String? descricao;
  final double valorObjetivo;
  final double valorAtual;
  final DateTime dataInicio;
  final DateTime dataFim;
  final TipoMeta tipo;
  final bool concluida;
  final List<DepositoMeta>? depositos;

  Meta({
    this.id,
    required this.titulo,
    this.descricao,
    required this.valorObjetivo,
    this.valorAtual = 0,
    required this.dataInicio,
    required this.dataFim,
    required this.tipo,
    this.concluida = false,
    this.depositos,
  });

  // Getters calculados
  double get progresso {
    if (valorObjetivo <= 0) return 0;
    return (valorAtual / valorObjetivo).clamp(0.0, 1.0);
  }

  double get percentual {
    return progresso * 100;
  }

  double get falta {
    return (valorObjetivo - valorAtual).clamp(0, valorObjetivo);
  }

  int get diasRestantes {
    return dataFim.difference(DateTime.now()).inDays;
  }

  bool get estaAtrasada {
    return !concluida && DateTime.now().isAfter(dataFim);
  }

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      id: json['id'] as int?,
      titulo: json['titulo'] as String,
      descricao: json['descricao'] as String?,
      valorObjetivo: (json['valor_objetivo'] as num).toDouble(),
      valorAtual: (json['valor_atual'] as num?)?.toDouble() ?? 0,
      dataInicio: DateTime.parse(json['data_inicio'] as String),
      dataFim: DateTime.parse(json['data_fim'] as String),
      tipo: TipoMetaExtension.fromString(json['cor'] as String?),
      concluida: (json['concluida'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'titulo': titulo,
      'descricao': descricao,
      'valor_objetivo': valorObjetivo,
      'valor_atual': valorAtual,
      'data_inicio': dataInicio.toIso8601String(),
      'data_fim': dataFim.toIso8601String(),
      'cor': tipo.nome,
      'icone': tipo.nome,
      'concluida': concluida ? 1 : 0,
    };
  }

  Meta copyWith({
    int? id,
    String? titulo,
    String? descricao,
    double? valorObjetivo,
    double? valorAtual,
    DateTime? dataInicio,
    DateTime? dataFim,
    TipoMeta? tipo,
    bool? concluida,
    List<DepositoMeta>? depositos,
  }) {
    return Meta(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      valorObjetivo: valorObjetivo ?? this.valorObjetivo,
      valorAtual: valorAtual ?? this.valorAtual,
      dataInicio: dataInicio ?? this.dataInicio,
      dataFim: dataFim ?? this.dataFim,
      tipo: tipo ?? this.tipo,
      concluida: concluida ?? this.concluida,
      depositos: depositos ?? this.depositos,
    );
  }
}
