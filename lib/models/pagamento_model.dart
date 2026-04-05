// lib/models/pagamento_model.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'conta_model.dart';

class PagamentoMes {
  String? id; // 🔥 Alterado de int? para String? (UUID do Supabase)
  String contaId; // 🔥 Alterado de int para String (UUID da Conta pai)
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
    // 🔥 Lógica para converter o status (aceita índice int ou nome String)
    StatusPagamento parseStatus(dynamic statusJson) {
      if (statusJson is int) return StatusPagamento.values[statusJson];
      if (statusJson is String) {
        return StatusPagamento.values.firstWhere(
          (e) => e.name.toLowerCase() == statusJson.toLowerCase(),
          orElse: () => StatusPagamento.pendente,
        );
      }
      return StatusPagamento.pendente;
    }

    return PagamentoMes(
      id: json['id']?.toString(),
      contaId: json['conta_id']?.toString() ?? '',
      contaNome: json['conta_nome']?.toString() ?? 'Conta Removida',
      anoMes: (json['ano_mes'] as num?)?.toInt() ?? 0,
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      dataPagamento: json['data_pagamento'] != null
          ? DateTime.parse(json['data_pagamento'] as String)
          : null,
      status: parseStatus(json['status']),
      diaVencimento: (json['dia_vencimento'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'conta_id': contaId,
      'ano_mes': anoMes,
      'valor': valor,
      'data_pagamento': dataPagamento?.toIso8601String(),
      // 🔥 Salvamos como String no Supabase para facilitar a leitura no dashboard
      'status': status.name,
      'dia_vencimento': diaVencimento,
    };

    if (id != null) map['id'] = id;
    return map;
  }

  String get mesAnoFormatado {
    if (anoMes < 100) return 'Data Inválida';
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    return DateFormat('MMMM/yyyy', 'pt_BR').format(DateTime(ano, mes));
  }

  String get diaFormatado {
    return diaVencimento.toString().padLeft(2, '0');
  }

  String get dataVencimentoFormatada {
    if (anoMes < 100) return '--/--/----';
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;
    return '$diaFormatado/${mes.toString().padLeft(2, '0')}/$ano';
  }

  bool get estaPago => status == StatusPagamento.pago;

  bool get estaAtrasado {
    if (estaPago || anoMes < 100) return false;

    final hoje = DateTime.now();
    final ano = anoMes ~/ 100;
    final mes = anoMes % 100;

    // Vencimento no último momento do dia
    final dataVencimento = DateTime(ano, mes, diaVencimento, 23, 59, 59);

    return dataVencimento.isBefore(hoje);
  }
}
