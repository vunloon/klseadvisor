import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/stock_quote.dart';
import '../services/settings_repository.dart';
import '../services/yahoo_finance_service.dart';
import 'settings_provider.dart';

enum WatchlistStatus { idle, loading, ready, error }

class WatchlistProvider extends ChangeNotifier {
  final YahooFinanceService _yahoo = YahooFinanceService();
  final SettingsRepository _repo = SettingsRepository();
  final SettingsProvider _settings;

  WatchlistProvider(this._settings);

  static const String indexSymbol = '^KLSE';

  List<String> _symbols = [];
  final Map<String, StockQuote> _quotes = {};
  StockQuote? _index;
  WatchlistStatus _status = WatchlistStatus.idle;
  String? _error;
  Timer? _timer;
  DateTime? _lastUpdated;

  List<String> get symbols => List.unmodifiable(_symbols);
  StockQuote? quote(String symbol) => _quotes[symbol];
  StockQuote? get index => _index;
  WatchlistStatus get status => _status;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isWatched => _symbols.isNotEmpty;

  Future<void> load() async {
    _symbols = await _repo.loadWatchlist();
    await refresh();
  }

  Future<void> refresh() async {
    if (_symbols.isEmpty && _quotes.isEmpty && _index == null) {
      _status = WatchlistStatus.ready;
      notifyListeners();
    }
    _status = WatchlistStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final all = [..._symbols];
      if (!all.contains(indexSymbol)) all.add(indexSymbol);
      final results = <String, StockQuote>{};
      const chunkSize = 20;
      for (var i = 0; i < all.length; i += chunkSize) {
        final chunk = all.sublist(i, (i + chunkSize).clamp(0, all.length));
        final batch = await _yahoo.getQuotes(chunk);
        results.addAll(batch);
      }
      _index = results.remove(indexSymbol) ?? _index;
      _quotes
        ..clear()
        ..addAll(results);
      _status = WatchlistStatus.ready;
      _lastUpdated = DateTime.now();
    } catch (e) {
      _status = WatchlistStatus.error;
      _error = e.toString();
    }
    notifyListeners();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!_settings.loaded || !_settings.autoRefresh) return;
    _timer = Timer(Duration(seconds: _settings.refreshSeconds), () {
      if (_settings.autoRefresh) refresh();
    });
  }

  void restartAutoRefresh() {
    _timer?.cancel();
    _scheduleNext();
  }

  Future<void> add(String symbol) async {
    symbol = symbol.trim().toUpperCase();
    if (symbol.isEmpty || _symbols.contains(symbol)) return;
    _symbols = [..._symbols, symbol];
    await _repo.saveWatchlist(_symbols);
    notifyListeners();
    unawaited(_fetchOne(symbol));
  }

  Future<void> _fetchOne(String symbol) async {
    try {
      final r = await _yahoo.getQuotes([symbol]);
      final q = r[symbol];
      if (q != null) {
        _quotes[symbol] = q;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> remove(String symbol) async {
    _symbols = _symbols.where((s) => s != symbol).toList();
    _quotes.remove(symbol);
    await _repo.saveWatchlist(_symbols);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
