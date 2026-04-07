import '../services/logger_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/performance_service.dart';

class CachePrice {
  final double price;
  final DateTime timestamp;

  CachePrice(this.price, this.timestamp);

  bool get isValid =>
      DateTime.now().difference(timestamp) < const Duration(minutes: 5);
}

class YahooFinanceService {
  static final YahooFinanceService _instance = YahooFinanceService._internal();
  factory YahooFinanceService() => _instance;
  YahooFinanceService._internal();

  static final Map<String, CachePrice> _priceCache = {};
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 15);

  Future<double?> getPrecoAtual(String ticker) async {
    PerformanceService.start('yahoo_getPreco_$ticker');

    final tickerLimpo = ticker.trim().toUpperCase().replaceAll('.SA', '');

    LoggerService.info('🔍 Buscando preço para $tickerLimpo');

    // Verificar cache
    if (_priceCache.containsKey(tickerLimpo) &&
        _priceCache[tickerLimpo]!.isValid) {
      PerformanceService.stop('yahoo_getPreco_$ticker (cache)');
      return _priceCache[tickerLimpo]!.price;
    }

    for (int tentativa = 1; tentativa <= _maxRetries; tentativa++) {
      try {
        final url = Uri.parse(
            'https://query1.finance.yahoo.com/v8/finance/chart/$tickerLimpo.SA');

        final response = await http.get(url).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['chart']['result'] != null &&
              data['chart']['result'].isNotEmpty) {
            final result = data['chart']['result'][0];
            final meta = result['meta'];

            double? preco = meta['regularMarketPrice']?.toDouble();

            if (preco == null || preco <= 0) {
              final indicators = result['indicators'];
              if (indicators != null && indicators['quote'] != null) {
                final quote = indicators['quote'][0];
                if (quote['close'] != null && quote['close'].isNotEmpty) {
                  preco = quote['close'].last?.toDouble();
                }
              }
            }

            if (preco == null || preco <= 0) {
              preco = meta['previousClose']?.toDouble();
            }

            if (preco != null && preco > 0) {
              _priceCache[tickerLimpo] = CachePrice(preco, DateTime.now());
              LoggerService.success(
                  '✅ $tickerLimpo: R\$ ${preco.toStringAsFixed(2)}');
              PerformanceService.stop('yahoo_getPreco_$ticker');
              return preco;
            }
          }
        }

        if (tentativa < _maxRetries) {
          await Future.delayed(Duration(seconds: tentativa));
        }
      } catch (e) {
        LoggerService.error(
            'Erro na tentativa $tentativa para $tickerLimpo', e);
        if (tentativa < _maxRetries) {
          await Future.delayed(Duration(seconds: tentativa));
        }
      }
    }

    LoggerService.error('❌ Falha ao obter preço para $tickerLimpo');
    PerformanceService.stop('yahoo_getPreco_$ticker (falha)');
    return null;
  }

  void limparCache() {
    final quantidade = _priceCache.length;
    _priceCache.clear();
    LoggerService.info('🗑️ Cache limpo: $quantidade itens removidos');
  }

  void removerDoCache(String ticker) {
    final tickerLimpo = ticker.trim().toUpperCase().replaceAll('.SA', '');
    _priceCache.remove(tickerLimpo);
    LoggerService.debug('🗑️ Cache removido para $tickerLimpo');
  }

  Future<Map<String, dynamic>?> getDadosCompletos(String ticker) async {
    PerformanceService.start('yahoo_getCompleto_$ticker');
    final tickerLimpo = ticker.trim().toUpperCase().replaceAll('.SA', '');

    LoggerService.info('📊 Buscando dados completos para $tickerLimpo');

    try {
      final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$tickerLimpo.SA');
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['chart']['result'] != null &&
            data['chart']['result'].isNotEmpty) {
          final result = data['chart']['result'][0];
          final meta = result['meta'];
          final indicators = result['indicators'];
          final quote = indicators['quote'][0];

          final precoAtual = meta['regularMarketPrice']?.toDouble();
          final nome = meta['longName'] ?? meta['symbol'] ?? tickerLimpo;

          final dados = {
            'ticker': tickerLimpo,
            'nome': nome,
            'precoAtual': precoAtual,
            'precoAbertura': quote['open']?.last?.toDouble(),
            'maximaDia': quote['high']?.last?.toDouble(),
            'minimaDia': quote['low']?.last?.toDouble(),
            'volume': quote['volume']?.last?.toInt(),
          };

          LoggerService.success('✅ Dados completos obtidos para $tickerLimpo');
          PerformanceService.stop('yahoo_getCompleto_$ticker');
          return dados;
        }
      }
    } catch (e) {
      LoggerService.error(
          '❌ Erro ao buscar dados completos de $tickerLimpo', e);
    }

    PerformanceService.stop('yahoo_getCompleto_$ticker (falha)');
    return null;
  }

  Future<List<Map<String, dynamic>>> getDadosHistoricos(
    String ticker, {
    int dias = 30,
  }) async {
    PerformanceService.start('yahoo_getHistorico_$ticker');
    final tickerLimpo = ticker.trim().toUpperCase().replaceAll('.SA', '');

    LoggerService.info(
        '📈 Buscando dados históricos de $dias dias para $tickerLimpo');

    try {
      final dataAtual = DateTime.now();
      final dataInicio = dataAtual.subtract(Duration(days: dias));

      final url = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$tickerLimpo.SA?'
          'period1=${dataInicio.millisecondsSinceEpoch ~/ 1000}&'
          'period2=${dataAtual.millisecondsSinceEpoch ~/ 1000}&'
          'interval=1d');

      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['chart']['result'] != null &&
            data['chart']['result'].isNotEmpty) {
          final result = data['chart']['result'][0];
          final timestamps = result['timestamp'] as List;
          final quote = result['indicators']['quote'][0];

          final List<Map<String, dynamic>> historico = [];

          for (int i = 0; i < timestamps.length; i++) {
            final preco = quote['close']?[i]?.toDouble();
            if (preco != null && preco > 0) {
              historico.add({
                'data':
                    DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
                'preco': preco,
              });
            }
          }

          LoggerService.success(
              '✅ ${historico.length} pontos históricos obtidos');
          PerformanceService.stop('yahoo_getHistorico_$ticker');
          return historico;
        }
      }
    } catch (e) {
      LoggerService.error(
          '❌ Erro ao buscar dados históricos de $tickerLimpo', e);
    }

    LoggerService.warning('⚠️ Nenhum dado histórico obtido');
    PerformanceService.stop('yahoo_getHistorico_$ticker (falha)');
    return [];
  }

  Future<Map<String, double?>> getPrecosEmLote(List<String> tickers) async {
    PerformanceService.start('yahoo_getLote');

    final Map<String, double?> resultados = {};

    for (var ticker in tickers) {
      final preco = await getPrecoAtual(ticker);
      resultados[ticker] = preco;
    }

    PerformanceService.stop('yahoo_getLote');
    return resultados;
  }

  Future<bool> verificarSaude() async {
    try {
      final result = await getPrecoAtual('PETR4');
      return result != null && result > 0;
    } catch (e) {
      return false;
    }
  }

  Map<String, dynamic> getEstatisticasCache() {
    final ativos = _priceCache.values.where((e) => e.isValid).length;
    return {
      'totalItens': _priceCache.length,
      'itensAtivos': ativos,
      'itensExpirados': _priceCache.length - ativos,
    };
  }
}

