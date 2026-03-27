import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_manager.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final SyncManager _syncManager = SyncManager();
  final Connectivity _connectivity = Connectivity();

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Escutar mudanças de conectividade
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isConnected =
          results.any((result) => result != ConnectivityResult.none);

      if (isConnected) {
        debugPrint('🌐 Conexão detectada, iniciando sincronização...');
        _syncManager.syncAll();
      }
    });

    debugPrint('✅ SyncService inicializado');

    // Sincroniza imediatamente ao iniciar
    syncNow();
  }

  Future<void> syncNow() async {
    debugPrint('🔄 Sincronização manual solicitada');
    final results = await _connectivity.checkConnectivity();
    final isConnected =
        results.any((result) => result != ConnectivityResult.none);

    if (isConnected) {
      await _syncManager.syncAll();
    } else {
      debugPrint('⚠️ Sem conexão, sincronização será feita quando online');
    }
  }

  Future<void> markAsPending(String table, int id) async {
    await _syncManager.markAsPending(table, id);
  }

  Future<void> deleteAndSync(String table, int localId, String remoteId) async {
    await _syncManager.deleteAndSync(table, localId, remoteId);
  }
}
