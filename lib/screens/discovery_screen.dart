import 'package:flutter/material.dart';

import '../models/stock_detail.dart';
import '../models/stock_quote.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/stat_tile.dart';
import 'stock_detail_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final YahooFinanceService _yahoo = YahooFinanceService();

  List<ScreenResult>? _results;
  bool _loading = false;
  int _progress = 0;
  String? _error;

  double _minYield = 0;
  double _maxPe = 40;
  double _maxDe = 3.0;
  double _minRoe = 0;
  double _minScore = 0;

  static const Map<String, List<String>> _sectorGroups = {
    'Banks & Financials': [
      '1155.KL', '1295.KL', '1023.KL', '5819.KL', '1066.KL', '1082.KL',
      '1015.KL', '5258.KL', '8621.KL', '6459.KL', '1818.KL', '1163.KL',
    ],
    'Telco & Utilities': [
      '4863.KL', '6947.KL', '6011.KL', '6888.KL', '5347.KL', '6033.KL',
      '4677.KL', '6742.KL',
    ],
    'Consumer': [
      '3182.KL', '4715.KL', '4707.KL', '3689.KL', '2658.KL', '2836.KL',
      '3255.KL', '4162.KL', '5296.KL', '5078.KL', '4065.KL', '3719.KL',
    ],
    'Plantations': [
      '1961.KL', '2445.KL', '2291.KL', '6611.KL', '6467.KL', '5015.KL',
    ],
    'Energy & Industrials': [
      '5183.KL', '5681.KL', '7277.KL', '3816.KL', '5210.KL', '4197.KL',
      '5398.KL', '5211.KL', '3336.KL', '5014.KL', '3397.KL', '5099.KL',
      '3034.KL', '6149.KL', '4731.KL', '3794.KL',
    ],
    'Healthcare & Gloves': [
      '5225.KL', '5878.KL', '7113.KL', '5168.KL', '7153.KL',
    ],
    'Technology': [
      '3867.KL', '5005.KL', '0166.KL', '0097.KL', '7163.KL', '8231.KL',
      '0085.KL', '0128.KL', '0147.KL', '7204.KL', '9233.KL', '8869.KL',
    ],
    'Property & REITs': [
      '8664.KL', '8206.KL', '8583.KL', '5106.KL', '5176.KL', '5122.KL',
      '5227.KL', '5089.KL',
    ],
  };

  bool get _hasResults => _results != null && _results!.isNotEmpty;

  Future<void> _runScreen() async {
    setState(() {
      _loading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final allSymbols = _sectorGroups.values.expand((l) => l).toSet().toList();
      final quotes = <String, StockQuote>{};
      for (var i = 0; i < allSymbols.length; i += 20) {
        final chunk = allSymbols.sublist(i, (i + 20).clamp(0, allSymbols.length));
        quotes.addAll(await _yahoo.getQuotes(chunk));
      }
      final out = <ScreenResult>[];
      const concurrency = 4;
      var index = 0;
      Future<void> worker() async {
        while (index < allSymbols.length) {
          final my = index++;
          final symbol = allSymbols[my];
          try {
            final detail = await _yahoo.getSummary(symbol);
            final quote = quotes[symbol];
            out.add(ScreenResult(
              quote: quote,
              detail: detail,
              score: detail.score,
            ));
          } catch (_) {}
          if (mounted) setState(() => _progress = out.length);
        }
      }
      await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
      out.sort((a, b) => b.score.compareTo(a.score));
      if (!mounted) return;
      setState(() {
        _results = out;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<ScreenResult> _filtered() {
    final all = _results ?? [];
    return all.where((r) {
      final d = r.detail;
      if (d.price == null || d.price! <= 0) return false;
      if (_minYield > 0 && (d.dividendYield ?? 0) < _minYield) return false;
      if (d.trailingPE != null &&
          d.trailingPE! > 0 &&
          d.trailingPE! > _maxPe &&
          _maxPe < 40) {
        return false;
      }
      if (d.trailingPE != null && d.trailingPE! <= 0) return false;
      if (_maxDe < 3.0 && (d.debtToEquity ?? 99) > _maxDe) return false;
      if (_minRoe > 0 && (d.roe ?? -1) < _minRoe) return false;
      if (r.score < _minScore) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _hasResults ? _filtered() : <ScreenResult>[];

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discover',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        'Long-term candidates scored on quality, value & income',
                        style:
                            TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildControls(context),
          Expanded(
            child: _loading
                ? _buildProgress(context)
                : _error != null
                    ? _buildError(context)
                    : !_hasResults
                        ? _buildEmpty(context)
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No stocks match the current filters',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              )
                            : _buildList(context, filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.tune,
                size: 18,
                color: _hasActiveFilters() ? scheme.primary : null,
              ),
              label: Text(
                _hasActiveFilters()
                    ? 'Filters active'
                    : 'Filters',
                style: TextStyle(
                  color: _hasActiveFilters() ? scheme.primary : null,
                ),
              ),
              onPressed: () => _showFilterSheet(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              icon: Icon(_hasResults ? Icons.refresh : Icons.play_arrow, size: 18),
              label: Text(_hasResults ? 'Refresh' : 'Scan KLSE'),
              onPressed: _loading ? null : _runScreen,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() =>
      _minYield > 0 || _maxPe < 40 || _maxDe < 3.0 || _minRoe > 0 || _minScore > 0;

  Widget _buildProgress(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Analyzing ${_sectorGroups.values.expand((l) => l).length} KLSE stocks…',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '$_progress fundamentals loaded',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
            FilledButton.tonal(
                onPressed: _runScreen, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Scan the KLSE universe',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Fetches fundamentals for ~80 large & mid-cap Bursa Malaysia stocks and ranks them for long-term investing:\n\n• Dividend yield\n• Return on equity\n• Debt levels\n• Valuation (PE / PB)\n• Earnings growth & margins',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Scan'),
              onPressed: _runScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ScreenResult> results) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = results[i];
        final d = r.detail;
        final changePct = r.quote?.changePercent;
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StockDetailScreen(symbol: d.symbol),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoreBadge(score: r.score),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${i + 1}. ${d.symbol.replaceAll('.KL', '')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                d.sector ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.name ?? d.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in d.strengths().take(3))
                              FlagChip(label: s, positive: true),
                            for (final w in d.warnings().take(2))
                              FlagChip(label: w, positive: false),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        d.price?.toStringAsFixed(2) ?? '--',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        changePct == null
                            ? ''
                            : '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: changePct == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : changePct >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _miniStat('Yield', d.dividendYield?.toStringAsFixed(1)),
                      _miniStat('PE', d.trailingPE?.toStringAsFixed(1)),
                      _miniStat('ROE', d.roe == null ? null : '${d.roe!.toStringAsFixed(0)}%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String? value) {
    return Text(
      '$label ${value ?? '-'}',
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    );
  }

  void _showFilterSheet(BuildContext context) {
    double minYield = _minYield;
    double maxPe = _maxPe;
    double maxDe = _maxDe;
    double minRoe = _minRoe;
    double minScore = _minScore;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Screening Filters',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              _slider('Min dividend yield', '${minYield.toStringAsFixed(1)}%',
                  minYield, 0, 8, (v) => setSheet(() => minYield = v)),
              _slider('Max P/E ratio', maxPe >= 40 ? 'Any' : maxPe.toStringAsFixed(0),
                  maxPe, 5, 40, (v) => setSheet(() => maxPe = v)),
              _slider('Max debt-to-equity',
                  maxDe >= 3.0 ? 'Any' : '${maxDe.toStringAsFixed(1)}x',
                  maxDe, 0.2, 3.0, (v) => setSheet(() => maxDe = v)),
              _slider('Min ROE', '${minRoe.toStringAsFixed(0)}%', minRoe, 0, 25,
                  (v) => setSheet(() => minRoe = v)),
              _slider('Min quality score', minScore.toStringAsFixed(0), minScore,
                  0, 90, (v) => setSheet(() => minScore = v)),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setSheet(() {
                        minYield = 0;
                        maxPe = 40;
                        maxDe = 3.0;
                        minRoe = 0;
                        minScore = 0;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _minYield = minYield;
                        _maxPe = maxPe;
                        _maxDe = maxDe;
                        _minRoe = minRoe;
                        _minScore = minScore;
                      });
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, String valueText, double value, double min,
      double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 10).round(),
            label: valueText,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(valueText,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
