// lib/constants/app_pages.dart

import 'package:flutter/material.dart';

// ✅ USANDO O BARREL DE TELAS
import '../screens/screens.dart';

// ✅ OU IMPORTS DIRETOS (se preferir)
// import '../screens/shared/dashboard.dart';
// import '../screens/shared/lancamentos.dart';
import '../screens/shared/nova_transacao.dart';
// import '../screens/shared/investimentos.dart';
// import '../screens/shared/metas_screen.dart';
// import '../screens/shared/contas_do_mes_screen.dart';
// import '../screens/shared/backup_screen.dart';
// import '../screens/shared/notificacoes_screen.dart';

import 'app_routes.dart';

class AppPages {
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.home: (context) => const DashboardScreen(),
    AppRoutes.dashboard: (context) => const DashboardScreen(),
    AppRoutes.lancamentos: (context) => const LancamentosScreen(),
    AppRoutes.novaTransacao: (context) => const NovaTransacaoScreen(),
    AppRoutes.investimentos: (context) => const InvestimentosScreen(),
    AppRoutes.metas: (context) => const MetasScreen(),
    AppRoutes.contas: (context) => const ContasDoMesScreen(),
    AppRoutes.backup: (context) => const BackupScreen(),
    AppRoutes.notificacoes: (context) => const NotificacoesScreen(),
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.novaTransacao:
        return MaterialPageRoute(
          builder: (_) => const NovaTransacaoScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
          settings: settings,
        );
    }
  }
}
