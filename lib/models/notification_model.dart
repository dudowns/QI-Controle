// lib/models/notification_model.dart

class AppNotification {
  final String? id; // 🔥 Alterado de int para String? (UUID do Supabase)
  final String titulo;
  final String mensagem;
  final DateTime data;
  final bool lida;
  final String? ticker;
  final double? valor;

  AppNotification({
    this.id, // ID agora pode ser opcional na criação manual
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
      'lida': lida, // 🔥 Enviamos como bool nativo para o Supabase
      'ticker': ticker,
      'valor': valor,
    };

    if (id != null) map['id'] = id;
    return map;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        // 🔥 Forçamos String para o ID e tratamos possíveis nulos
        id: json['id']?.toString(),
        titulo: json['titulo']?.toString() ?? '',
        mensagem: json['mensagem']?.toString() ?? '',
        data: json['data'] != null
            ? DateTime.parse(json['data'] as String)
            : DateTime.now(),
        // 🔥 No Supabase o booleano é retornado como bool, não como int (0/1)
        lida: json['lida'] is bool ? json['lida'] : (json['lida'] == 1),
        ticker: json['ticker']?.toString(),
        // 🔥 Garantimos que qualquer número do banco vire double
        valor: (json['valor'] as num?)?.toDouble(),
      );
}

// Extension para copyWith atualizada
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
