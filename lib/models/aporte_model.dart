// lib/models/aporte_model.dart
class AporteModel {
  final String? id;
  final String investimentoId;
  final double valor;
  final DateTime dataAplicacao;
  final double? rendimentoBruto;
  final double? iof;
  final double? ir;
  final double? rendimentoLiquido;
  final double? valorAtual;

  AporteModel({
    this.id,
    required this.investimentoId,
    required this.valor,
    required this.dataAplicacao,
    this.rendimentoBruto,
    this.iof,
    this.ir,
    this.rendimentoLiquido,
    this.valorAtual,
  });

  factory AporteModel.fromJson(Map<String, dynamic> json) => AporteModel(
        id: json['id']?.toString(),
        investimentoId: json['investimento_id']?.toString() ?? '',
        valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
        dataAplicacao: DateTime.parse(json['data_aplicacao']),
        rendimentoBruto: (json['rendimento_bruto'] as num?)?.toDouble(),
        iof: (json['iof'] as num?)?.toDouble(),
        ir: (json['ir'] as num?)?.toDouble(),
        rendimentoLiquido: (json['rendimento_liquido'] as num?)?.toDouble(),
        valorAtual: (json['valor_atual'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'investimento_id': investimentoId,
        'valor': valor,
        'data_aplicacao': dataAplicacao.toIso8601String(),
        'rendimento_bruto': rendimentoBruto,
        'iof': iof,
        'ir': ir,
        'rendimento_liquido': rendimentoLiquido,
        'valor_atual': valorAtual,
      };
}
