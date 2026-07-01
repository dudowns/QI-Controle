// lib/models/notification_model.dart
class AppNotification {
  final String? id;
  final String titulo;
  final String mensagem;
  final DateTime data;
  final bool lida;
  final String? ticker;
  final double? valor;

  AppNotification({
    this.id,
    required this.titulo,
    required this.mensagem,
    required this.data,
    this.lida = false,
    this.ticker,
    this.valor,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'titulo': titulo,
      'mensagem': mensagem,
      'data': data.toIso8601String(),
      'lida': lida,
      'ticker': ticker,
      'valor': valor,
    };

    if (id != null) map['id'] = id;
    return map;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString(),
        titulo: (json['titulo'] as String?) ?? '',
        mensagem: (json['mensagem'] as String?) ?? '',
        data: json['data'] != null
            ? DateTime.tryParse(json['data'].toString()) ?? DateTime.now()
            : DateTime.now(),
        lida: json['lida'] is bool ? json['lida'] : (json['lida'] == 1),
        ticker: json['ticker']?.toString(),
        valor: (json['valor'] as num?)?.toDouble(),
      );
}

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
