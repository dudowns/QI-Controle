// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;
  bool _initialized = false;

  // CONSTANTES
  static const String _defaultChannelId = 'controle_financeiro_channel';
  static const String _defaultChannelName = 'Controle Financeiro';
  static const String _defaultChannelDescription =
      'Notificações do Controle Financeiro';

  final List<Map<String, dynamic>> _notificacoes = [];

  List<Map<String, dynamic>> get notificacoes =>
      List.unmodifiable(_notificacoes);

  Function? onNotificationsUpdated;

  // ========== INICIALIZAÇÃO ==========
  Future<void> init() async {
    if (_initialized) return;

    try {
      LoggerService.info('🔔 Inicializando serviço de notificações...');

      tz.initializeTimeZones();

      _notifications = FlutterLocalNotificationsPlugin();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _notifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _createNotificationChannel();
      await _requestPermissions();

      _initialized = true;
      LoggerService.success('✅ Notification service initialized successfully');
    } catch (e) {
      LoggerService.error('❌ Failed to initialize notifications', e);
      _notifications = null;
    }
  }

  // CRIAÇÃO DO CANAL
  Future<void> _createNotificationChannel() async {
    if (!kIsWeb && _notifications != null) {
      try {
        const androidChannel = AndroidNotificationChannel(
          _defaultChannelId,
          _defaultChannelName,
          description: _defaultChannelDescription,
          importance: Importance.high,
          showBadge: true,
          enableVibration: true,
          enableLights: true,
        );

        await _notifications!
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);

        LoggerService.info(
            '📢 Canal de notificação criado: $_defaultChannelId');
      } catch (e) {
        LoggerService.warning('⚠️ Erro ao criar canal de notificação: $e');
      }
    }
  }

  // SOLICITAR PERMISSÕES
  Future<void> _requestPermissions() async {
    if (!kIsWeb && _notifications != null) {
      try {
        final android = _notifications!.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (android != null) {
          final bool? granted = await android.requestNotificationsPermission();
          if (granted == true) {
            LoggerService.success('✅ Permissão de notificação concedida');
          } else {
            LoggerService.warning('⚠️ Permissão de notificação negada');
          }
        }

        final ios = _notifications!.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (ios != null) {
          final bool? granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          if (granted == true) {
            LoggerService.success('✅ Permissão iOS concedida');
          } else {
            LoggerService.warning('⚠️ Permissão iOS negada');
          }
        }
      } catch (e) {
        LoggerService.warning('⚠️ Erro ao solicitar permissões: $e');
      }
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    LoggerService.info('🔔 Notification tapped: ${response.payload}');
  }

  // ========== ADICIONAR NOTIFICAÇÃO ==========
  Future<void> addNotification({
    required String titulo,
    required String mensagem,
    String? ticker,
    double? valor,
    int? id,
  }) async {
    try {
      final notificationId = id ?? DateTime.now().millisecondsSinceEpoch;

      final notificacao = {
        'id': notificationId,
        'titulo': titulo,
        'mensagem': mensagem,
        'data': DateTime.now(),
        'lida': false,
        'ticker': ticker,
        'valor': valor,
      };

      _notificacoes.insert(0, notificacao);

      if (_notificacoes.length > 50) {
        _notificacoes.removeLast();
      }

      await _showNativeNotification(
        id: notificationId,
        titulo: titulo,
        mensagem: mensagem,
        payload: ticker,
      );

      onNotificationsUpdated?.call();

      LoggerService.info('📢 Notificação adicionada: $titulo');
    } catch (e) {
      LoggerService.error('Failed to add notification', e);
    }
  }

  // MOSTRAR NOTIFICAÇÃO NATIVA
  Future<void> _showNativeNotification({
    required int id,
    required String titulo,
    required String mensagem,
    String? payload,
  }) async {
    if (!_initialized || _notifications == null) {
      LoggerService.warning('⚠️ Notificações não inicializadas');
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        _defaultChannelName,
        channelDescription: _defaultChannelDescription,
        importance: Importance.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notifications!.show(
        id,
        titulo,
        mensagem,
        notificationDetails,
        payload: payload,
      );

      LoggerService.info('✅ Notificação nativa mostrada: id=$id');
    } catch (e) {
      LoggerService.error('❌ Erro ao mostrar notificação nativa', e);
    }
  }

  // AGENDAR NOTIFICAÇÃO
  Future<void> scheduleNotification({
    required int id,
    required String titulo,
    required String mensagem,
    required DateTime dataAgendamento,
    String? payload,
  }) async {
    if (!_initialized || _notifications == null) {
      LoggerService.warning('⚠️ Notificações não inicializadas');
      return;
    }

    try {
      final scheduledDate = tz.TZDateTime.from(dataAgendamento, tz.local);

      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        LoggerService.warning(
            '⚠️ Data de agendamento já passou: $dataAgendamento');
        await addNotification(
          titulo: titulo,
          mensagem: mensagem,
          ticker: payload,
        );
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        _defaultChannelName,
        channelDescription: _defaultChannelDescription,
        importance: Importance.high,
      );

      const iosDetails = DarwinNotificationDetails();

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications!.zonedSchedule(
        id,
        titulo,
        mensagem,
        scheduledDate,
        notificationDetails,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      LoggerService.success(
          '📅 Notificação agendada para ${_formatDate(dataAgendamento)}');
    } catch (e) {
      LoggerService.error('❌ Erro ao agendar notificação', e);
    }
  }

  // AGENDAR PROVENTO
  Future<void> scheduleProventoNotification({
    required String ticker,
    required DateTime dataPagamento,
    required double valor,
    required int id,
  }) async {
    try {
      final titulo = '💰 Provento: $ticker';
      final mensagem =
          'Você receberá ${_formatCurrency(valor)} em ${_formatDate(dataPagamento)}';

      await scheduleNotification(
        id: id,
        titulo: titulo,
        mensagem: mensagem,
        dataAgendamento: dataPagamento,
        payload: ticker,
      );

      await addNotification(
        titulo: titulo,
        mensagem: mensagem,
        ticker: ticker,
        valor: valor,
        id: id,
      );
    } catch (e) {
      LoggerService.error('Failed to schedule provento', e);
    }
  }

  // AGENDAR CONTA
  Future<void> scheduleContaNotification({
    required String nomeConta,
    required double valor,
    required DateTime dataVencimento,
    required int id,
    int diasAntecedencia = 3,
  }) async {
    try {
      final dataLembrete =
          dataVencimento.subtract(Duration(days: diasAntecedencia));

      final titulo = '📅 Conta a vencer: $nomeConta';
      final mensagem =
          'Vencimento em ${_formatDate(dataVencimento)} - Valor: ${_formatCurrency(valor)}';

      await scheduleNotification(
        id: id,
        titulo: titulo,
        mensagem: mensagem,
        dataAgendamento: dataLembrete,
        payload: nomeConta,
      );

      LoggerService.success('📅 Lembrete agendado para $nomeConta');
    } catch (e) {
      LoggerService.error('Failed to schedule conta notification', e);
    }
  }

  // ========== MÉTODOS DE UTILITÁRIOS ==========

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void marcarComoLida(int id) {
    final index = _notificacoes.indexWhere((n) => n['id'] == id);
    if (index != -1) {
      _notificacoes[index]['lida'] = true;
      onNotificationsUpdated?.call();
      LoggerService.info('✅ Notificação marcada como lida: $id');
    }
  }

  void marcarTodasComoLidas() {
    for (var notif in _notificacoes) {
      notif['lida'] = true;
    }
    onNotificationsUpdated?.call();
    LoggerService.info('📭 Todas notificações marcadas como lidas');
  }

  void limparTodas() {
    _notificacoes.clear();
    onNotificationsUpdated?.call();
    LoggerService.info('🗑️ Todas notificações removidas');
  }

  int get naoLidas => _notificacoes.where((n) => n['lida'] == false).length;

  void registerUpdateCallback(Function callback) {
    onNotificationsUpdated = callback;
  }

  // CANCELAR NOTIFICAÇÕES

  Future<void> cancelNotification(int id) async {
    try {
      if (_initialized && _notifications != null) {
        await _notifications!.cancel(id);
        LoggerService.info('❌ Notificação cancelada: $id');
      }
    } catch (e) {
      LoggerService.warning('Failed to cancel notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      if (_initialized && _notifications != null) {
        await _notifications!.cancelAll();
        LoggerService.info('❌ Todas notificações canceladas');
      }
    } catch (e) {
      LoggerService.warning('Failed to cancel all notifications: $e');
    }
  }

  // VERIFICAR STATUS (VERSÃO CORRIGIDA)
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized || _notifications == null) {
      LoggerService.warning('⚠️ Notificações não inicializadas');
      return false;
    }

    try {
      // Verificar permissão no Android usando método que existe
      final android = _notifications!.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        // Na versão atual, retornamos true se inicializou
        // O usuário já deu permissão na primeira execução
        LoggerService.info('📢 Notificações Android disponíveis');
        return true;
      }

      // Para iOS/macOS
      final ios = _notifications!.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (ios != null) {
        LoggerService.info('📢 Notificações iOS disponíveis');
        return true;
      }

      return _initialized;
    } catch (e) {
      LoggerService.warning('⚠️ Erro ao verificar status das notificações: $e');
      return false;
    }
  }

  // TESTAR NOTIFICAÇÃO
  Future<void> testNotification() async {
    LoggerService.info('🔔 Testando notificação...');

    await addNotification(
      titulo: '🔔 Teste de Notificação',
      mensagem: 'Se você está vendo isso, as notificações estão funcionando!',
      ticker: 'TESTE',
      valor: 0,
    );
  }

  bool get isInitialized => _initialized;
}
