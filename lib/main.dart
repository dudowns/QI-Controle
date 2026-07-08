// lib/main.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

// ✅ SERVICES
import 'services/theme_service.dart';
import 'services/sync_service.dart';
import 'services/loading_service.dart';
import 'services/logger_service.dart';
import 'services/notification_service.dart';
import 'services/sync_service_improved.dart';

// ✅ DATABASE
import 'database/db_helper.dart';

// ✅ PROVIDERS
import 'providers/layout_provider.dart';

// ✅ WIDGETS
import 'widgets/confirm_dialog.dart';

// ✅ SCREENS (IMPORT DO BARREL PRINCIPAL)
import 'screens/screens.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    LoggerService.error(
        '🔥 Erro global Flutter: ${details.exception}', details.exception);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.error('🔥 Erro fatal: $error', error);
    return true;
  };

  try {
    LoggerService.info('🚀 Inicializando Supabase...');
    await Supabase.initialize(
      url: 'https://fmzzuoqqvzomtlpatwye.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtenp1b3FxdnpvbXRscGF0d3llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MzExNjAsImV4cCI6MjA5MDEwNzE2MH0.6SO5dLvLOSr_-QV3AMYB8aOCe_DLmJ30L_VNFsDz4XM',
    );
    LoggerService.success('✅ Supabase inicializado');

    Intl.defaultLocale = 'pt_BR';

    final bool isWeb = identical(0, 0.0) ? true : false;

    if (isWeb) {
      LoggerService.info('🌐 Modo Web detectado. Usando apenas Supabase.');
    } else {
      LoggerService.info('🗄️ Inicializando banco de dados...');
      final dbHelper = DBHelper();
      await dbHelper.database;
      LoggerService.success('✅ Banco de dados pronto');
      await dbHelper.otimizarBanco();
      LoggerService.success('✅ Banco otimizado');
    }

    final themeService = ThemeService();
    await themeService.loadTheme();

    LoggerService.info('🔄 Inicializando SyncService...');
    final syncService = SyncService();
    syncService.initialize();

    // ✅ NOVO: Serviço de sincronização melhorado
    final syncImproved = SyncServiceImproved();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (Supabase.instance.client.auth.currentUser != null) {
        LoggerService.info('🔄 Executando sincronização inicial completa...');
        await syncImproved.syncAllData(force: true);
        LoggerService.success('✅ Sincronização inicial concluída!');
      }
    });

    LoggerService.success('✅ SyncService inicializado com segurança');

    LoggerService.info('🔔 Inicializando NotificationService...');
    await NotificationService().init();
    LoggerService.success('✅ NotificationService inicializado');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeService),
          ChangeNotifierProvider(create: (_) => LoadingService()),
          ChangeNotifierProvider(create: (_) => SyncService()),
          ChangeNotifierProvider(create: (_) => LayoutProvider()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e) {
    LoggerService.error('❌ Erro fatal na inicialização: $e', e);
    runApp(ErrorApp(error: e.toString()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                const Text('Erro de Inicialização',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'QI Controle',
          debugShowCheckedModeBanner: false,
          theme: themeService.getLightTheme(),
          darkTheme: themeService.getDarkTheme(),
          themeMode: themeService.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR'), Locale('en', 'US')],
          locale: const Locale('pt', 'BR'),
          initialRoute: '/splash',
          routes: {
            // ✅ SHARED SCREENS
            '/splash': (context) => const SplashScreen(),
            '/profiles': (context) => const ProfilesScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/verify-otp': (context) => const VerifyOtpScreen(email: ''),
            '/reset-password': (context) => const ResetPasswordScreen(),
            '/main': (context) => const MainScreen(),

            // ✅ DESKTOP & MOBILE SCREENS (usando o barrel)
            '/dashboard': (context) => const DashboardScreen(),
            '/lancamentos': (context) => const LancamentosScreen(),
            '/investimentos': (context) => const InvestimentosScreen(),
            '/metas': (context) => const MetasScreen(),
            '/proventos': (context) => const ProventosScreen(),
            '/renda-fixa': (context) => const RendaFixaScreen(),
            '/transacoes': (context) => const TransacoesScreen(),
            '/contas': (context) => const ContasDoMesScreen(),
            '/notificacoes': (context) => const NotificacoesScreen(),
            '/backup': (context) => const BackupScreen(),
            '/configuracoes': (context) => const ConfiguracoesScreen(),
            '/perfil': (context) => const PerfilScreen(),
            '/debug-sync': (context) => const DebugSyncScreen(),
          },
        );
      },
    );
  }
}
