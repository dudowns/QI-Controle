// lib/services/cache_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheEntry {
  final dynamic value;
  final DateTime createdAt;
  final Duration? ttl;

  CacheEntry(this.value, {this.ttl}) : createdAt = DateTime.now();

  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(createdAt) > ttl!;
  }
}

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry> _memoryCache = {};

  // ========== SALVAR ==========

  /// Salva um valor com tempo de expiracao opcional
  Future<void> set(String key, dynamic value, {Duration? ttl}) async {
    _memoryCache[key] = CacheEntry(value, ttl: ttl);

    try {
      final file = await _getCacheFile(key);
      final data = {
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
        'ttl': ttl?.inSeconds,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // Falha ao salvar em disco nao e critico
    }
  }

  // ========== BUSCAR ==========

  /// Busca um valor do cache
  Future<dynamic> get(String key) async {
    // Verificar memoria primeiro
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key]!;
      if (!entry.isExpired) return entry.value;
      _memoryCache.remove(key);
    }

    // Buscar do disco
    try {
      final file = await _getCacheFile(key);
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);

        // Verificar TTL
        final timestamp = DateTime.parse(data['timestamp']);
        final ttlSeconds = data['ttl'] as int?;

        if (ttlSeconds != null) {
          final ttl = Duration(seconds: ttlSeconds);
          if (DateTime.now().difference(timestamp) > ttl) {
            await file.delete();
            return null;
          }
        }

        _memoryCache[key] = CacheEntry(data['value']);
        return data['value'];
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  /// Busca com tipo especifico
  Future<T?> getAs<T>(String key) async {
    final value = await get(key);
    if (value is T) return value;
    return null;
  }

  /// Busca ou computa (se nao existir)
  Future<T> getOrCompute<T>(String key, Future<T> Function() compute,
      {Duration? ttl}) async {
    final cached = await get(key);
    if (cached != null && cached is T) return cached;

    final value = await compute();
    await set(key, value, ttl: ttl);
    return value;
  }

  // ========== VERIFICAR ==========

  /// Verifica se a chave existe e nao expirou
  Future<bool> has(String key) async {
    final value = await get(key);
    return value != null;
  }

  // ========== REMOVER ==========

  /// Remove uma chave do cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final file = await _getCacheFile(key);
      if (await file.exists()) await file.delete();
    } catch (e) {
      // Ignorar erro
    }
  }

  /// Remove multiplas chaves
  Future<void> removeAll(List<String> keys) async {
    for (var key in keys) {
      await remove(key);
    }
  }

  /// Limpa todo o cache
  Future<void> clear() async {
    _memoryCache.clear();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignorar erro
    }
  }

  /// Remove apenas chaves expiradas
  Future<void> clearExpired() async {
    final expiredKeys = <String>[];
    for (var entry in _memoryCache.entries) {
      if (entry.value.isExpired) expiredKeys.add(entry.key);
    }
    for (var key in expiredKeys) {
      await remove(key);
    }
  }

  // ========== INFO ==========

  /// Numero de itens em cache
  int get size => _memoryCache.length;

  /// Todas as chaves em cache
  List<String> get keys => _memoryCache.keys.toList();

  // ========== PRIVADO ==========

  Future<File> _getCacheFile(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return File('${cacheDir.path}/${key.hashCode}.json');
  }
}
