// lib/constants/app_pages.dart

import 'package:flutter/material.dart';
import '../screens/dashboard.dart';
import '../screens/lancamentos.dart';
import '../screens/nova_transacao.dart';
import '../screens/investimentos.dart';
import '../screens/metas_screen.dart';
import '../screens/contas_do_mes_screen.dart';
import '../screens/backup_screen.dart';
import '../screens/notificacoes_screen.dart';
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
    // 🔥 REMOVIDA A LINHA DUPLICADA
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

