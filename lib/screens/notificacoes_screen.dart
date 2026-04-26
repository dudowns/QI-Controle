// lib/screens/notificacoes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  final NotificationService _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifService.registerUpdateCallback(() {
      if (mounted) setState(() {});
    });
  }

  String _formatarData(DateTime data) {
    final now = DateTime.now();
    final difference = now.difference(data);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora mesmo';
        }
        return 'Ha ${difference.inMinutes} min';
      }
      return 'Ha ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return 'Ha ${difference.inDays} dias';
    } else {
      return DateFormat('dd/MM/yyyy').format(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificacoes = _notifService.notificacoes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificacoes'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        actions: [
          if (notificacoes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () {
                _notifService.marcarTodasComoLidas();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todas marcadas como lidas'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          if (notificacoes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Limpar notificacoes'),
                    content:
                        const Text('Deseja remover todas as notificacoes?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _notifService.limparTodas();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: notificacoes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma notificacao',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As notificacoes de proventos aparecerao aqui',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notificacoes.length,
              itemBuilder: (context, index) {
                final notif = notificacoes[index];
                final bool lida = notif['lida'] ?? false;
                final String ticker = notif['ticker'] ?? '';
                final String titulo = notif['titulo'] ?? 'Notificacao';
                final String mensagem = notif['mensagem'] ?? '';
                final DateTime data = notif['data'] is DateTime
                    ? notif['data']
                    : DateTime.parse(notif['data'].toString());
                final int id = notif['id'] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: lida ? Colors.white : const Color(0xFFF0E6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: lida
                          ? Colors.grey[300]!
                          : const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ticker.contains('11')
                            ? Colors.green.withValues(alpha: 0.1)
                            : const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        ticker.contains('11')
                            ? Icons.apartment
                            : Icons.notifications,
                        color: ticker.contains('11')
                            ? Colors.green
                            : const Color(0xFF6A1B9A),
                      ),
                    ),
                    title: Text(
                      titulo,
                      style: TextStyle(
                        fontWeight: lida ? FontWeight.normal : FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          mensagem,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatarData(data),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    trailing: lida
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6A1B9A),
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      if (!lida) {
                        setState(() {
                          _notifService.marcarComoLida(id);
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
