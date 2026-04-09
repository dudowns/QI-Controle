// lib/models/renda_fixa_model.dart
import 'package:flutter/material.dart';

enum Indexador {
  preFixado,
  posFixadoCDI,
  ipca,
}

class RendaFixaModel {
  final String? id;
  final String nome;
  final String tipoRenda;
  final double valorAplicado;
  final double taxa;
  final DateTime dataAplicacao;
  final DateTime dataVencimento;
  final int diasUteis;
  final double? rendimentoBruto;
  final double? iof;
  final double? ir;
  final double? rendimentoLiquido;
  final double? valorFinal;
  final Indexador indexador;
  final bool liquidezDiaria;
  final bool isIsento;
  final String status;
  final String? observacao; // 🔥 NOVO CAMPO PARA HISTÓRICO DE APORTES

  RendaFixaModel({
    this.id,
    required this.nome,
    required this.tipoRenda,
    required this.valorAplicado,
    required this.taxa,
    required this.dataAplicacao,
    required this.dataVencimento,
    required this.diasUteis,
    this.rendimentoBruto,
    this.iof,
    this.ir,
    this.rendimentoLiquido,
    this.valorFinal,
    required this.indexador,
    required this.liquidezDiaria,
    required this.isIsento,
    required this.status,
    this.observacao,
  });

  factory RendaFixaModel.fromJson(Map<String, dynamic> json) {
    return RendaFixaModel(
      id: json['id']?.toString(),
      nome: json['nome']?.toString() ?? '',
      tipoRenda: json['tipo_renda']?.toString() ?? '',
      valorAplicado: (json['valor'] as num?)?.toDouble() ?? 0.0,
      taxa: (json['taxa'] as num?)?.toDouble() ?? 0.0,
      dataAplicacao: json['data_aplicacao'] != null
          ? DateTime.parse(json['data_aplicacao'] as String)
          : DateTime.now(),
      dataVencimento: json['data_vencimento'] != null
          ? DateTime.parse(json['data_vencimento'] as String)
          : DateTime.now(),
      diasUteis: (json['dias'] as num?)?.toInt() ?? 0,
      rendimentoBruto: (json['rendimento_bruto'] as num?)?.toDouble(),
      iof: (json['iof'] as num?)?.toDouble(),
      ir: (json['ir'] as num?)?.toDouble(),
      rendimentoLiquido: (json['rendimento_liquido'] as num?)?.toDouble(),
      valorFinal: (json['valor_final'] as num?)?.toDouble(),
      indexador: _getIndexadorFromString(json['indexador'] as String?),
      liquidezDiaria: json['liquidez'] == 'Diária',
      isIsento: json['is_lci'] == 1,
      status: json['status']?.toString() ?? 'ativo',
      observacao: json['observacao']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'tipo_renda': tipoRenda,
      'valor': valorAplicado,
      'taxa': taxa,
      'data_aplicacao': dataAplicacao.toIso8601String(),
      'data_vencimento': dataVencimento.toIso8601String(),
      'dias': diasUteis,
      'rendimento_bruto': rendimentoBruto,
      'iof': iof,
      'ir': ir,
      'rendimento_liquido': rendimentoLiquido,
      'valor_final': valorFinal,
      'indexador': _getIndexadorString(indexador),
      'liquidez': liquidezDiaria ? 'Diária' : 'No vencimento',
      'is_lci': isIsento ? 1 : 0,
      'status': status,
      'observacao': observacao,
    };
  }

  static Indexador _getIndexadorFromString(String? value) {
    switch (value) {
      case 'preFixado':
        return Indexador.preFixado;
      case 'posFixadoCDI':
        return Indexador.posFixadoCDI;
      case 'ipca':
        return Indexador.ipca;
      default:
        return Indexador.preFixado;
    }
  }

  static String _getIndexadorString(Indexador indexador) {
    switch (indexador) {
      case Indexador.preFixado:
        return 'preFixado';
      case Indexador.posFixadoCDI:
        return 'posFixadoCDI';
      case Indexador.ipca:
        return 'ipca';
    }
  }

  RendaFixaModel copyWith({
    String? id,
    String? nome,
    String? tipoRenda,
    double? valorAplicado,
    double? taxa,
    DateTime? dataAplicacao,
    DateTime? dataVencimento,
    int? diasUteis,
    double? rendimentoBruto,
    double? iof,
    double? ir,
    double? rendimentoLiquido,
    double? valorFinal,
    Indexador? indexador,
    bool? liquidezDiaria,
    bool? isIsento,
    String? status,
    String? observacao,
  }) {
    return RendaFixaModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      tipoRenda: tipoRenda ?? this.tipoRenda,
      valorAplicado: valorAplicado ?? this.valorAplicado,
      taxa: taxa ?? this.taxa,
      dataAplicacao: dataAplicacao ?? this.dataAplicacao,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      diasUteis: diasUteis ?? this.diasUteis,
      rendimentoBruto: rendimentoBruto ?? this.rendimentoBruto,
      iof: iof ?? this.iof,
      ir: ir ?? this.ir,
      rendimentoLiquido: rendimentoLiquido ?? this.rendimentoLiquido,
      valorFinal: valorFinal ?? this.valorFinal,
      indexador: indexador ?? this.indexador,
      liquidezDiaria: liquidezDiaria ?? this.liquidezDiaria,
      isIsento: isIsento ?? this.isIsento,
      status: status ?? this.status,
      observacao: observacao ?? this.observacao,
    );
  }
}
