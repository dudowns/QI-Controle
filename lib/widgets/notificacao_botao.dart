// lib/widgets/notificacao_botao.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';
import '../utils/formatters.dart';

class NotificacaoBotao extends StatefulWidget {
  const NotificacaoBotao({super.key});

  @override
  State<NotificacaoBotao> createState() => _NotificacaoBotaoState();
}

class _NotificacaoBotaoState extends State<NotificacaoBotao> {
  final NotificationService _notifService = NotificationService();
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _notifService.registerUpdateCallback(() {
      if (mounted) setState(() {});
    });
  }

  int get _naoLidas => _notifService.naoLidas;

  void _showDropdown() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    final RenderBox renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
              ),
            ),
            Positioned(
              top: offset.dy + size.height + 8,
              right:
                  MediaQuery.of(context).size.width - (offset.dx + size.width),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 320,
                  height: 450,
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Cabeçalho
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications,
                                color: Colors.white),
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
                            if (_naoLidas > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$_naoLidas novas',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 20),
                              onPressed: _removeOverlay,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // Lista de notificações
                      Expanded(
                        child: _notifService.notificacoes.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      size: 48,
                                      color: AppColors.muted(context),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Nenhuma notificação',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _notifService.notificacoes.length,
                                itemBuilder: (context, index) {
                                  final notif =
                                      _notifService.notificacoes[index];
                                  return _buildNotificacaoItem(notif);
                                },
                              ),
                      ),

                      // Rodapé
                      if (_notifService.notificacoes.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.border(context)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _notifService.marcarTodasComoLidas();
                                  setState(() {});
                                },
                                child: const Text(
                                  'Marcar todas como lidas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  _notifService.limparTodas();
                                  setState(() {});
                                },
                                child: const Text(
                                  'Limpar todas',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(_buttonKey.currentContext!).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildNotificacaoItem(Map<String, dynamic> notif) {
    final bool lida = notif['lida'] ?? false;
    final String ticker = notif['ticker'] ?? '';
    final String titulo = notif['titulo'] ?? 'Notificação';
    final String mensagem = notif['mensagem'] ?? '';
    final DateTime data = notif['data'] ?? DateTime.now();
    final int id = notif['id'] ?? 0;

    // Identificar tipo de notificação
    IconData icone;
    Color cor;
    if (titulo.contains('Provento')) {
      icone = Icons.monetization_on;
      cor = Colors.green;
    } else if (titulo.contains('Conta')) {
      icone = Icons.receipt;
      cor = Colors.orange;
    } else if (titulo.contains('Meta')) {
      icone = Icons.flag;
      cor = Colors.purple;
    } else {
      icone = Icons.notifications;
      cor = AppColors.primary;
    }

    return Dismissible(
      key: Key('notif_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: lida ? Colors.grey : Colors.green,
        child: const Icon(Icons.done, color: Colors.white),
      ),
      onDismissed: (direction) {
        if (!lida) {
          _notifService.marcarComoLida(id);
          setState(() {});
        }
      },
      child: GestureDetector(
        onTap: () {
          if (!lida) {
            _notifService.marcarComoLida(id);
            setState(() {});
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lida
                ? AppColors.surface(context)
                : AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: cor, size: 20),
              ),
              const SizedBox(width: 12),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: lida ? FontWeight.normal : FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mensagem,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatarData(data),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Indicador de não lida
              if (!lida)
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
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    final now = DateTime.now();
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
    return Stack(
      children: [
        IconButton(
          key: _buttonKey,
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: _showDropdown,
          tooltip: 'Notificações',
        ),
        if (_naoLidas > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '$_naoLidas',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }
}
