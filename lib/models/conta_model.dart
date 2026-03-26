// lib/models/conta_model.dart

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
  int? id;
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
      id: json['id'] as int?,
      nome: json['nome'] as String,
      valor: (json['valor'] as num).toDouble(),
      diaVencimento: json['dia_vencimento'] as int,
      tipo: json['tipo'] == 'mensal' ? TipoConta.mensal : TipoConta.parcelada,
      categoria: json['categoria'] as String?,
      ativa: (json['ativa'] as int) == 1,
      parcelasTotal: json['parcelas_total'] as int?,
      parcelasPagas: json['parcelas_pagas'] as int?,
      dataInicio: json['data_inicio'] != null
          ? DateTime.parse(json['data_inicio'])
          : null,
      dataFim:
          json['data_fim'] != null ? DateTime.parse(json['data_fim']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'valor': valor,
      'dia_vencimento': diaVencimento,
      'tipo': tipo == TipoConta.mensal ? 'mensal' : 'parcelada',
      'categoria': categoria,
      'ativa': ativa ? 1 : 0,
      'parcelas_total': parcelasTotal,
      'parcelas_pagas': parcelasPagas,
      'data_inicio': dataInicio?.toIso8601String(),
      'data_fim': dataFim?.toIso8601String(),
    };
  }

  bool get ehParcelada => tipo == TipoConta.parcelada;
  bool get ehMensal => tipo == TipoConta.mensal;
  String get parcelasInfo {
    if (!ehParcelada || parcelasTotal == null) return '';
    return '$parcelasPagas/$parcelasTotal';
  }
}
