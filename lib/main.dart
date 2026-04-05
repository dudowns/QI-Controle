// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/lancamentos.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/loading_service.dart';
import 'services/supabase_service.dart';
import 'screens/investimentos.dart';
import 'screens/metas_screen.dart';
import 'screens/dashboard.dart';
import 'screens/proventos.dart';
import 'screens/renda_fixa_screen.dart';
import 'screens/transacoes_screen.dart';
import 'screens/contas_do_mes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://fmzzuoqqvzomtlpatwye.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtenp1b3FxdnpvbXRscGF0d3llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MzExNjAsImV4cCI6MjA5MDEwNzE2MH0.6SO5dLvLOSr_-QV3AMYB8aOCe_DLmJ30L_VNFsDz4XM',
  );

  Intl.defaultLocale = 'pt_BR';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()..loadTheme()),
        ChangeNotifierProvider(create: (_) => LoadingService()),
        Provider<SupabaseService>(create: (_) => SupabaseService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Controle Financeiro',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
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
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/main': (context) => MainScreen(key: MainScreen.navigatorKey),
              '/lancamentos': (context) => const LancamentosScreen(),
              '/investimentos': (context) => const InvestimentosScreen(),
              '/metas': (context) => const MetasScreen(),
              '/dashboard': (context) => const DashboardScreen(),
              '/proventos': (context) => const ProventosScreen(),
              '/renda-fixa': (context) => const RendaFixaScreen(),
              '/transacoes': (context) => const TransacoesScreen(),
              '/contas': (context) => const ContasDoMesScreen(),
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF7B2CBF),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF7B2CBF),
        secondary: Color(0xFF9D4EDD),
        surface: Colors.white,
        error: Color(0xFFC62828),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF7B2CBF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF9D4EDD),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9D4EDD),
        secondary: Color(0xFF7B2CBF),
        surface: Color(0xFF1E1E1E),
        error: Color(0xFFEF5350),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9D4EDD),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
