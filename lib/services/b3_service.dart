// lib/services/b3_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'logger_service.dart';

class B3Service {
  static final B3Service _instance = B3Service._internal();
  factory B3Service() => _instance;
  B3Service._internal();

  static final Map<String, Map<String, dynamic>> _cache = {};
  static const Duration _cacheValidity = Duration(minutes: 5);

  Future<Map<String, dynamic>?> getCotacao(String ticker) async {
    if (_cache.containsKey(ticker)) {
      final cached = _cache[ticker]!;
      final cacheTime = DateTime.parse(cached['timestamp']);
      if (DateTime.now().difference(cacheTime) < _cacheValidity) {
        return cached;
      }
    }

    try {
      final tickerLimpo = ticker.trim().toUpperCase();
      final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$tickerLimpo.SA');

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['chart']['result'] != null &&
            data['chart']['result'].isNotEmpty) {
          final result = data['chart']['result'][0];
          final meta = result['meta'];

          final cotacao = {
            'ticker': tickerLimpo,
            'preco': meta['regularMarketPrice']?.toDouble() ?? 0.0,
            'variacao_percentual':
                meta['regularMarketChangePercent']?.toDouble() ?? 0.0,
            'nome': meta['longName'] ?? tickerLimpo,
            'timestamp': DateTime.now().toIso8601String(),
          };

          _cache[tickerLimpo] = cotacao;
          LoggerService.success('✅ $tickerLimpo: R\$ ${cotacao['preco']}');
          return cotacao;
        }
      }
    } catch (e) {
      LoggerService.error('❌ Erro ao buscar $ticker: $e');
    }
    return null;
  }

  Future<Map<String, Map<String, dynamic>>> getCotacoesEmLote(
      List<String> tickers) async {
    final resultados = <String, Map<String, dynamic>>{};
    for (var ticker in tickers) {
      final cotacao = await getCotacao(ticker);
      if (cotacao != null) resultados[ticker] = cotacao;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return resultados;
  }

  void limparCache() => _cache.clear();
}
