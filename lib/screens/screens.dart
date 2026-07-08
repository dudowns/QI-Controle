// lib/screens/screens.dart

// ========== SHARED SCREENS ==========
export 'shared/splash_screen.dart';
export 'shared/login_screen.dart';
export 'shared/profiles_screen.dart';
export 'shared/register_screen.dart';
export 'shared/forgot_password_screen.dart';
export 'shared/verify_otp_screen.dart';
export 'shared/reset_password_screen.dart';
export 'shared/main_screen.dart';
export 'shared/backup_screen.dart';
export 'shared/configuracoes_screen.dart';
export 'shared/perfil_screen.dart';
export 'shared/transacoes_screen.dart';
export 'shared/notificacoes_screen.dart';
export 'shared/debug_sync_screen.dart';

// ========== DESKTOP SCREENS ==========
export 'desktop/dashboard.dart';
export 'desktop/lancamentos.dart';
export 'desktop/contas_do_mes_screen.dart';
export 'desktop/investimentos.dart';
export 'desktop/renda_fixa_screen.dart';
export 'desktop/proventos.dart'; // ✅ Provento do Desktop
export 'desktop/metas_screen.dart';

// ========== MOBILE SCREENS ==========
export 'mobile/dashboard_mobile.dart';
export 'mobile/lancamentos_mobile.dart';
export 'mobile/contas_do_mes_mobile.dart';
export 'mobile/investimentos_mobile.dart';
export 'mobile/renda_fixa_mobile.dart';
export 'mobile/proventos_mobile.dart'
    hide Provento; // ✅ OCULTA O Provento DO MOBILE
export 'mobile/metas_mobile.dart';
export 'mobile/configuracoes_mobile.dart';
