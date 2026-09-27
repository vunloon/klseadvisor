import 'dart:math' as math;

/// Pure technical-indicator math.
/// Every function returns a list aligned 1:1 with the input series; leading
/// values that cannot be computed yet are `null`.

List<double?> sma(List<double> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length < period) return out;
  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= period) sum -= values[i - period];
    if (i >= period - 1) out[i] = sum / period;
  }
  return out;
}

/// Exponential moving average. Seeds with the SMA of the first `period`
/// consecutive non-null values, then applies the standard EMA recursion.
List<double?> ema(List<double?> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0) return out;
  final k = 2 / (period + 1);
  double? prev;
  var count = 0;
  var sum = 0.0;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v == null) {
      count = 0;
      sum = 0;
      continue;
    }
    if (prev == null) {
      sum += v;
      count++;
      if (count == period) {
        prev = sum / period;
        out[i] = prev;
      }
    } else {
      prev = prev * (1 - k) + v * k;
      out[i] = prev;
    }
  }
  return out;
}

class BollingerBands {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;
  const BollingerBands({
    required this.upper,
    required this.middle,
    required this.lower,
  });
}

/// Classic Bollinger Bands: SMA(period) +/- mult * population stddev.
BollingerBands bollinger(
  List<double> values, {
  int period = 20,
  double mult = 2,
}) {
  final mid = sma(values, period);
  final upper = List<double?>.filled(values.length, null);
  final lower = List<double?>.filled(values.length, null);
  for (var i = period - 1; i < values.length; i++) {
    final m = mid[i];
    if (m == null) continue;
    var variance = 0.0;
    for (var j = i - period + 1; j <= i; j++) {
      final d = values[j] - m;
      variance += d * d;
    }
    final sd = math.sqrt(variance / period);
    upper[i] = m + mult * sd;
    lower[i] = m - mult * sd;
  }
  return BollingerBands(upper: upper, middle: mid, lower: lower);
}

class MacdResult {
  final List<double?> macd;
  final List<double?> signal;
  final List<double?> histogram;
  const MacdResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });
}

/// MACD = EMA(fast) - EMA(slow); signal = EMA(signalPeriod) of MACD;
/// histogram = MACD - signal.
MacdResult macd(
  List<double> values, {
  int fast = 12,
  int slow = 26,
  int signalPeriod = 9,
}) {
  final fastEma = ema(values, fast);
  final slowEma = ema(values, slow);
  final macdLine = List<double?>.filled(values.length, null);
  for (var i = 0; i < values.length; i++) {
    final f = fastEma[i];
    final s = slowEma[i];
    if (f != null && s != null) macdLine[i] = f - s;
  }
  final signalLine = ema(macdLine, signalPeriod);
  final hist = List<double?>.filled(values.length, null);
  for (var i = 0; i < values.length; i++) {
    final m = macdLine[i];
    final s = signalLine[i];
    if (m != null && s != null) hist[i] = m - s;
  }
  return MacdResult(macd: macdLine, signal: signalLine, histogram: hist);
}

/// Wilder's RSI. Values in 0..100; 100 when there are no losses in the window.
List<double?> rsi(List<double> values, {int period = 14}) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length <= period) return out;
  var gain = 0.0;
  var loss = 0.0;
  for (var i = 1; i <= period; i++) {
    final ch = values[i] - values[i - 1];
    if (ch >= 0) {
      gain += ch;
    } else {
      loss -= ch;
    }
  }
  var avgGain = gain / period;
  var avgLoss = loss / period;
  out[period] = _rsiValue(avgGain, avgLoss);
  for (var i = period + 1; i < values.length; i++) {
    final ch = values[i] - values[i - 1];
    final g = ch > 0 ? ch : 0.0;
    final l = ch < 0 ? -ch : 0.0;
    avgGain = (avgGain * (period - 1) + g) / period;
    avgLoss = (avgLoss * (period - 1) + l) / period;
    out[i] = _rsiValue(avgGain, avgLoss);
  }
  return out;
}

double _rsiValue(double avgGain, double avgLoss) {
  if (avgLoss == 0) return avgGain == 0 ? 50 : 100;
  return 100 - 100 / (1 + avgGain / avgLoss);
}
