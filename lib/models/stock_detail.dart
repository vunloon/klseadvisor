import 'stock_quote.dart';

class StockDetail {
  final String symbol;
  final String? name;
  final String? sector;
  final String? industry;
  final String? website;
  final String? businessSummary;
  final double? price;
  final double? marketCap;
  final double? trailingPE;
  final double? forwardPE;
  final double? priceToBook;
  final double? priceToSales;
  final double? dividendYield;
  final double? dividendRate;
  final double? payoutRatio;
  final double? beta;
  final double? roe;
  final double? returnOnAssets;
  final double? debtToEquity;
  final double? currentRatio;
  final double? freeCashflow;
  final double? operatingCashflow;
  final double? totalCash;
  final double? totalDebt;
  final double? revenue;
  final double? revenueGrowth;
  final double? earningsGrowth;
  final double? profitMargins;
  final double? grossMargins;
  final double? targetMeanPrice;
  final double? recommendationMean;
  final int? analystCount;
  final String? recommendation;
  final double? yearHigh;
  final double? yearLow;
  final double? fiftyDayAverage;
  final double? twoHundredDayAverage;
  final double? trailingEps;
  final double? bookValue;
  final int? sharesOutstanding;
  final String? currency;
  final String? recommendationKey;

  const StockDetail({
    required this.symbol,
    this.name,
    this.sector,
    this.industry,
    this.website,
    this.businessSummary,
    this.price,
    this.marketCap,
    this.trailingPE,
    this.forwardPE,
    this.priceToBook,
    this.priceToSales,
    this.dividendYield,
    this.dividendRate,
    this.payoutRatio,
    this.beta,
    this.roe,
    this.returnOnAssets,
    this.debtToEquity,
    this.currentRatio,
    this.freeCashflow,
    this.operatingCashflow,
    this.totalCash,
    this.totalDebt,
    this.revenue,
    this.revenueGrowth,
    this.earningsGrowth,
    this.profitMargins,
    this.grossMargins,
    this.targetMeanPrice,
    this.recommendationMean,
    this.analystCount,
    this.recommendation,
    this.yearHigh,
    this.yearLow,
    this.fiftyDayAverage,
    this.twoHundredDayAverage,
    this.trailingEps,
    this.bookValue,
    this.sharesOutstanding,
    this.currency,
    this.recommendationKey,
  });

  static double? _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is Map && v['raw'] is num) return (v['raw'] as num).toDouble();
    return null;
  }

  static int? _i(dynamic v) {
    if (v is num) return v.toInt();
    if (v is Map && v['raw'] is num) return (v['raw'] as num).toInt();
    return null;
  }

  static String? _s(dynamic v) => v is String ? v : null;

  factory StockDetail.fromQuoteSummary(
    String symbol,
    Map<String, dynamic>? summaryDetail,
    Map<String, dynamic>? financialData,
    Map<String, dynamic>? defaultKeyStatistics,
    Map<String, dynamic>? summaryProfile,
    Map<String, dynamic>? price,
  ) {
    final sd = summaryDetail ?? const {};
    final fd = financialData ?? const {};
    final ks = defaultKeyStatistics ?? const {};
    final sp = summaryProfile ?? const {};
    final pr = price ?? const {};

    final marketCap = _d(pr['marketCap']) ?? _d(sd['marketCap']);
    final trailingEps = _d(sd['trailingEps']) ?? _d(ks['trailingEps']);
    final bookValue = _d(sd['bookValue']) ?? _d(ks['bookValue']);
    var dy = _d(sd['dividendYield']);
    if (dy != null && dy < 1) dy = dy * 100;
    var de = _d(fd['debtToEquity']);
    if (de != null && de > 5) de = de / 100;

    double? pct(dynamic v) {
      final x = _d(v);
      return x == null ? null : x * 100;
    }

    return StockDetail(
      symbol: symbol,
      name: _s(pr['longName']) ?? _s(pr['shortName']),
      sector: _s(sp['sector']),
      industry: _s(sp['industry']),
      website: _s(sp['website']),
      businessSummary: _s(sp['longBusinessSummary']),
      price: _d(pr['regularMarketPrice']),
      marketCap: marketCap,
      trailingPE: _d(sd['trailingPE']),
      forwardPE: _d(sd['forwardPE']),
      priceToBook: _d(ks['priceToBook']) ?? _d(sd['priceToBook']),
      priceToSales: _d(sd['priceToSalesTrailing12Months']),
      dividendYield: dy,
      dividendRate: _d(sd['dividendRate']),
      payoutRatio: pct(sd['payoutRatio']),
      beta: _d(sd['beta']),
      roe: pct(fd['returnOnEquity']),
      returnOnAssets: pct(fd['returnOnAssets']),
      debtToEquity: de,
      currentRatio: _d(fd['currentRatio']),
      freeCashflow: _d(fd['freeCashflow']),
      operatingCashflow: _d(fd['operatingCashflow']),
      totalCash: _d(fd['totalCash']),
      totalDebt: _d(fd['totalDebt']),
      revenue: _d(fd['totalRevenue']),
      revenueGrowth: pct(fd['revenueGrowth']),
      earningsGrowth: pct(fd['earningsGrowth']),
      profitMargins: pct(fd['profitMargins']),
      grossMargins: pct(fd['grossMargins']),
      targetMeanPrice: _d(fd['targetMeanPrice']),
      recommendationMean: _d(fd['recommendationMean']),
      analystCount: _i(fd['numberOfAnalystOpinions']),
      recommendation: _s(fd['recommendationKey']),
      recommendationKey: _s(fd['recommendationKey']),
      yearHigh: _d(sd['fiftyTwoWeekHigh']) ?? _d(pr['fiftyTwoWeekHigh']),
      yearLow: _d(sd['fiftyTwoWeekLow']) ?? _d(pr['fiftyTwoWeekLow']),
      fiftyDayAverage: _d(sd['fiftyDayAverage']),
      twoHundredDayAverage: _d(sd['twoHundredDayAverage']),
      trailingEps: trailingEps,
      bookValue: bookValue,
      sharesOutstanding: _i(ks['sharesOutstanding']),
      currency: _s(pr['financialCurrency']) ?? _s(pr['currency']),
    );
  }

  double get score {
    double s = 0;
    if (dividendYield != null && dividendYield! > 0) {
      s += (dividendYield! / 5).clamp(0.0, 1.0) * 25;
    }
    if (roe != null && roe! > 0) s += (roe! / 15).clamp(0.0, 1.0) * 20;
    if (debtToEquity != null) {
      s += (1 - (debtToEquity! - 0.5) / 1.5).clamp(0.0, 1.0) * 15;
    }
    if (trailingPE != null && trailingPE! > 0) {
      s += (1 - (trailingPE! - 10) / 20).clamp(0.0, 1.0) * 15;
    }
    if (earningsGrowth != null) {
      s += (earningsGrowth! / 10).clamp(0.0, 1.0) * 10;
    }
    if (profitMargins != null) {
      s += (profitMargins! / 15).clamp(0.0, 1.0) * 10;
    }
    if (priceToBook != null && priceToBook! > 0) {
      s += (1 - (priceToBook! - 1) / 2).clamp(0.0, 1.0) * 5;
    }
    return s;
  }

  List<String> strengths() {
    final out = <String>[];
    if ((dividendYield ?? 0) >= 4) out.add('High yield');
    if ((roe ?? 0) >= 15) out.add('Strong ROE');
    if ((debtToEquity ?? 99) <= 0.5) out.add('Low debt');
    if (trailingPE != null && trailingPE! > 0 && trailingPE! <= 12) out.add('Cheap PE');
    if ((earningsGrowth ?? 0) >= 10) out.add('Growing earnings');
    if ((profitMargins ?? 0) >= 15) out.add('Wide margins');
    return out;
  }

  List<String> warnings() {
    final out = <String>[];
    if (trailingPE != null && trailingPE! < 0) out.add('Loss-making (negative PE)');
    if ((debtToEquity ?? 0) >= 2) out.add('High leverage');
    if ((payoutRatio ?? 0) > 100) out.add('Unsustainable payout');
    if ((roe ?? 99) < 5 && roe != null) out.add('Weak ROE');
    if ((earningsGrowth ?? 1) < -5) out.add('Shrinking earnings');
    return out;
  }
}

class ScreenResult {
  final StockQuote? quote;
  final StockDetail detail;
  final double score;

  const ScreenResult({required this.quote, required this.detail, required this.score});
}
