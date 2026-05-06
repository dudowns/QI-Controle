// lib/main.dart
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'services/theme_service.dart';
import 'services/sync_service.dart';
import 'services/loading_service.dart';
import 'services/logger_service.dart';
import 'database/db_helper.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/verify_otp_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/dashboard.dart';
import 'screens/lancamentos.dart';
import 'screens/investimentos.dart';
import 'screens/metas_screen.dart';
import 'screens/proventos.dart';
import 'screens/renda_fixa_screen.dart';
import 'screens/contas_do_mes_screen.dart';
import 'screens/transacoes_screen.dart';
import 'screens/notificacoes_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/configuracoes_screen.dart';
import 'screens/perfil_screen.dart';
import 'widgets/confirm_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Captura erros globais
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
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtenp1b3FxdnpvbXRscGF0d3llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MzExNjAsImV4cCI6MjA5MDEwNzE2MH0.6SO5dLvLOSr_-QV3AMYB8aOCe_DLmJ30L_VNFsDz4XM',
    );
    LoggerService.success('✅ Supabase inicializado');

    Intl.defaultLocale = 'pt_BR';

    // Inicializar banco ANTES de tudo
    LoggerService.info('🗄️ Inicializando banco de dados...');
    final dbHelper = DBHelper();
    await dbHelper.database;
    LoggerService.success('✅ Banco de dados pronto');

    // Otimizar banco
    await dbHelper.otimizarBanco();
    LoggerService.success('✅ Banco otimizado');

    final themeService = ThemeService();
    await themeService.loadTheme();

    // Inicializar SyncService DEPOIS do DB
    LoggerService.info('🔄 Inicializando SyncService...');
    SyncService().initialize();
    LoggerService.success('✅ SyncService inicializado');

    runApp(MyApp(themeService: themeService));
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
  final ThemeService themeService;
  const MyApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider(create: (_) => LoadingService()),
        ChangeNotifierProvider(create: (_) => SyncService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ConfirmDialog.setContext(context);
          });

          return MaterialApp(
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
              '/splash': (context) => const SplashScreen(),
              '/profiles': (context) => const ProfilesScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/verify-otp': (context) => const VerifyOtpScreen(email: ''),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/main': (context) => const MainScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/lancamentos': (context) => const LancamentosScreen(),
              '/investimentos': (context) => const InvestimentosScreen(),
              '/metas': (context) => const MetasScreen(),
              '/proventos': (context) => const ProventosScreen(),
              '/renda-fixa': (context) => const RendaFixaScreen(),
              '/transacoes': (context) => const TransacoesScreen(),
              '/contas': (context) => const ContasDoMesScreen(),
              '/notificacoes': (context) => NotificacoesScreen(),
              '/backup': (context) => const BackupScreen(),
              '/configuracoes': (context) => const ConfiguracoesScreen(),
              '/perfil': (context) => const PerfilScreen(),
            },
          );
        },
      ),
    );
  }
}
