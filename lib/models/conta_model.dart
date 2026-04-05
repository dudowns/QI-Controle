// lib/models/conta_model.dart

import 'package:flutter/foundation.dart';

enum TipoConta {
  mensal, // Netflix, Claro, etc (aparece todo mês)
  parcelada, // Compra parcelada (aparece até acabar)
}

enum StatusPagamento {
  pendente,
  pago,
  atrasado,
}

extension StatusPagamentoExtension on StatusPagamento {
  String get nome {
    switch (this) {
      case StatusPagamento.pendente:
        return 'Pendente';
      case StatusPagamento.pago:
        return 'Pago';
      case StatusPagamento.atrasado:
        return 'Atrasado';
    }
  }

  String get nomeAcao {
    switch (this) {
      case StatusPagamento.pendente:
        return 'PAGAR AGORA';
      case StatusPagamento.pago:
        return 'JÁ PAGO';
      case StatusPagamento.atrasado:
        return 'PAGAR';
    }
  }
}

class Conta {
  String? id; // 🔥 Alterado de int? para String? (UUID do Supabase)
  String nome;
  double valor;
  int diaVencimento; // 1 a 31
  TipoConta tipo;
  String? categoria;
  bool ativa;

  // Para contas parceladas
  int? parcelasTotal;
  int? parcelasPagas;
  DateTime? dataInicio;
  DateTime? dataFim;

  Conta({
    this.id,
    required this.nome,
    required this.valor,
    required this.diaVencimento,
    required this.tipo,
    this.categoria,
    this.ativa = true,
    this.parcelasTotal,
    this.parcelasPagas,
    this.dataInicio,
    this.dataFim,
  });

  factory Conta.fromJson(Map<String, dynamic> json) {
    return Conta(
      // 🔥 Forçamos o ID a ser String independente do que venha do banco
      id: json['id']?.toString(),
      nome: json['nome'] as String,
      // Usamos 'num' antes do double para evitar erros de cast
      valor: (json['valor'] as num).toDouble(),
      diaVencimento: (json['dia_vencimento'] as num).toInt(),
      tipo: json['tipo'] == 'mensal' ? TipoConta.mensal : TipoConta.parcelada,
      categoria: json['categoria'] as String?,
      // 🔥 No Supabase o booleano é retornado como bool, não como int (0/1)
      ativa: json['ativa'] is bool ? json['ativa'] : (json['ativa'] == 1),
      parcelasTotal: json['parcelas_total'] != null
          ? (json['parcelas_total'] as num).toInt()
          : null,
      parcelasPagas: json['parcelas_pagas'] != null
          ? (json['parcelas_pagas'] as num).toInt()
          : null,
      dataInicio: json['data_inicio'] != null
          ? DateTime.parse(json['data_inicio'])
          : null,
      dataFim:
          json['data_fim'] != null ? DateTime.parse(json['data_fim']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'nome': nome,
      'valor': valor,
      'dia_vencimento': diaVencimento,
      'tipo': tipo == TipoConta.mensal ? 'mensal' : 'parcelada',
      'categoria': categoria,
      'ativa': ativa, // 🔥 Enviamos como bool nativo para o Supabase
      'parcelas_total': parcelasTotal,
      'parcelas_pagas': parcelasPagas,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
    };

    // Só adiciona o ID se ele não for nulo (útil para updates)
    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  bool get ehParcelada => tipo == TipoConta.parcelada;
  bool get ehMensal => tipo == TipoConta.mensal;

  String get parcelasInfo {
    if (!ehParcelada || parcelasTotal == null) return '';
    return '${parcelasPagas ?? 0}/${parcelasTotal ?? 0}';
  }
}
