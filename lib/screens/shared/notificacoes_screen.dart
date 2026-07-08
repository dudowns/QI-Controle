// lib/screens/notificacoes_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../../constants/app_colors.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({super.key});

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  int get _unreadCount => _notifications.where((n) => !n.lida).length;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    // TODO: Carregar do repositório
    // Exemplo mockado:
    setState(() {
      _notifications = [
        AppNotification(
          titulo: 'Dividendo recebido! 💰',
          mensagem: 'BBAS3 pagou R\$ 45,80 em dividendos na sua conta.',
          data: DateTime.now().subtract(const Duration(hours: 2)),
          ticker: 'BBAS3',
          valor: 45.80,
        ),
        AppNotification(
          titulo: 'Conta vencendo hoje 📅',
          mensagem: 'Aluguel - R\$ 1.200,00 vence hoje. Não esqueça de pagar!',
          data: DateTime.now().subtract(const Duration(hours: 5)),
          valor: 1200.00,
        ),
        AppNotification(
          titulo: 'Meta quase lá! 🎯',
          mensagem: 'Viagem Europa atingiu 50% do objetivo. Continue assim!',
          data: DateTime.now().subtract(const Duration(days: 1)),
          lida: true,
        ),
        AppNotification(
          titulo: 'Tesouro Direto atualizado 📈',
          mensagem: 'Seus títulos renderam +1.2% este mês.',
          data: DateTime.now().subtract(const Duration(days: 2)),
          lida: true,
        ),
        AppNotification(
          titulo: 'Boas-vindas ao QI Controle! 🚀',
          mensagem:
              'Seu app financeiro está pronto. Cadastre suas primeiras metas!',
          data: DateTime.now().subtract(const Duration(days: 7)),
          lida: true,
        ),
      ];
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(int index) async {
    if (_notifications[index].lida) return;
    setState(() {
      _notifications[index] = _notifications[index].copyWith(lida: true);
    });
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(lida: true)).toList();
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limpar notificações'),
        content: const Text('Todas as notificações serão removidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Limpar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _notifications.clear());
    }
  }

  Color _getCardColor(AppNotification notification) {
    if (notification.ticker != null) return const Color(0xFF4CAF50); // Provento
    if (notification.titulo.toLowerCase().contains('conta')) {
      return const Color(0xFFFF9800);
    }
    if (notification.titulo.toLowerCase().contains('meta')) {
      return const Color(0xFF2196F3);
    }
    if (notification.titulo.toLowerCase().contains('invest') ||
        notification.titulo.toLowerCase().contains('tesouro')) {
      return const Color(0xFF9C27B0);
    }
    return const Color(0xFF607D8B);
  }

  String _getCardIcon(AppNotification notification) {
    if (notification.ticker != null) return '💵';
    if (notification.titulo.toLowerCase().contains('conta')) return '📅';
    if (notification.titulo.toLowerCase().contains('meta')) return '🎯';
    if (notification.titulo.toLowerCase().contains('invest') ||
        notification.titulo.toLowerCase().contains('tesouro')) {
      return '📈';
    }
    return '🔔';
  }

  String _getCardLabel(AppNotification notification) {
    if (notification.ticker != null) return 'Provento';
    if (notification.titulo.toLowerCase().contains('conta')) return 'Conta';
    if (notification.titulo.toLowerCase().contains('meta')) return 'Meta';
    if (notification.titulo.toLowerCase().contains('invest') ||
        notification.titulo.toLowerCase().contains('tesouro')) {
      return 'Investimento';
    }
    return 'Geral';
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('dd/MM/yy').format(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return 'agora';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary(context),
        elevation: 0,
        title: Row(
          children: [
            const Text('Notificações',
                style: TextStyle(fontWeight: FontWeight.bold)),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty) ...[
            if (_unreadCount > 0)
              IconButton(
                onPressed: _markAllAsRead,
                icon: const Icon(Icons.done_all),
                tooltip: 'Marcar todas como lidas',
              ),
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpar todas',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _notifications.asMap().entries.map((entry) {
                      final index = entry.key;
                      final notification = entry.value;
                      return _buildNotificationCard(notification, index);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none, size: 80),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhuma notificação',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Você está em dia! 🎉',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, int index) {
    final cor = _getCardColor(notification);
    final icone = _getCardIcon(notification);
    final label = _getCardLabel(notification);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _markAsRead(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: notification.lida
                    ? Colors.transparent
                    : cor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cor.withValues(alpha: 0.7), cor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(icone, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                // Conteúdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: cor),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _getTimeAgo(notification.data),
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[400]),
                          ),
                          const SizedBox(width: 4),
                          if (!notification.lida)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.mensagem,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.valor != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'R\$ ${notification.valor!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
