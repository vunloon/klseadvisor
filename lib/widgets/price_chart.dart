import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/yahoo_finance_service.dart';
import '../util/format.dart';
import '../util/indicators.dart';

enum ChartIndicator { sma20, sma50, bollinger, macd, rsi }

extension ChartIndicatorX on ChartIndicator {
  String get label => switch (this) {
        ChartIndicator.sma20 => 'SMA 20',
        ChartIndicator.sma50 => 'SMA 50',
        ChartIndicator.bollinger => 'BB (20, 2)',
        ChartIndicator.macd => 'MACD',
        ChartIndicator.rsi => 'RSI',
      };
}

class PriceChart extends StatelessWidget {
  final List<ChartPoint> points;
  final bool showYAxis;
  final Set<ChartIndicator> indicators;

  const PriceChart({
    super.key,
    required this.points,
    this.showYAxis = true,
    this.indicators = const {},
  });

  static const _sma20Color = Color(0xFF0EA5E9);
  static const _sma50Color = Color(0xFFF59E0B);
  static const _bbColor = Color(0xFF8B5CF6);
  static const _rsiColor = Color(0xFFA855F7);
  static const _macdLabels = ['MACD', 'Signal', 'Hist'];

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Not enough data to plot')),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final closes = [for (final p in points) p.close];
    final up = closes.last >= closes.first;
    final priceColor = up ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    final sma20Line =
        indicators.contains(ChartIndicator.sma20) ? sma(closes, 20) : null;
    final sma50Line =
        indicators.contains(ChartIndicator.sma50) ? sma(closes, 50) : null;
    final bb = indicators.contains(ChartIndicator.bollinger)
        ? bollinger(closes)
        : null;

    // ---- price panel -------------------------------------------------------
    final priceSpots = <FlSpot>[
      for (var i = 0; i < closes.length; i++) FlSpot(i.toDouble(), closes[i]),
    ];

    final bars = <LineChartBarData>[
      LineChartBarData(
        spots: priceSpots,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        color: priceColor,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: priceColor.withOpacity(0.08),
        ),
      ),
    ];
    final labels = <String>['Close'];
    if (sma20Line != null) {
      bars.add(_series(_spots(sma20Line), _sma20Color, 1.4));
      labels.add('SMA 20');
    }
    if (sma50Line != null) {
      bars.add(_series(_spots(sma50Line), _sma50Color, 1.4));
      labels.add('SMA 50');
    }
    var bbFill = const <BetweenBarsData>[];
    if (bb != null) {
      final upperIdx = bars.length;
      bars.add(_series(_spots(bb.upper), _bbColor.withOpacity(0.75), 1));
      labels.add('BB Upper');
      bars.add(_series(_spots(bb.lower), _bbColor.withOpacity(0.75), 1));
      labels.add('BB Lower');
      bbFill = [
        BetweenBarsData(
          fromIndex: upperIdx,
          toIndex: upperIdx + 1,
          color: _bbColor.withOpacity(0.08),
        ),
      ];
    }

    double lo = closes.reduce((a, b) => a < b ? a : b);
    double hi = closes.reduce((a, b) => a > b ? a : b);
    if (bb != null) {
      for (final v in bb.upper) {
        if (v != null && v > hi) hi = v;
      }
      for (final v in bb.lower) {
        if (v != null && v < lo) lo = v;
      }
    }
    final pad = (hi - lo) == 0 ? (hi * 0.05) : (hi - lo) * 0.08;

    final legendItems = <(Color, String)>[
      (priceColor, 'Close'),
      if (sma20Line != null) (_sma20Color, 'SMA 20'),
      if (sma50Line != null) (_sma50Color, 'SMA 50'),
      if (bb != null) (_bbColor, 'BB (20, 2)'),
    ];

    final showMacd = indicators.contains(ChartIndicator.macd);
    final showRsi = indicators.contains(ChartIndicator.rsi);
    final macdResult = showMacd ? macd(closes) : null;
    final rsiLine = showRsi ? rsi(closes) : null;

    final labelEvery = (points.length / 4).ceil().clamp(1, points.length);

    // ---- layout ------------------------------------------------------------
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
          child: SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: (lo - pad).floorToDouble(),
                maxY: (hi + pad).ceilToDouble(),
                betweenBarsData: bbFill,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      (hi - lo) / 4 == 0 ? null : (hi - lo) / 4,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: scheme.outlineVariant.withOpacity(0.4),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: showYAxis,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          v.toStringAsFixed(2),
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: !showMacd && !showRsi,
                      reservedSize: 24,
                      getTitlesWidget: (v, meta) => _xTitle(
                        v, meta, scheme, labelEvery,
                        show: !showMacd && !showRsi,
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          s.barIndex == 0
                              ? '${fmtDateShort(points[s.x.toInt()].date)}\n'
                                  '${labels[s.barIndex]} ${s.y.toStringAsFixed(2)}'
                              : '${labels[s.barIndex]} ${s.y.toStringAsFixed(2)}',
                          TextStyle(
                            color: scheme.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: bars,
              ),
            ),
          ),
        ),
        if (legendItems.length > 1) ...[
          const SizedBox(height: 6),
          _legend(scheme, legendItems),
        ],
        if (macdResult != null) ...[
          const SizedBox(height: 10),
          _macdPanel(context, macdResult, labelEvery,
              bottomDates: !showRsi),
        ],
        if (rsiLine != null) ...[
          const SizedBox(height: 10),
          _rsiPanel(context, rsiLine, labelEvery),
        ],
      ],
    );
  }

  List<FlSpot> _spots(List<double?> values) => [
        for (var i = 0; i < values.length; i++)
          if (values[i] != null) FlSpot(i.toDouble(), values[i]!),
      ];

  LineChartBarData _series(List<FlSpot> spots, Color color, double width) =>
      LineChartBarData(
        spots: spots,
        isCurved: false,
        color: color,
        barWidth: width,
        dotData: const FlDotData(show: false),
      );

  Widget _xTitle(
    double v,
    TitleMeta meta,
    ColorScheme scheme,
    int labelEvery, {
    bool show = true,
  }) {
    if (!show) return const SizedBox.shrink();
    final idx = v.toInt();
    if (idx % labelEvery != 0 || idx < 0 || idx >= points.length) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        fmtDateShort(points[idx].date),
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _legend(ColorScheme scheme, List<(Color, String)> items) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final (c, l) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  l,
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _panelHeader(ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _macdPanel(
    BuildContext context,
    MacdResult m,
    int labelEvery, {
    required bool bottomDates,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final values = <double>[
      for (final v in m.macd)
        if (v != null) v,
      for (final v in m.signal)
        if (v != null) v,
      for (final v in m.histogram)
        if (v != null) v,
    ];
    if (values.isEmpty) return const SizedBox.shrink();
    final hi = values.reduce((a, b) => a > b ? a : b);
    final lo = values.reduce((a, b) => a < b ? a : b);
    final pad = (hi - lo) == 0 ? (hi.abs() * 0.1 + 0.01) : (hi - lo) * 0.15;

    final macdBars = _series(_spots(m.macd), _sma20Color, 1.4);
    final signalBars = _series(_spots(m.signal), _sma50Color, 1.2);
    final histBars = LineChartBarData(
      spots: _spots(m.histogram),
      isCurved: false,
      color: scheme.outlineVariant.withOpacity(0.6),
      barWidth: 1,
      dotData: const FlDotData(show: false),
      aboveBarData: BarAreaData(
        show: true,
        applyCutOffY: true,
        cutOffY: 0,
        color: const Color(0xFF16A34A).withOpacity(0.25),
      ),
      belowBarData: BarAreaData(
        show: true,
        applyCutOffY: true,
        cutOffY: 0,
        color: const Color(0xFFDC2626).withOpacity(0.25),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _panelHeader(scheme, 'MACD (12, 26, 9)'),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
          child: SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: lo - pad,
                maxY: hi + pad,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      reservedSize: 44,
                      showTitles: showYAxis,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          v == 0
                              ? '0'
                              : v.abs() >= 10
                                  ? v.toStringAsFixed(0)
                                  : v.toStringAsFixed(2),
                          style: TextStyle(
                              fontSize: 9, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: bottomDates,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) => _xTitle(
                        v, meta, scheme, labelEvery,
                        show: bottomDates,
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: scheme.outlineVariant,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${_macdLabels[s.barIndex]} ${s.y.toStringAsFixed(2)}',
                          TextStyle(
                            color: scheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [histBars, macdBars, signalBars],
              ),
            ),
          ),
        ),
        _legend(scheme, [
          (_sma20Color, 'MACD'),
          (_sma50Color, 'Signal'),
          (const Color(0xFF16A34A), 'Hist +'),
          (const Color(0xFFDC2626), 'Hist -'),
        ]),
      ],
    );
  }

  Widget _rsiPanel(BuildContext context, List<double?> r, int labelEvery) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _panelHeader(scheme, 'RSI (14)'),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
          child: SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: showYAxis,
                      reservedSize: 44,
                      interval: 50,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          v.toInt().toString(),
                          style: TextStyle(
                              fontSize: 9, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, meta) =>
                          _xTitle(v, meta, scheme, labelEvery),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 70,
                      color: const Color(0xFFDC2626).withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    HorizontalLine(
                      y: 30,
                      color: const Color(0xFF16A34A).withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          '${fmtDateShort(points[s.x.toInt()].date)}\nRSI ${s.y.toStringAsFixed(1)}',
                          TextStyle(
                            color: scheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  _series(_spots(r), _rsiColor, 1.6),
                ],
              ),
            ),
          ),
        ),
        _legend(scheme, [
          (_rsiColor, 'RSI'),
          (const Color(0xFFDC2626).withOpacity(0.7), 'Overbought 70'),
          (const Color(0xFF16A34A).withOpacity(0.7), 'Oversold 30'),
        ]),
      ],
    );
  }
}
