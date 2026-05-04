// lib/services/sync_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sync_manager.dart';
import 'logger_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SyncManager _syncManager = SyncManager();
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _debounceTimer;
  DateTime? _lastSyncTime;
  StreamSubscription? _connectivitySubscription;
  bool _isConnected = false;
  bool _hasUser = false;

  static const _debounceDelay = Duration(seconds: 2);
  static const _minSyncInterval = Duration(minutes: 1);

  bool get isSyncing => _isSyncing;

  void initialize() {
    if (_isInitialized) {
      LoggerService.info('⚠️ SyncService já inicializado, ignorando...');
      return;
    }
    _isInitialized = true;
    LoggerService.info('🔄 SyncService: Inicializando...');

    _checkUserAndSetup();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected && !_isConnected) {
        LoggerService.info('🌐 Conexão RESTABELECIDA');
        _isConnected = true;
        _debouncedSync();
      } else if (!isConnected && _isConnected) {
        LoggerService.info('📵 Conexão PERDIDA');
        _isConnected = false;
      }
    });

    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.session != null && !_hasUser) {
        LoggerService.info('👤 Usuário logado: ${event.session!.user.email}');
        _hasUser = true;
        _debouncedSync();
      } else if (event.session == null && _hasUser) {
        LoggerService.info('👋 Usuário deslogado');
        _hasUser = false;
      }
    });

    _checkInitialState();
    LoggerService.success('✅ SyncService inicializado com sucesso');
  }

  Future<void> _checkInitialState() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = results.any((r) => r != ConnectivityResult.none);
      final user = Supabase.instance.client.auth.currentUser;
      _hasUser = user != null;
      LoggerService.info(
          '📡 Estado inicial: Conectado=$_isConnected, Logado=$_hasUser');
      if (_isConnected && _hasUser) _debouncedSync();
    } catch (e) {
      LoggerService.error('❌ Erro ao verificar estado inicial: $e');
    }
  }

  void _checkUserAndSetup() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _hasUser = true;
      LoggerService.info('👤 Usuário atual: ${user.email}');
    } else {
      LoggerService.info('⚠️ Nenhum usuário logado no momento');
    }
  }

  void _debouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () => syncNow());
  }

  Future<void> syncNow() async {
    if (!_isConnected) {
      LoggerService.info('📵 Sem conexão, ignorando sync');
      return;
    }
    if (!_hasUser) {
      LoggerService.info('👤 Sem usuário logado, ignorando sync');
      return;
    }
    if (_isSyncing) {
      LoggerService.info('⏳ Sincronização já em andamento, ignorando...');
      return;
    }
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _minSyncInterval) {
      LoggerService.info(
          '⏱️ Throttle: Último sync foi há ${DateTime.now().difference(_lastSyncTime!).inSeconds}s');
      return;
    }

    LoggerService.info('🔄 Iniciando sincronização...');
    _isSyncing = true;
    notifyListeners();

    try {
      await _syncManager.syncAll();
      _lastSyncTime = DateTime.now();
      LoggerService.success(
          '✅ Sincronização concluída em ${DateTime.now().difference(_lastSyncTime!).inSeconds}s');
      notifyListeners();
    } catch (e, stack) {
      LoggerService.error('❌ Erro na sincronização: $e', e);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> markAsPending(String table, int id) async {
    try {
      await _syncManager.markAsPending(table, id);
      LoggerService.info('📝 Marcado como pendente: $table/$id');
    } catch (e) {
      LoggerService.error('❌ Erro ao marcar pendente: $e');
    }
  }

  Future<void> deleteAndSync(String table, int localId, String remoteId) async {
    try {
      await _syncManager.deleteAndSync(table, localId, remoteId);
      LoggerService.info('🗑️ Deletado e sincronizado: $table/$localId');
    } catch (e) {
      LoggerService.error('❌ Erro ao deletar e sincronizar: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
