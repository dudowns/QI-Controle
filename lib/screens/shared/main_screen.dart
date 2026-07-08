// lib/screens/shared/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_colors.dart';
import '../../services/sync_service.dart';
import '../../services/loading_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/theme_selector.dart';
import '../../widgets/backup_modal.dart';
import '../../widgets/notificacao_botao.dart';
import '../../widgets/layout_selector.dart';
import '../../providers/layout_provider.dart';

// ✅ IMPORTS DAS VERSÕES DESKTOP
import '../desktop/dashboard.dart';
import '../desktop/lancamentos.dart';
import '../desktop/contas_do_mes_screen.dart';
import '../desktop/investimentos.dart';
import '../desktop/renda_fixa_screen.dart';
import '../desktop/proventos.dart';
import '../desktop/metas_screen.dart';
import '../shared/configuracoes_screen.dart';

// ✅ IMPORTS DAS VERSÕES MOBILE
import '../mobile/dashboard_mobile.dart';
import '../mobile/lancamentos_mobile.dart';
import '../mobile/contas_do_mes_mobile.dart';
import '../mobile/investimentos_mobile.dart';
import '../mobile/renda_fixa_mobile.dart';
import '../mobile/proventos_mobile.dart';
import '../mobile/metas_mobile.dart';
import '../mobile/configuracoes_mobile.dart';

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
  late final List<Widget> _screens;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  final SyncService _syncService = SyncService();
  final AuthService _auth = AuthService();
  bool _isSyncing = false;
  bool _realtimeConnected = false;
  RealtimeChannel? _realtimeChannel;

  Map<String, dynamic>? _perfil;
  int _avatarVersion = 0;

  // ✅ BOTTOM NAVIGATION (5 ITENS PRINCIPAIS)
  final List<Map<String, dynamic>> _bottomNavItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.receipt_long_rounded, 'label': 'Lançamentos', 'index': 1},
    {'icon': Icons.trending_up_rounded, 'label': 'Investimentos', 'index': 3},
    {'icon': Icons.payments_rounded, 'label': 'Proventos', 'index': 5},
    {'icon': Icons.flag_rounded, 'label': 'Metas', 'index': 6},
  ];

  // ✅ MENU LATERAL (8 ITENS - TODAS AS TELAS)
  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'index': 0},
    {'icon': Icons.receipt_long_rounded, 'label': 'Lançamentos', 'index': 1},
    {
      'icon': Icons.calendar_month_rounded,
      'label': 'Contas do Mês',
      'index': 2
    },
    {'icon': Icons.trending_up_rounded, 'label': 'Investimentos', 'index': 3},
    {'icon': Icons.savings_rounded, 'label': 'Renda Fixa', 'index': 4},
    {'icon': Icons.payments_rounded, 'label': 'Proventos', 'index': 5},
    {'icon': Icons.flag_rounded, 'label': 'Metas', 'index': 6},
    {'icon': Icons.settings_rounded, 'label': 'Configurações', 'index': 7},
  ];

  // ✅ LISTA DE TELAS COM VERSÕES RESPONSIVAS
  late final List<Widget> _screensList = [
    // Dashboard
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const DashboardMobileScreen()
            : const DashboardScreen();
      },
    ),
    // Lançamentos
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const LancamentosMobileScreen()
            : const LancamentosScreen();
      },
    ),
    // Contas do Mês
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const ContasDoMesMobileScreen()
            : const ContasDoMesScreen();
      },
    ),
    // Investimentos
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const InvestimentosMobileScreen()
            : const InvestimentosScreen();
      },
    ),
    // Renda Fixa
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const RendaFixaMobileScreen()
            : const RendaFixaScreen();
      },
    ),
    // Proventos
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const ProventosMobileScreen()
            : const ProventosScreen();
      },
    ),
    // Metas
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const MetasMobileScreen()
            : const MetasScreen();
      },
    ),
    // Configurações
    Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        return layoutProvider.isMobile
            ? const ConfiguracoesMobileScreen()
            : const ConfiguracoesScreen();
      },
    ),
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

    _screens = _screensList;
    _carregarPerfil();
    _sincronizarDados();
    _initRealtime();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ========== MÉTODOS ==========

  Future<void> _carregarPerfil() async {
    try {
      final perfil = await _auth.getPerfil();
      if (mounted) {
        setState(() {
          _perfil = perfil;
          _avatarVersion++;
        });
      }
    } catch (e) {}
  }

  void _initRealtime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        });
      } catch (e) {
        if (kDebugMode) debugPrint('❌ Realtime init error: $e');
      }
    });
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
      await _syncService.forceSyncNow();
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
      return "QI Controle";
    }
  }

  void _navegarPara(int index) {
    if (mounted && index >= 0 && index < _screensList.length) {
      setState(() => _currentIndex = index);
      _carregarPerfil();
      if (MediaQuery.of(context).size.width <= 900) {
        Navigator.pop(context);
      }
    }
  }

  void mudarTela(int index) => _navegarPara(index);

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Consumer<LayoutProvider>(
      builder: (context, layoutProvider, child) {
        final isMobile = layoutProvider.isMobile;
        final isDesktop = layoutProvider.isDesktop;

        final width = MediaQuery.of(context).size.width;
        layoutProvider.updateScreenSize(width);

        return Consumer<LoadingService>(
          builder: (context, loadingService, child) {
            return GlobalLoadingOverlay(
              child: Scaffold(
                key: _scaffoldKey,
                backgroundColor: AppColors.background(context),
                appBar: _buildAppBar(context, isMobile, isDesktop),
                drawer: isMobile ? _buildDrawer(context) : null,
                body: Row(
                  children: [
                    if (isDesktop) _buildSideMenu(context),
                    Expanded(
                      child: _screens[_currentIndex],
                    ),
                  ],
                ),
                bottomNavigationBar:
                    isMobile ? _buildBottomNavigationBar(context) : null,
              ),
            );
          },
        );
      },
    );
  }

  // ========== APP BAR ==========

  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isMobile, bool isDesktop) {
    return AppBar(
      leading: isDesktop
          ? IconButton(
              icon: const Icon(Icons.menu_open, color: Colors.white),
              onPressed: () => _navegarPara(0),
              tooltip: 'Ir para Dashboard',
            )
          : IconButton(
              icon: const Icon(Icons.menu_rounded),
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
                color: Colors.white,
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
        const LayoutSelector(),
        const SizedBox(width: 4),
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
            icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
            onPressed: () {
              BackupModal.show(
                context: context,
                onBackupRealizado: () => _sincronizarDados(),
              );
            },
            tooltip: 'Backup',
          ),
        ),
        const ThemeSelector(),
      ],
    );
  }

  // ========== BOTTOM NAVIGATION BAR (MOBILE - 5 ITENS) ==========

  Widget _buildBottomNavigationBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
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
                    _carregarPerfil();
                    _animationController.forward(from: 0);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(isSelected ? 6 : 0),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item['icon'],
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.grey[600] : Colors.grey[400]),
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
                              : (isDark ? Colors.grey[600] : Colors.grey[400]),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
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
    );
  }

  // ========== DRAWER (MOBILE - 8 ITENS COMPLETOS) ==========

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Container(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        child: Column(
          children: [
            // CABEÇALHO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.primaryLight
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'QI Controle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seu gerenciador financeiro',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            // LISTA DE ITENS (8 TELAS COMPLETAS)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _currentIndex == item['index'];
                  return FadeInLeft(
                    delay: Duration(milliseconds: 30 * index),
                    duration: const Duration(milliseconds: 300),
                    child: _buildMenuItem(
                      icon: item['icon'] as IconData,
                      label: item['label'] as String,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _currentIndex = item['index'] as int);
                        _carregarPerfil();
                        _animationController.forward(from: 0);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),

            // PERFIL DO USUÁRIO
            _buildUserProfile(context),
          ],
        ),
      ),
    );
  }

  // ========== SIDE MENU (DESKTOP - 8 ITENS) ==========

  Widget _buildSideMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 230,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                  AppColors.primaryLight
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'QI Controle',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = _currentIndex == item['index'];
                return _buildMenuItem(
                  icon: item['icon'] as IconData,
                  label: item['label'] as String,
                  isSelected: isSelected,
                  onTap: () => _navegarPara(item['index'] as int),
                );
              },
            ),
          ),
          _buildUserProfile(context),
        ],
      ),
    );
  }

  // ========== MENU ITEM ==========

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== USER PROFILE ==========

  Widget _buildUserProfile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withValues(alpha: 0.1),
              image: _perfil?['avatar_url'] != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                        '${_perfil!['avatar_url']}?v=$_avatarVersion',
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _perfil?['avatar_url'] == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 22)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _perfil?['nome'] ?? _perfil?['username'] ?? 'Usuário',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'v2.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
