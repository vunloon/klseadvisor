import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klse_advisor/services/yahoo_finance_service.dart';
import 'package:klse_advisor/util/indicators.dart';
import 'package:klse_advisor/widgets/price_chart.dart';

void main() {
  group('sma', () {
    test('returns null until enough data', () {
      final r = sma([1, 2, 3, 4, 5], 3);
      expect(r, [null, null, 2, 3, 4]);
    });
    test('insufficient data', () {
      expect(sma([1, 2], 5), everyElement(isNull));
    });
  });

  group('ema', () {
    test('seeds with sma then recursive', () {
      final r = ema([1, 2, 3, 4, 5], 3);
      expect(r, [null, null, 2, 3, 4]);
    });
    test('handles null prefix (macd alignment)', () {
      final r = ema([null, null, 1, 2, 3], 2);
      expect(r[3], closeTo(1.5, 1e-9));
      expect(r[4], closeTo(2.5, 1e-9));
      expect(r[2], isNull);
    });
  });

  group('bollinger', () {
    test('bands are sma +/- mult * stddev', () {
      final bb = bollinger([2, 4, 6, 8, 10], period: 3, mult: 2);
      expect(bb.middle, [null, null, 4, 6, 8]);
      const sd = 1.6329931618554521;
      expect(bb.upper[2]!, closeTo(4 + 2 * sd, 1e-9));
      expect(bb.lower[2]!, closeTo(4 - 2 * sd, 1e-9));
      expect(bb.upper[3]!, closeTo(6 + 2 * sd, 1e-9));
      expect(bb.lower[4]!, closeTo(8 - 2 * sd, 1e-9));
    });
  });

  group('macd', () {
    test('macd = ema(fast) - ema(slow), signal = ema of macd', () {
      // Linear series: ema3[i] = i (i>=2), ema5[i] = i-1 (i>=5).
      final r = macd([1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          fast: 3, slow: 5, signalPeriod: 2);
      expect(r.macd[3], isNull);
      expect(r.macd[4], closeTo(1, 1e-9));
      expect(r.macd[6], closeTo(1, 1e-9));
      expect(r.signal[4], isNull);
      expect(r.signal[5], closeTo(1, 1e-9));
      expect(r.histogram[6], closeTo(0, 1e-9));
    });
  });

  group('rsi', () {
    test('wilder smoothing on hand-computed series', () {
      final r = rsi([10, 12, 11, 13, 12, 14], period: 3);
      expect(r[2], isNull);
      expect(r[3]!, closeTo(80, 1e-9));
      expect(r[4]!, closeTo(61.538461538, 1e-6));
      expect(r[5]!, closeTo(77.272727273, 1e-6));
    });
    test('monotonic series saturates', () {
      final up = rsi([1, 2, 3, 4, 5, 6], period: 3);
      final down = rsi([6, 5, 4, 3, 2, 1], period: 3);
      expect(up.last, 100);
      expect(down.last, 0);
    });
    test('flat series is neutral', () {
      final r = rsi([5, 5, 5, 5, 5], period: 3);
      expect(r.last, 50);
    });
  });

  testWidgets('PriceChart renders active indicator panels and legend',
      (tester) async {
    final points = [
      for (var i = 0; i < 60; i++)
        ChartPoint(
          date: DateTime(2024, 1, 1).add(Duration(days: i)),
          close: 10 + i * 0.1,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PriceChart(
              points: points,
              indicators: const {
                ChartIndicator.sma20,
                ChartIndicator.macd,
                ChartIndicator.rsi,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SMA 20'), findsWidgets);
    expect(find.text('MACD (12, 26, 9)'), findsOneWidget);
    expect(find.text('RSI (14)'), findsOneWidget);
    expect(find.text('Overbought 70'), findsOneWidget);
  });

  testWidgets('PriceChart hides disabled panels', (tester) async {
    final points = [
      for (var i = 0; i < 30; i++)
        ChartPoint(
          date: DateTime(2024, 1, 1).add(Duration(days: i)),
          close: 10 + i * 0.2,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PriceChart(points: points),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MACD (12, 26, 9)'), findsNothing);
    expect(find.text('RSI (14)'), findsNothing);
  });
}
