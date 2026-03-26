// lib/models/pagamento_model.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'conta_model.dart';

class PagamentoMes {
  int? id;
  int contaId;
  String contaNome;
  int anoMes;
  double valor;
  DateTime? dataPagamento;
  StatusPagamento status;
  int diaVencimento;

  PagamentoMes({
    this.id,
    required this.contaId,
    required this.contaNome,
    required this.anoMes,
    required this.valor,
    this.dataPagamento,
    required this.status,
    required this.diaVencimento,
  });

  factory PagamentoMes.fromJson(Map<String, dynamic> json) {
    return PagamentoMes(
      id: json['id'] as int?,
      contaId: json['conta_id'] as int,
      contaNome: json['conta_nome'] as String,
      anoMes: json['ano_mes'] as int,
      valor: (json['valor'] as num).toDouble(),
      dataPagamento: json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'])
          : null,
      status: StatusPagamento.values[json['status'] as int],
      diaVencimento: json['dia_vencimento'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conta_id': contaId,
      'ano_mes': anoMes,
      'valor': valor,
      'data_pagamento': dataPagamento?.toIso8601String(),
      'status': status.index,
    };
  }

  String get mesAnoFormatado {
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    return DateFormat('MMMM/yyyy', 'pt_BR').format(DateTime(ano, mes));
  }

  String get diaFormatado {
    return diaVencimento.toString().padLeft(2, '0');
  }

  String get dataVencimentoFormatada {
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    return '$diaFormatado/${mes.toString().padLeft(2, '0')}/$ano';
  }

  bool get estaPago => status == StatusPagamento.pago;

  bool get estaAtrasado {
    if (estaPago) return false;

    final hoje = DateTime.now();
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    final dataVencimento = DateTime(ano, mes, diaVencimento);

    return dataVencimento.isBefore(hoje);
  }
}
