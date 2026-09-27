class StockQuote {
  final String symbol;
  final String? shortName;
  final String? longName;
  final double? price;
  final double? previousClose;
  final double? change;
  final double? changePercent;
  final double? dayHigh;
  final double? dayLow;
  final double? yearHigh;
  final double? yearLow;
  final int? volume;
  final String? currency;
  final String? marketState;
  final String? exchange;

  const StockQuote({
    required this.symbol,
    this.shortName,
    this.longName,
    this.price,
    this.previousClose,
    this.change,
    this.changePercent,
    this.dayHigh,
    this.dayLow,
    this.yearHigh,
    this.yearLow,
    this.volume,
    this.currency,
    this.marketState,
    this.exchange,
  });

  static double? _d(dynamic v) => v is num ? v.toDouble() : null;
  static int? _i(dynamic v) => v is num ? v.toInt() : null;
  static String? _s(dynamic v) => v is String ? v : null;

  factory StockQuote.fromYahooJson(Map<String, dynamic> j) {
    return StockQuote(
      symbol: (j['symbol'] as String?) ?? '',
      shortName: _s(j['shortName']),
      longName: _s(j['longName']),
      price: _d(j['regularMarketPrice']),
      previousClose: _d(j['regularMarketPreviousClose']),
      change: _d(j['regularMarketChange']),
      changePercent: _d(j['regularMarketChangePercent']),
      dayHigh: _d(j['regularMarketDayHigh']),
      dayLow: _d(j['regularMarketDayLow']),
      yearHigh: _d(j['fiftyTwoWeekHigh']),
      yearLow: _d(j['fiftyTwoWeekLow']),
      volume: _i(j['regularMarketVolume']),
      currency: _s(j['currency']),
      marketState: _s(j['marketState']),
      exchange: _s(j['fullExchangeName']),
    );
  }

  String get displayName {
    if (longName != null && longName!.trim().isNotEmpty) return longName!;
    if (shortName != null && shortName!.trim().isNotEmpty) return shortName!;
    return symbol;
  }

  bool get isUp => (changePercent ?? 0) > 0;
  bool get isDown => (changePercent ?? 0) < 0;
}
