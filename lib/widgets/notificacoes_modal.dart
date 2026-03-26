// lib/widgets/notificacoes_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../utils/date_helper.dart';

class NotificacoesModal extends StatefulWidget {
  const NotificacoesModal({super.key});

  @override
  State<NotificacoesModal> createState() => _NotificacoesModalState();

  static Future<void> show({
    required BuildContext context,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const NotificacoesModal(),
      ),
    );
  }
}

class _NotificacoesModalState extends State<NotificacoesModal> {
  final NotificationService _notifService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notifService.registerUpdateCallback(() {
      if (mounted) setState(() {});
    });
  }

  String _formatarData(DateTime data) {
    final now = DateHelper.agoraBrasilia();
    final difference = now.difference(data);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Agora mesmo';
        }
        return 'Há ${difference.inMinutes} min';
      }
      return 'Há ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ontem';
    } else if (difference.inDays < 7) {
      return 'Há ${difference.inDays} dias';
    } else {
      return DateFormat('dd/MM/yyyy').format(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificacoes = _notifService.notificacoes;

    return Column(
      children: [
        // 🔝 CABEÇALHO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Notificações',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (notificacoes.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  onPressed: () {
                    _notifService.marcarTodasComoLidas();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Todas marcadas como lidas'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  tooltip: 'Marcar todas como lidas',
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.surface(context),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  const Icon(Icons.warning, color: Colors.red),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Limpar notificações',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Deseja remover todas as notificações?',
                          style: TextStyle(
                              color: AppColors.textSecondary(context)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                  color: AppColors.textSecondary(context)),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _notifService.limparTodas();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🗑️ Notificações removidas'),
                                  backgroundColor: Colors.orange,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('LIMPAR'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Limpar todas',
                ),
              ],
            ],
          ),
        ),

        // 📝 CONTEÚDO
        Expanded(
          child: notificacoes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: AppColors.muted(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma notificação',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'As notificações de proventos aparecerão aqui',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary(context),
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
                    final String titulo = notif['titulo'] ?? 'Notificação';
                    final String mensagem = notif['mensagem'] ?? '';
                    final DateTime data = notif['data'] ?? DateTime.now();
                    final int id = notif['id'] ?? 0;

                    return Dismissible(
                      key: Key('notif_$id'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.green,
                        child: const Icon(Icons.done, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        if (!lida) {
                          _notifService.marcarComoLida(id);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: lida
                              ? AppColors.surface(context).withOpacity(0.5)
                              : AppColors.surface(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: lida
                                ? AppColors.border(context)
                                : AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Ícone
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: ticker.contains('11')
                                    ? Colors.green.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                ticker.contains('11')
                                    ? Icons.apartment
                                    : Icons.notifications,
                                color: ticker.contains('11')
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Informações
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titulo,
                                    style: TextStyle(
                                      fontWeight: lida
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 16,
                                      color: lida
                                          ? AppColors.textSecondary(context)
                                          : AppColors.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mensagem,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatarData(data),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary(context)
                                          .withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Indicador de não lida
                            if (!lida)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
