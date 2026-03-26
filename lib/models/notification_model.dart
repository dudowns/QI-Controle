class AppNotification {
  final int id;
  final String titulo;
  final String mensagem;
  final DateTime data;
  final bool lida;
  final String? ticker;
  final double? valor;

  AppNotification({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.data,
    this.lida = false,
    this.ticker,
    this.valor,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'mensagem': mensagem,
        'data': data.toIso8601String(),
        'lida': lida ? 1 : 0,
        'ticker': ticker,
        'valor': valor,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        titulo: json['titulo'],
        mensagem: json['mensagem'],
        data: DateTime.parse(json['data']),
        lida: json['lida'] == 1,
        ticker: json['ticker'],
        valor: json['valor']?.toDouble(),
      );
}

// Extension para copyWith
extension AppNotificationExtension on AppNotification {
  AppNotification copyWith({bool? lida}) => AppNotification(
        id: id,
        titulo: titulo,
        mensagem: mensagem,
        data: data,
        lida: lida ?? this.lida,
        ticker: ticker,
        valor: valor,
      );
}
