// lib/models/transacao_model.dart

class Transacao {
  final String? id; // 🔥 Alterado de int? para String? (UUID do Supabase)
  final String ticker;
  final String tipo; // 'COMPRA' ou 'VENDA'
  final double quantidade;
  final double preco;
  final DateTime data;
  final double? taxa; // opcional

  Transacao({
    this.id,
    required this.ticker,
    required this.tipo,
    required this.quantidade,
    required this.preco,
    required this.data,
    this.taxa,
  });

  double get valorTotal => (quantidade * preco) + (taxa ?? 0.0);

  // No Supabase, costuma-se usar toJson() por padrão, mas mantive toMap() se preferir
  Map<String, dynamic> toMap() {
    final map = {
      'ticker': ticker.toUpperCase().trim(),
      'tipo': tipo.toUpperCase(),
      'quantidade': quantidade,
      'preco': preco,
      'data': data.toIso8601String(),
      'taxa': taxa,
    };

    if (id != null) map['id'] = id;
    return map;
  }

  // 🔥 Alias para toJson() para manter compatibilidade com os outros modelos
  Map<String, dynamic> toJson() => toMap();

  factory Transacao.fromMap(Map<String, dynamic> map) {
    return Transacao(
      // 🔥 Forçamos String para o ID (UUID)
      id: map['id']?.toString(),
      ticker: map['ticker']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? 'COMPRA',
      // 🔥 Conversão robusta de num para double (evita erro de subtype)
      quantidade: (map['quantidade'] as num?)?.toDouble() ?? 0.0,
      preco: (map['preco'] as num?)?.toDouble() ?? 0.0,
      data: map['data'] != null
          ? DateTime.parse(map['data'] as String)
          : DateTime.now(),
      taxa: (map['taxa'] as num?)?.toDouble(),
    );
  }

  // 🔥 Alias para fromJson() para manter compatibilidade
  factory Transacao.fromJson(Map<String, dynamic> json) =>
      Transacao.fromMap(json);
}

