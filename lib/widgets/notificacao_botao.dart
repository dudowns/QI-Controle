// lib/widgets/notificacao_botao.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Fundo escuro
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
            // Card do dropdown
            Positioned(
              top: offset.dy + size.height + 12,
              right: screenWidth - (offset.dx + size.width),
              child: FadeInDown(
                duration: const Duration(milliseconds: 300),
                child: Material(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 360,
                    constraints: const BoxConstraints(maxHeight: 480),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cabeçalho com gradiente
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.notifications_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$_naoLidas nova(s)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _removeOverlay,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Lista de notificações
                        Flexible(
                          child: _notifService.notificacoes.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.notifications_none_rounded,
                                          size: 48,
                                          color: AppColors.primary
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Nenhuma notificação',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Você está em dia! 🎉',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  shrinkWrap: true,
                                  itemCount: _notifService.notificacoes.length,
                                  itemBuilder: (context, index) {
                                    final notif =
                                        _notifService.notificacoes[index];
                                    return FadeInUp(
                                      delay: Duration(milliseconds: 50 * index),
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: _buildNotificacaoItem(notif),
                                    );
                                  },
                                ),
                        ),

                        // Rodapé
                        if (_notifService.notificacoes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: AppColors.border(context)
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    _notifService.marcarTodasComoLidas();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.done_all_rounded,
                                      size: 16),
                                  label: const Text('Marcar lidas'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    _notifService.limparTodas();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 16),
                                  label: const Text('Limpar'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red.shade400,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
    final String titulo = notif['titulo'] ?? 'Notificação';
    final String mensagem = notif['mensagem'] ?? '';
    final DateTime data = notif['data'] is DateTime
        ? notif['data']
        : DateTime.tryParse(notif['data']?.toString() ?? '') ?? DateTime.now();
    final int id = notif['id'] ?? 0;

    // Tipo e cor
    IconData icone;
    Color cor;
    String tipo;
    if (titulo.toLowerCase().contains('provento') ||
        titulo.toLowerCase().contains('dividendo')) {
      icone = Icons.monetization_on_rounded;
      cor = const Color(0xFF4CAF50);
      tipo = 'Provento';
    } else if (titulo.toLowerCase().contains('conta') ||
        titulo.toLowerCase().contains('vencendo')) {
      icone = Icons.receipt_long_rounded;
      cor = const Color(0xFFFF9800);
      tipo = 'Conta';
    } else if (titulo.toLowerCase().contains('meta')) {
      icone = Icons.flag_rounded;
      cor = const Color(0xFF2196F3);
      tipo = 'Meta';
    } else if (titulo.toLowerCase().contains('invest') ||
        titulo.toLowerCase().contains('tesouro')) {
      icone = Icons.trending_up_rounded;
      cor = const Color(0xFF9C27B0);
      tipo = 'Investimento';
    } else {
      icone = Icons.notifications_rounded;
      cor = AppColors.primary;
      tipo = 'Geral';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: lida ? Colors.transparent : cor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            if (!lida) {
              _notifService.marcarComoLida(id);
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: lida
                  ? null
                  : Border.all(color: cor.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone com gradiente
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cor.withValues(alpha: 0.7), cor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
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
                              tipo,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: cor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!lida)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: lida ? FontWeight.w500 : FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mensagem,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatarData(data),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
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
    );
  }

  String _formatarData(DateTime data) {
    final now = DateTime.now();
    final difference = now.difference(data);

    if (difference.inMinutes < 1) return 'Agora mesmo';
    if (difference.inHours < 1) return 'Há ${difference.inMinutes}min';
    if (difference.inHours < 24) return 'Há ${difference.inHours}h';
    if (difference.inDays == 1) return 'Ontem';
    if (difference.inDays < 7) return 'Há ${difference.inDays} dias';
    return DateFormat('dd/MM/yy').format(data);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            key: _buttonKey,
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white),
            onPressed: _showDropdown,
            tooltip: 'Notificações',
          ),
        ),
        if (_naoLidas > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  _naoLidas > 9 ? '9+' : '$_naoLidas',
                  style: const TextStyle(
                    fontSize: 9,
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
