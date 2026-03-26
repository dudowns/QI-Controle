// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 🔥 IMPORT PARA debugPrint
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../services/sync_service.dart';
import '../widgets/theme_selector.dart';
import '../widgets/backup_modal.dart';
import '../widgets/notificacoes_modal.dart';
import 'dashboard.dart';
import 'lancamentos.dart';
import 'contas_do_mes_screen.dart';
import 'investimentos_tabs.dart';
import 'metas_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  // Controle de sincronização
  final SyncService _syncService = SyncService();
  bool _isSyncing = false;

  // Realtime subscription
  RealtimeChannel? _realtimeChannel;
  bool _realtimeConnected = false;

  final List<String> _titles = [
    'Dashboard',
    'Gastos',
    'Contas do Mês',
    'Invest',
    'Metas',
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _screens = const [
      DashboardScreen(),
      LancamentosScreen(),
      ContasDoMesScreen(),
      InvestimentosTabsScreen(),
      MetasScreen(),
    ];

    // Sincronizar ao abrir o app
    _sincronizarDados();

    // Iniciar Realtime
    _initRealtime();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // Inicializar Realtime (CORRIGIDO)
  void _initRealtime() {
    try {
      final supabase = Supabase.instance.client;

      _realtimeChannel = supabase.channel('public:changes');

      // Escutar mudanças na tabela lancamentos
      _realtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'lancamentos',
        callback: (payload) {
          debugPrint('🔄 Mudança detectada em lancamentos');
          _onDataChanged();
        },
      );

      // Escutar mudanças na tabela investimentos
      _realtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'investimentos',
        callback: (payload) {
          debugPrint('🔄 Mudança detectada em investimentos');
          _onDataChanged();
        },
      );

      // Escutar mudanças na tabela metas
      _realtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'metas',
        callback: (payload) {
          debugPrint('🔄 Mudança detectada em metas');
          _onDataChanged();
        },
      );

      // Escutar mudanças na tabela proventos
      _realtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'proventos',
        callback: (payload) {
          debugPrint('🔄 Mudança detectada em proventos');
          _onDataChanged();
        },
      );

      // Subscrever
      _realtimeChannel?.subscribe((status, error) {
        if (mounted) {
          setState(() {
            _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
          });
          debugPrint('📡 Realtime status: $status');
        }
        if (error != null) {
          debugPrint('❌ Erro no Realtime: $error');
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao iniciar Realtime: $e');
    }
  }

  // Quando dados mudam em tempo real
  void _onDataChanged() {
    if (!mounted) return;

    // Mostrar snackbar indicando mudança
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados atualizados em tempo real!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Sincronizar dados
  Future<void> _sincronizarDados() async {
    setState(() => _isSyncing = true);
    await _syncService.syncNow();
    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              _titles[_currentIndex],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            // Indicador de sincronização
            if (_isSyncing)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            // Indicador de Realtime
            if (_realtimeConnected)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        actions: [
          // Botão de sincronização manual
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                _isSyncing ? Icons.sync : Icons.sync_outlined,
                color: Colors.white,
              ),
              onPressed: _isSyncing ? null : _sincronizarDados,
              tooltip: 'Sincronizar agora',
            ),
          ),

          // SELETOR DE TEMA
          const ThemeSelector(),

          // BOTÃO DE BACKUP
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.backup_outlined),
              onPressed: () {
                BackupModal.show(
                  context: context,
                  onBackupRealizado: () {
                    debugPrint('Backup realizado/restaurado/excluído');
                    _sincronizarDados();
                  },
                );
              },
              tooltip: 'Backup',
              color: Colors.white,
            ),
          ),

          // BOTÃO DE NOTIFICAÇÕES
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                NotificacoesModal.show(context: context);
              },
              tooltip: 'Notificações',
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          boxShadow: [
            if (Theme.of(context).brightness == Brightness.light)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                    Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(
                    Icons.pie_chart_outline, Icons.pie_chart, 'Gastos', 1),
                _buildNavItem(
                    Icons.receipt_outlined, Icons.receipt, 'Contas', 2),
                _buildNavItem(
                    Icons.trending_up_outlined, Icons.trending_up, 'Invest', 3),
                _buildNavItem(Icons.flag_outlined, Icons.flag, 'Metas', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData iconOutlined, IconData iconFilled, String label, int index) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
          _animationController.forward(from: 0);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(isSelected ? 8 : 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ScaleTransition(
              scale: isSelected
                  ? _scaleAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Icon(
                isSelected ? iconFilled : iconOutlined,
                color:
                    isSelected ? AppColors.primary : AppColors.muted(context),
                size: isSelected ? 26 : 22,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? AppColors.primary : AppColors.muted(context),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
