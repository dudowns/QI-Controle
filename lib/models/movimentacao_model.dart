// lib/models/movimentacao_model.dart

class Movimentacao {
  final String? id; // 🔥 UUID do Supabase
  final String ticker;
  final String tipo; // 'COMPRA' ou 'VENDA'
  final double quantidade;
  final double preco;
  final double taxa;
  final DateTime data;
  final String? observacao;

  Movimentacao({
    this.id,
    required this.ticker,
    required this.tipo,
    required this.quantidade,
    required this.preco,
    this.taxa = 0,
    required this.data,
    this.observacao,
  });

  double get valorTotal => (quantidade * preco) + taxa;
  double get valorSemTaxa => quantidade * preco;

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      // 🔥 Forçamos String para o ID (UUID)
      id: json['id']?.toString(),
      ticker: json['ticker']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'COMPRA',
      // 🔥 Conversão robusta para evitar erro de 'int' vs 'double'
      quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0.0,
      preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
      taxa: (json['taxa'] as num?)?.toDouble() ?? 0.0,
      // Verificação de segurança na data
      data: json['data'] != null
          ? DateTime.parse(json['data'] as String)
          : DateTime.now(),
      observacao: json['observacao']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'ticker': ticker.toUpperCase().trim(),
      'tipo': tipo.toUpperCase(),
      'quantidade': quantidade,
      'preco': preco,
      'taxa': taxa,
      'data': data.toIso8601String(),
      'observacao': observacao,
    };

    // Adiciona o id apenas se ele não for nulo (para atualizações)
    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  bool get isCompra => tipo.toUpperCase() == 'COMPRA';
  bool get isVenda => tipo.toUpperCase() == 'VENDA';
}
