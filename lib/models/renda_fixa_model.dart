// lib/models/renda_fixa_model.dart
import 'package:flutter/material.dart';

enum Indexador {
  preFixado,
  posFixadoCDI,
  ipca,
}

class RendaFixaModel {
  final int? id;
  final String nome;
  final String tipoRenda; // ✅ TEM QUE SER 'tipoRenda'
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

  RendaFixaModel({
    this.id,
    required this.nome,
    required this.tipoRenda, // ✅ TEM QUE SER 'tipoRenda'
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
  });

  factory RendaFixaModel.fromJson(Map<String, dynamic> json) {
    return RendaFixaModel(
      id: json['id'] as int?,
      nome: json['nome'] as String,
      tipoRenda: json['tipo_renda'] as String, // ✅ Mapeia do banco
      valorAplicado: (json['valor'] as num).toDouble(),
      taxa: (json['taxa'] as num).toDouble(),
      dataAplicacao: DateTime.parse(json['data_aplicacao']),
      dataVencimento: DateTime.parse(json['data_vencimento']),
      diasUteis: json['dias'] as int? ?? 0,
      rendimentoBruto: (json['rendimento_bruto'] as num?)?.toDouble(),
      iof: (json['iof'] as num?)?.toDouble(),
      ir: (json['ir'] as num?)?.toDouble(),
      rendimentoLiquido: (json['rendimento_liquido'] as num?)?.toDouble(),
      valorFinal: (json['valor_final'] as num?)?.toDouble(),
      indexador: _getIndexadorFromString(json['indexador'] as String?),
      liquidezDiaria: json['liquidez'] == 'Diária',
      isIsento: (json['is_lci'] as int?) == 1,
      status: json['status'] as String? ?? 'ativo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'tipo_renda': tipoRenda, // ✅ Salva como 'tipo_renda'
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
}
