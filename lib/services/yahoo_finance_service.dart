import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/stock_detail.dart';
import '../models/stock_quote.dart';

class YahooFinanceException implements Exception {
  final String message;
  YahooFinanceException(this.message);
  @override
  String toString() => message;
}

class ChartPoint {
  final DateTime date;
  final double close;
  const ChartPoint({required this.date, required this.close});
}

class YahooFinanceService {
  static final YahooFinanceService _instance = YahooFinanceService._internal();
  factory YahooFinanceService() => _instance;
  YahooFinanceService._internal();

  static const String _base = 'https://query1.finance.yahoo.com';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  String? _cookie;
  String? _crumb;
  DateTime _crumbAt = DateTime.fromMillisecondsSinceEpoch(0);
  final HttpClient _io = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  Future<void> _ensureCrumb({bool force = false}) async {
    if (!force &&
        _crumb != null &&
        DateTime.now().difference(_crumbAt) < const Duration(hours: 1)) {
      return;
    }
    try {
      final cookieStr = await _fetchCookies('https://fc.yahoo.com');
      final crumb = await _fetchCrumb(cookieStr);
      _cookie = cookieStr;
      _crumb = crumb;
      _crumbAt = DateTime.now();
    } on SocketException catch (e) {
      throw YahooFinanceException('No network connection: ${e.message}');
    }
  }

  Future<String> _fetchCookies(String url) async {
    for (final u in [url, 'https://finance.yahoo.com/']) {
      try {
        final req = await _io.getUrl(Uri.parse(u));
        req.headers.set(HttpHeaders.userAgentHeader, _ua);
        final resp = await req.close();
        await resp.drain<void>();
        final parts = <String>[];
        for (final sc in resp.headers[HttpHeaders.setCookieHeader] ?? const <String>[]) {
          final pair = sc.split(';').first.trim();
          if (pair.isNotEmpty) parts.add(pair);
        }
        if (parts.isNotEmpty) return parts.join('; ');
      } catch (_) {
        continue;
      }
    }
    throw YahooFinanceException('Could not establish Yahoo session');
  }

  Future<String> _fetchCrumb(String cookie) async {
    final req = await _io.getUrl(Uri.parse('$_base/v1/test/getcrumb'));
    req.headers.set(HttpHeaders.userAgentHeader, _ua);
    req.headers.set(HttpHeaders.cookieHeader, cookie);
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode == 200 && body.trim().isNotEmpty && body.trim().length < 64) {
      return body.trim();
    }
    throw YahooFinanceException('Yahoo crumb request failed (HTTP ${resp.statusCode})');
  }

  Future<dynamic> _getJson(Uri uri, {bool auth = true}) async {
    if (auth) await _ensureCrumb();
    final json = await _attempt(uri, auth);
    return json;
  }

  Future<dynamic> _attempt(Uri uri, bool auth) async {
    HttpClientResponse resp;
    try {
      final req = await _io.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, _ua);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (auth && _cookie != null) req.headers.set(HttpHeaders.cookieHeader, _cookie!);
      resp = await req.close().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw YahooFinanceException('Request timed out');
    } on SocketException catch (e) {
      throw YahooFinanceException('No network connection: ${e.message}');
    }

    final body = await resp.transform(utf8.decoder).join();

    if ((resp.statusCode == 401 || resp.statusCode == 403 || resp.statusCode == 999) && auth) {
      await _ensureCrumb(force: true);
      final retryUri = _crumb == null
          ? uri
          : uri.replace(queryParameters: {...uri.queryParameters, 'crumb': _crumb!});
      final retry = await _io.getUrl(retryUri);
      retry.headers.set(HttpHeaders.userAgentHeader, _ua);
      retry.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_cookie != null) retry.headers.set(HttpHeaders.cookieHeader, _cookie!);
      final retryResp = await retry.close().timeout(const Duration(seconds: 25));
      final retryBody = await retryResp.transform(utf8.decoder).join();
      if (retryResp.statusCode == 200) return jsonDecode(retryBody);
      throw YahooFinanceException('Yahoo rejected the request (HTTP ${retryResp.statusCode})');
    }

    if (resp.statusCode != 200) {
      throw YahooFinanceException('Yahoo request failed (HTTP ${resp.statusCode})');
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      throw YahooFinanceException('Invalid response from Yahoo');
    }
  }

  static dynamic _sub(dynamic obj, String key) => obj is Map ? obj[key] : null;

  Future<Map<String, StockQuote>> getQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final uri = Uri.parse('$_base/v7/finance/quote').replace(queryParameters: {
      'symbols': symbols.join(','),
    });
    final json = await _getJson(uri);
    final result = _sub(_sub(json, 'quoteResponse'), 'result');
    final out = <String, StockQuote>{};
    if (result is List) {
      for (final item in result) {
        if (item is Map<String, dynamic> &&
            (item['symbol'] as String?)?.isNotEmpty == true) {
          final q = StockQuote.fromYahooJson(item);
          if (q.price != null) out[q.symbol] = q;
        }
      }
    }
    return out;
  }

  Future<List<ChartPoint>> getChart(
    String symbol, {
    String range = '1y',
    String interval = '1d',
  }) async {
    final uri = Uri.parse('$_base/v8/finance/chart/${Uri.encodeComponent(symbol)}')
        .replace(queryParameters: {'range': range, 'interval': interval});
    final json = await _getJson(uri, auth: false);
    final result = _sub(_sub(json, 'chart'), 'result');
    if (result is! List || result.isEmpty) {
      final err = _sub(_sub(_sub(json, 'chart'), 'error'), 'description');
      throw YahooFinanceException(err is String ? err : 'No chart data for $symbol');
    }
    final r = result.first as Map<String, dynamic>;
    final timestamps = r['timestamp'] as List?;
    final quote = _sub(_sub(r, 'indicators'), 'quote');
    final closes =
        quote is List && quote.isNotEmpty && quote.first is Map ? quote.first['close'] as List? : null;
    if (timestamps == null || closes == null) {
      throw YahooFinanceException('No chart data for $symbol');
    }
    final out = <ChartPoint>[];
    for (var i = 0; i < timestamps.length && i < closes.length; i++) {
      final ts = timestamps[i];
      final c = closes[i];
      if (ts is num && c is num) {
        out.add(ChartPoint(
          date: DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000),
          close: c.toDouble(),
        ));
      }
    }
    return out;
  }

  Future<StockDetail> getSummary(String symbol) async {
    final uri = Uri.parse(
      '$_base/v10/finance/quoteSummary/${Uri.encodeComponent(symbol)}',
    ).replace(queryParameters: {
      'modules':
          'price,summaryDetail,defaultKeyStatistics,financialData,summaryProfile',
    });
    final json = await _getJson(uri);
    final result = _sub(_sub(json, 'quoteSummary'), 'result');
    if (result is! List || result.isEmpty) {
      throw YahooFinanceException('No fundamentals data for $symbol');
    }
    final r = result.first as Map<String, dynamic>;
    Map<String, dynamic>? m(String key) => r[key] is Map<String, dynamic> ? r[key] as Map<String, dynamic> : null;
    return StockDetail.fromQuoteSummary(
      symbol,
      m('summaryDetail'),
      m('financialData'),
      m('defaultKeyStatistics'),
      m('summaryProfile'),
      m('price'),
    );
  }

  Future<List<StockQuote>> search(String query) async {
    final uri = Uri.parse('$_base/v1/finance/search').replace(queryParameters: {
      'q': query,
      'quotesCount': '30',
      'newsCount': '0',
    });
    final json = await _getJson(uri);
    final quotes = json is Map ? json['quotes'] : null;
    final out = <StockQuote>[];
    if (quotes is List) {
      for (final item in quotes) {
        if (item is Map<String, dynamic>) {
          final symbol = item['symbol'] as String? ?? '';
          final qType = item['quoteType'] as String? ?? '';
          if (symbol.isEmpty || qType != 'EQUITY') continue;
          out.add(StockQuote.fromYahooJson(item));
        }
      }
    }
    out.sort((a, b) {
      final aKl = a.symbol.endsWith('.KL') ? 0 : 1;
      final bKl = b.symbol.endsWith('.KL') ? 0 : 1;
      if (aKl != bKl) return aKl - bKl;
      return a.symbol.compareTo(b.symbol);
    });
    return out;
  }

  void dispose() {
    _io.close(force: true);
  }
}
