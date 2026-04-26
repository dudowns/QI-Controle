// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'services/theme_service.dart';
import 'services/sync_service.dart';
import 'services/loading_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
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

  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://fmzzuoqqvzomtlpatwye.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtenp1b3FxdnpvbXRscGF0d3llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MzExNjAsImV4cCI6MjA5MDEwNzE2MH0.6SO5dLvLOSr_-QV3AMYB8aOCe_DLmJ30L_VNFsDz4XM',
  );

  // Configurar locale padrão
  Intl.defaultLocale = 'pt_BR';

  // Inicializar ThemeService
  final themeService = ThemeService();
  await themeService.loadTheme();

  // Inicializar SyncService
  SyncService().initialize();

  runApp(MyApp(themeService: themeService));
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
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Configurar ConfirmDialog com o contexto
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ConfirmDialog.setContext(context);
          });

          // 🔥🔥🔥 SEM LayoutBuilder! SEM ValueKey!
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
            supportedLocales: const [
              Locale('pt', 'BR'),
              Locale('en', 'US'),
            ],
            locale: const Locale('pt', 'BR'),
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
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
              '/notificacoes': (context) => const NotificacoesScreen(),
              '/backup': (context) => const BackupScreen(),
              '/configuracoes': (context) => const ConfiguracoesScreen(),
              '/perfil': (context) => const PerfilScreen(),
            },
            onGenerateRoute: (settings) {
              // Fallback para rotas não encontradas
              return MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
                settings: settings,
              );
            },
          );
        },
      ),
    );
  }
}
