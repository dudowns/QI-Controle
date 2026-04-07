// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/sync_service.dart';
import '../services/loading_service.dart';
import '../widgets/theme_selector.dart';
import '../widgets/backup_modal.dart';
import '../widgets/notificacao_botao.dart';
import '../database/db_helper.dart';
import 'dashboard.dart';
import 'lancamentos.dart';
import 'contas_do_mes_screen.dart' as contas_mes;
import 'investimentos.dart';
import 'renda_fixa_screen.dart';
import 'proventos.dart' as proventos;
import 'metas_screen.dart';
import 'configuracoes_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final GlobalKey<MainScreenState> navigatorKey =
      GlobalKey<MainScreenState>();

  static void navigateTo(int index) {
    navigatorKey.currentState?.mudarTela(index);
  }

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;
  bool _drawerOpen = true;
  late final List<Widget> _screens;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _menuAnimation;

  final SyncService _syncService = SyncService();
  bool _isSyncing = false;
  bool _realtimeConnected = false;
  RealtimeChannel? _realtimeChannel;

  final List<Map<String, dynamic>> _bottomNavItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.receipt, 'label': 'Lançamentos', 'index': 1},
    {'icon': Icons.trending_up, 'label': 'Investimentos', 'index': 3},
    {'icon': Icons.attach_money, 'label': 'Proventos', 'index': 5},
    {'icon': Icons.flag, 'label': 'Metas', 'index': 6},
  ];

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.receipt, 'label': 'Lançamentos', 'index': 1},
    {'icon': Icons.calendar_month, 'label': 'Contas do Mês', 'index': 2},
    {'icon': Icons.trending_up, 'label': 'Investimentos', 'index': 3},
    {'icon': Icons.savings, 'label': 'Renda Fixa', 'index': 4},
    {'icon': Icons.attach_money, 'label': 'Proventos', 'index': 5},
    {'icon': Icons.flag, 'label': 'Metas', 'index': 6},
    {'icon': Icons.settings, 'label': 'Configurações', 'index': 7},
  ];

  final List<Widget> _screensList = [
    const DashboardScreen(),
    const LancamentosScreen(),
    const contas_mes.ContasDoMesScreen(),
    const InvestimentosScreen(),
    const RendaFixaScreen(),
    const proventos.ProventosScreen(),
    const MetasScreen(),
    const ConfiguracoesScreen(),
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
    _menuAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _screens = _screensList;
    _sincronizarDados();
    _initRealtime();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _initRealtime() {
    try {
      final supabase = Supabase.instance.client;
      _realtimeChannel = supabase.channel('public:changes');

      _realtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'lancamentos',
        callback: (payload) {
          if (kDebugMode) debugPrint('🔄 Mudança detectada');
          _onDataChanged();
        },
      );

      _realtimeChannel?.subscribe((status, error) {
        if (!mounted) return;
        setState(() {
          _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
        });
        if (error != null && kDebugMode) {
          debugPrint('❌ Realtime error: $error');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Realtime init error: $e');
    }
  }

  void _onDataChanged() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📡 Dados atualizados!'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sincronizarDados() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await _syncService.syncNow();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Sync error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _forcarSincronizacao() async {
    if (_isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Sincronização já em andamento...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      await _syncService.syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dados sincronizados com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao sincronizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _getTitle() {
    try {
      final item = _menuItems.firstWhere((m) => m['index'] == _currentIndex);
      return item['label'] as String;
    } catch (e) {
      return "FinControl";
    }
  }

  void mudarTela(int index) {
    if (kDebugMode) debugPrint('🔄 mudarTela chamado para índice: $index');

    if (mounted && index >= 0 && index < _screensList.length) {
      setState(() {
        _currentIndex = index;
      });
      if (MediaQuery.of(context).size.width <= 900) {
        Navigator.pop(context);
      }

      if (kDebugMode) debugPrint('✅ Tela alterada para índice: $_currentIndex');
    } else {
      if (kDebugMode) {
        debugPrint(
            '❌ Não foi possível mudar tela. mounted: $mounted, index: $index, length: ${_screensList.length}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isMobile = screenWidth <= 900;

    return Consumer<LoadingService>(
      builder: (context, loadingService, child) {
        return GlobalLoadingOverlay(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.background(context),
            appBar: AppBar(
              leading: isDesktop
                  ? AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _drawerOpen ? Icons.menu_open : Icons.menu,
                            key: ValueKey(_drawerOpen),
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _drawerOpen = !_drawerOpen;
                          });
                          _animationController.forward(from: 0);
                        },
                        tooltip: _drawerOpen ? 'Esconder menu' : 'Mostrar menu',
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: 'Menu',
                    ),
              title: Row(
                children: [
                  FadeInLeft(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (_isSyncing)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_realtimeConnected)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
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
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
              ),
              actions: [
                const NotificacaoBotao(),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_sync, color: Colors.white),
                    onPressed: _forcarSincronizacao,
                    tooltip: 'Sincronizar dados',
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined,
                        color: Colors.white),
                    onPressed: () {
                      BackupModal.show(
                        context: context,
                        onBackupRealizado: () {
                          if (kDebugMode) debugPrint('Backup realizado');
                          _sincronizarDados();
                        },
                      );
                    },
                    tooltip: 'Backup',
                  ),
                ),
                const ThemeSelector(),
              ],
            ),
            drawer: isMobile ? _buildDrawer() : null,
            body: Row(
              children: [
                if (isDesktop)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: _drawerOpen ? 280 : 0,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxWidth: 280,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _drawerOpen ? 1.0 : 0.0,
                          child: _buildDrawer(),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: IndexedStack(
                      key: ValueKey(_currentIndex),
                      index: _currentIndex,
                      children: _screens,
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isMobile
                ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      boxShadow: [
                        if (Theme.of(context).brightness == Brightness.light)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                      ],
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        height: 65,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _bottomNavItems.map((item) {
                            final isSelected = _currentIndex == item['index'];
                            return Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() => _currentIndex = item['index']);
                                  _animationController.forward(from: 0);
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding:
                                          EdgeInsets.all(isSelected ? 6 : 0),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item['icon'],
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.muted(context),
                                        size: isSelected ? 26 : 24,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['label'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.muted(context),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.surface(context),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInLeft(
                    duration: const Duration(milliseconds: 600),
                    child: const Text(
                      'FinControl',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeInLeft(
                    duration: const Duration(milliseconds: 700),
                    child: const Text(
                      'Controle Financeiro',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _currentIndex == item['index'];
                  return FadeInLeft(
                    delay: Duration(milliseconds: 50 * index),
                    duration: const Duration(milliseconds: 400),
                    child: ListTile(
                      leading: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(isSelected ? 6 : 0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item['icon'],
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.muted(context),
                          size: isSelected ? 24 : 22,
                        ),
                      ),
                      title: Text(
                        item['label'],
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary(context),
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      onTap: () {
                        setState(() {
                          _currentIndex = item['index'];
                        });
                        _animationController.forward(from: 0);
                        if (MediaQuery.of(context).size.width <= 900) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Versão 2.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
