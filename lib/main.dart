import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase com suas credenciais
  await Supabase.initialize(
    url: 'https://fmzzuoqqvzomtlpatwye.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZtenp1b3FxdnpvbXRscGF0d3llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI5MTE2NjQsImV4cCI6MjA1ODQ4NzY2NH0.pG9YKXcBqsEWfCxY-mALrW8OwI87mHwgUw7pUJRHzVY',
  );

  // 🔥 Inicializar SyncService para sincronização automática
  SyncService().initialize();

  // Configurar localização para português
  Intl.defaultLocale = 'pt_BR';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle Financeiro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF7B2CBF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B2CBF),
          primary: const Color(0xFF7B2CBF),
          secondary: const Color(0xFF9D4EDD),
        ),
        useMaterial3: true,
        // 🔥 REMOVIDO: fontFamily: 'Poppins' (se não tiver a fonte, mantenha comentado)
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B2CBF),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7B2CBF), width: 2),
          ),
        ),
      ),
      // Configuração de localização
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

      // 🔥 Tela inicial baseada no estado de autenticação
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Enquanto carrega, mostra splash ou loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7B2CBF),
                ),
              ),
            );
          }

          // Verifica se tem usuário logado
          if (snapshot.hasData) {
            final session = snapshot.data?.session;
            if (session != null) {
              // Usuário logado - vai para MainScreen
              return const MainScreen();
            }
          }

          // Usuário não logado - vai para LoginScreen
          return const LoginScreen();
        },
      ),
    );
  }
}
