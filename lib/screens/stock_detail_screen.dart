import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_detail.dart';
import '../services/llm_service.dart';
import '../services/yahoo_finance_service.dart';
import '../providers/settings_provider.dart';
import '../providers/watchlist_provider.dart';
import '../util/format.dart';
import '../widgets/price_chart.dart';
import '../widgets/stat_tile.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

enum _ChartRange { m6, y1, y5 }

extension _ChartRangeX on _ChartRange {
  String get label => switch (this) {
        _ChartRange.m6 => '6M',
        _ChartRange.y1 => '1Y',
        _ChartRange.y5 => '5Y',
      };
  String get range => switch (this) {
        _ChartRange.m6 => '6mo',
        _ChartRange.y1 => '1y',
        _ChartRange.y5 => '5y',
      };
  String get interval => this == _ChartRange.y5 ? '1wk' : '1d';
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final YahooFinanceService _yahoo = YahooFinanceService();
  final LlmService _llm = LlmService();

  late Future<StockDetail> _detailFuture;
  _ChartRange _range = _ChartRange.y1;
  late Future<List<ChartPoint>> _chartFuture;
  final Set<ChartIndicator> _indicators = {
    ChartIndicator.sma20,
    ChartIndicator.sma50,
  };

  String? _analysis;
  bool _analyzing = false;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    _detailFuture = _yahoo.getSummary(widget.symbol);
    _chartFuture = _yahoo.getChart(widget.symbol,
        range: _range.range, interval: _range.interval);
  }

  void _setRange(_ChartRange r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _chartFuture = _yahoo.getChart(widget.symbol,
          range: r.range, interval: r.interval);
    });
  }

  Future<void> _toggleWatchlist() async {
    final wp = context.read<WatchlistProvider>();
    if (wp.symbols.contains(widget.symbol)) {
      await wp.remove(widget.symbol);
    } else {
      await wp.add(widget.symbol);
    }
  }

  Future<void> _runAnalysis(StockDetail d) async {
    final settings = context.read<SettingsProvider>();
    final config = settings.llm;
    if (!config.isConfigured) {
      setState(() => _analysisError =
          'LLM is not configured. Go to Settings and set the API URL, token and model first.');
      return;
    }
    setState(() {
      _analyzing = true;
      _analysisError = null;
      _analysis = null;
    });
    try {
      final result = await _llm.complete(
        config: config,
        system:
            'You are a long-term equity research analyst specialising in Bursa Malaysia (KLSE) stocks. '
            'You reason carefully and conservatively. Use ONLY the data provided by the user; '
            'you have no access to live prices or news.',
        prompt: _buildPrompt(d),
        temperature: 0.4,
      );
      if (mounted) setState(() => _analysis = result);
    } catch (e) {
      if (mounted) {
        setState(() => _analysisError = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  String _buildPrompt(StockDetail d) {
    final cur = d.currency ?? 'MYR';
    String line(String label, Object? v, {String suffix = ''}) =>
        '- $label: ${v ?? 'N/A'}$suffix\n';

    final buf = StringBuffer()
      ..writeln('Produce a long-term investment research note for this stock.')
      ..writeln()
      ..writeln('STOCK DATA')
      ..write(line('Company', '${d.name ?? 'Unknown'} [${d.symbol}]'))
      ..write(line('Sector / Industry', '${d.sector ?? 'N/A'} / ${d.industry ?? 'N/A'}'))
      ..write(line('Price', d.price?.toStringAsFixed(2), suffix: ' $cur'))
      ..write(line('52-week range',
          '${d.yearLow?.toStringAsFixed(2) ?? '?'} - ${d.yearHigh?.toStringAsFixed(2) ?? '?'}'))
      ..write(line('50-day avg', d.fiftyDayAverage?.toStringAsFixed(2)))
      ..write(line('200-day avg', d.twoHundredDayAverage?.toStringAsFixed(2)))
      ..write(line('Market cap', fmtCompact(d.marketCap)))
      ..writeln()
      ..writeln('VALUATION')
      ..write(line('Trailing P/E', d.trailingPE?.toStringAsFixed(1)))
      ..write(line('Forward P/E', d.forwardPE?.toStringAsFixed(1)))
      ..write(line('P/B', d.priceToBook?.toStringAsFixed(2)))
      ..write(line('P/S', d.priceToSales?.toStringAsFixed(2)))
      ..write(line('Book value/share', d.bookValue?.toStringAsFixed(2)))
      ..writeln()
      ..writeln('INCOME & DIVIDENDS')
      ..write(line('Dividend yield', d.dividendYield?.toStringAsFixed(2), suffix: '%'))
      ..write(line('Dividend per share', d.dividendRate?.toStringAsFixed(2), suffix: ' $cur'))
      ..write(line('Payout ratio', d.payoutRatio?.toStringAsFixed(0), suffix: '%'))
      ..writeln()
      ..writeln('QUALITY & GROWTH')
      ..write(line('ROE', d.roe?.toStringAsFixed(1), suffix: '%'))
      ..write(line('ROA', d.returnOnAssets?.toStringAsFixed(1), suffix: '%'))
      ..write(line('Profit margin', d.profitMargins?.toStringAsFixed(1), suffix: '%'))
      ..write(line('Gross margin', d.grossMargins?.toStringAsFixed(1), suffix: '%'))
      ..write(line('Revenue growth (YoY)', d.revenueGrowth?.toStringAsFixed(1), suffix: '%'))
      ..write(line('Earnings growth (YoY)', d.earningsGrowth?.toStringAsFixed(1), suffix: '%'))
      ..writeln()
      ..writeln('BALANCE SHEET & CASH FLOW')
      ..write(line('Debt/Equity', d.debtToEquity?.toStringAsFixed(2)))
      ..write(line('Current ratio', d.currentRatio?.toStringAsFixed(2)))
      ..write(line('Total cash', fmtCompact(d.totalCash), suffix: ' $cur'))
      ..write(line('Total debt', fmtCompact(d.totalDebt), suffix: ' $cur'))
      ..write(line('Operating cashflow', fmtCompact(d.operatingCashflow), suffix: ' $cur'))
      ..write(line('Free cashflow', fmtCompact(d.freeCashflow), suffix: ' $cur'))
      ..writeln()
      ..writeln('ANALYST VIEW')
      ..write(line('Recommendation', recommendationLabel(d.recommendationKey)))
      ..write(line('Target price', d.targetMeanPrice?.toStringAsFixed(2), suffix: ' $cur'))
      ..write(line('Analysts covering', d.analystCount))
      ..writeln()
      ..writeln(
          'In-app quantitative long-term score: ${d.score.toStringAsFixed(0)}/100 (weighted: dividend yield 25, ROE 20, debt 15, PE 15, growth 10, margins 10, PB 5).')
      ..writeln()
      ..writeln('FORMAT YOUR NOTE AS PLAIN TEXT WITH THESE SECTIONS:')
      ..writeln('1. BUSINESS & MOAT')
      ..writeln('2. FINANCIAL HEALTH & QUALITY')
      ..writeln('3. VALUATION & DIVIDEND')
      ..writeln('4. KEY RISKS')
      ..writeln('5. LONG-TERM VERDICT (suitability score out of 10 with one-line justification)')
      ..writeln('Keep the whole note under 400 words. Do not fabricate data you were not given.');

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WatchlistProvider>();
    final watched = wp.symbols.contains(widget.symbol);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol.replaceAll('.KL', '')),
        actions: [
          IconButton(
            icon: Icon(
              watched ? Icons.star_rounded : Icons.star_border_rounded,
              color: watched ? Colors.amber.shade700 : null,
            ),
            tooltip: watched ? 'Remove from watchlist' : 'Add to watchlist',
            onPressed: _toggleWatchlist,
          ),
        ],
      ),
      body: FutureBuilder<StockDetail>(
        future: _detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _errorView(context, snap.error.toString());
          }
          final d = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _detailFuture = _yahoo.getSummary(widget.symbol);
                _chartFuture = _yahoo.getChart(widget.symbol,
                    range: _range.range, interval: _range.interval);
              });
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _header(context, d),
                const SizedBox(height: 16),
                _chartSection(context),
                const SizedBox(height: 16),
                _scoreSection(context, d),
                const SizedBox(height: 16),
                _valuationSection(context, d),
                const SizedBox(height: 16),
                _incomeSection(context, d),
                const SizedBox(height: 16),
                _qualitySection(context, d),
                const SizedBox(height: 16),
                _balanceSection(context, d),
                const SizedBox(height: 16),
                _analystSection(context, d),
                const SizedBox(height: 16),
                _aiSection(context, d),
                if (d.businessSummary != null && d.businessSummary!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _card(
                    context,
                    title: 'About',
                    child: Text(
                      d.businessSummary!,
                      style: const TextStyle(fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _errorView(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => setState(() {
                _detailFuture = _yahoo.getSummary(widget.symbol);
                _chartFuture = _yahoo.getChart(widget.symbol,
                    range: _range.range, interval: _range.interval);
              }),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, required Widget child, Widget? trailing}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _header(BuildContext context, StockDetail d) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          d.name ?? widget.symbol,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (d.sector != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  d.sector!,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary),
                ),
              ),
            if (d.industry != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  d.industry!,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmtMoney(d.price, currency: d.currency ?? 'RM'),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '52w ${d.yearLow?.toStringAsFixed(2) ?? '?'} – ${d.yearHigh?.toStringAsFixed(2) ?? '?'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chartSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _card(
      context,
      title: 'Technical Chart',
      trailing: SegmentedButton<_ChartRange>(
        style: const ButtonStyle(
          visualDensity: VisualDensity(horizontal: -3, vertical: -2.5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: [
          for (final r in _ChartRange.values)
            ButtonSegment(value: r, label: Text(r.label, style: const TextStyle(fontSize: 11))),
        ],
        selected: {_range},
        onSelectionChanged: (s) => _setRange(s.first),
      ),
      child: FutureBuilder<List<ChartPoint>>(
        future: _chartFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError || snap.data == null) {
            return SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  'Chart unavailable',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PriceChart(points: snap.data!, indicators: _indicators),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final ind in ChartIndicator.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: FilterChip(
                        label: Text(ind.label,
                            style: const TextStyle(fontSize: 11)),
                        selected: _indicators.contains(ind),
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onSelected: (sel) => setState(() {
                          sel ? _indicators.add(ind) : _indicators.remove(ind);
                        }),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _scoreSection(BuildContext context, StockDetail d) {
    final scheme = Theme.of(context).colorScheme;
    final strengths = d.strengths();
    final warnings = d.warnings();
    return _card(
      context,
      title: 'Long-Term Score',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScoreBadge(score: d.score, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weighted on yield, ROE, debt, valuation, growth & margins.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                if (strengths.isEmpty && warnings.isEmpty)
                  Text('Mixed profile — no standout signals.',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in strengths) FlagChip(label: s, positive: true),
                    for (final w in warnings) FlagChip(label: w, positive: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(List<Widget> tiles) {
    return LayoutBuilder(builder: (context, constraints) {
      const cols = 3;
      const gap = 8.0;
      final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }

  Widget _valuationSection(BuildContext context, StockDetail d) {
    return _card(
      context,
      title: 'Valuation',
      child: _statGrid([
        StatTile(label: 'Trailing P/E', value: fmtNum(d.trailingPE, digits: 1)),
        StatTile(label: 'Forward P/E', value: fmtNum(d.forwardPE, digits: 1)),
        StatTile(label: 'P/B', value: fmtNum(d.priceToBook)),
        StatTile(label: 'P/S', value: fmtNum(d.priceToSales)),
        StatTile(label: 'EPS (TTM)', value: fmtNum(d.trailingEps)),
        StatTile(label: 'Market Cap', value: fmtCompact(d.marketCap)),
      ]),
    );
  }

  Widget _incomeSection(BuildContext context, StockDetail d) {
    return _card(
      context,
      title: 'Income & Dividends',
      child: _statGrid([
        StatTile(
          label: 'Div Yield',
          value: d.dividendYield == null ? 'N/A' : '${d.dividendYield!.toStringAsFixed(2)}%',
          valueColor: (d.dividendYield ?? 0) >= 4 ? const Color(0xFF16A34A) : null,
        ),
        StatTile(label: 'Div/Share', value: fmtNum(d.dividendRate)),
        StatTile(label: 'Payout', value: d.payoutRatio == null ? 'N/A' : '${d.payoutRatio!.toStringAsFixed(0)}%'),
      ]),
    );
  }

  Widget _qualitySection(BuildContext context, StockDetail d) {
    Color? good(double? v, double threshold) =>
        v != null && v >= threshold ? const Color(0xFF16A34A) : null;
    return _card(
      context,
      title: 'Quality & Growth',
      child: _statGrid([
        StatTile(label: 'ROE', value: fmtPct(d.roe, signed: false), valueColor: good(d.roe, 12)),
        StatTile(label: 'ROA', value: fmtPct(d.returnOnAssets, signed: false)),
        StatTile(label: 'Net Margin', value: fmtPct(d.profitMargins, signed: false)),
        StatTile(label: 'Gross Margin', value: fmtPct(d.grossMargins, signed: false)),
        StatTile(label: 'Rev Growth', value: fmtPct(d.revenueGrowth)),
        StatTile(label: 'Earn Growth', value: fmtPct(d.earningsGrowth)),
      ]),
    );
  }

  Widget _balanceSection(BuildContext context, StockDetail d) {
    return _card(
      context,
      title: 'Balance Sheet & Cash Flow',
      child: _statGrid([
        StatTile(
          label: 'Debt/Equity',
          value: d.debtToEquity == null ? 'N/A' : '${d.debtToEquity!.toStringAsFixed(2)}x',
          valueColor: (d.debtToEquity ?? 0) <= 1 ? const Color(0xFF16A34A) : null,
        ),
        StatTile(label: 'Current Ratio', value: fmtNum(d.currentRatio)),
        StatTile(label: 'Op. Cashflow', value: fmtCompact(d.operatingCashflow)),
        StatTile(label: 'Free Cashflow', value: fmtCompact(d.freeCashflow)),
        StatTile(label: 'Total Cash', value: fmtCompact(d.totalCash)),
        StatTile(label: 'Total Debt', value: fmtCompact(d.totalDebt)),
      ]),
    );
  }

  Widget _analystSection(BuildContext context, StockDetail d) {
    final target = d.targetMeanPrice;
    final price = d.price;
    final upside =
        target != null && price != null && price > 0 ? (target - price) / price * 100 : null;
    return _card(
      context,
      title: 'Analyst View',
      child: _statGrid([
        StatTile(label: 'Rating', value: recommendationLabel(d.recommendationKey)),
        StatTile(label: 'Target Price', value: fmtNum(target)),
        StatTile(
          label: 'Upside',
          value: upside == null ? 'N/A' : fmtPct(upside),
          valueColor: upside != null && upside > 0 ? const Color(0xFF16A34A) : null,
        ),
        StatTile(label: 'Analysts', value: d.analystCount?.toString() ?? 'N/A'),
        StatTile(label: '50D Avg', value: fmtNum(d.fiftyDayAverage)),
        StatTile(
          label: 'vs 200D',
          value: d.twoHundredDayAverage != null && price != null
              ? fmtPct((price - d.twoHundredDayAverage!) / d.twoHundredDayAverage! * 100)
              : 'N/A',
          valueColor: d.twoHundredDayAverage != null && price != null
              ? price >= d.twoHundredDayAverage!
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626)
              : null,
        ),
      ]),
    );
  }

  Widget _aiSection(BuildContext context, StockDetail d) {
    final scheme = Theme.of(context).colorScheme;
    final llm = context.watch<SettingsProvider>().llm;
    return _card(
      context,
      title: 'AI Research Note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            llm.isConfigured
                ? 'Uses your configured LLM (${llm.model}) to produce a long-term investment thesis from the fundamentals above.'
                : 'Configure an LLM API (URL, token, model) in Settings to enable AI research notes.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                icon: _analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_analyzing ? 'Analyzing…' : 'Generate Analysis'),
                onPressed: _analyzing ? null : () => _runAnalysis(d),
              ),
              const Spacer(),
              if (llm.isConfigured && !_analyzing && (_analysis != null || _analysisError != null))
                TextButton(
                  onPressed: () => _runAnalysis(d),
                  child: const Text('Regenerate'),
                ),
            ],
          ),
          if (_analysisError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _analysisError!,
                      style: TextStyle(fontSize: 12, color: scheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_analysis != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
              ),
              child: SelectableText(
                _analysis!,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
