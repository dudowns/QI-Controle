// lib/services/sync_service.dart
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isConnected =
          results.any((result) => result != ConnectivityResult.none);

      if (isConnected) {
        LoggerService.info('🌐 Conexão detectada, iniciando sincronização...');
        syncNow();
      }
    });

    LoggerService.info('✅ SyncService inicializado');
    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      LoggerService.info('⚠️ Sincronização já em andamento');
      return;
    }

    LoggerService.info('🔄 Sincronização manual solicitada');
    _isSyncing = true;

    try {
      await _syncManager.syncAll();
      notifyListeners(); // 🔥 NOTIFICAR TODOS OS LISTENERS
    } catch (e) {
      LoggerService.error('❌ Erro na sincronização: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> markAsPending(String table, int id) async {
    await _syncManager.markAsPending(table, id);
  }

  Future<void> deleteAndSync(String table, int localId, String remoteId) async {
    await _syncManager.deleteAndSync(table, localId, remoteId);
  }
}
