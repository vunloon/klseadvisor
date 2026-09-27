import 'package:intl/intl.dart';

final NumberFormat _moneyFmt = NumberFormat('#,##0.00');
final NumberFormat _intFmt = NumberFormat('#,##0');

String fmtMoney(num? v, {String currency = 'RM'}) {
  if (v == null) return 'N/A';
  return '$currency ${_moneyFmt.format(v)}';
}

String fmtNum(num? v, {int digits = 2}) {
  if (v == null) return 'N/A';
  return v.toStringAsFixed(digits);
}

String fmtPct(num? v, {bool signed = true}) {
  if (v == null) return 'N/A';
  final sign = signed && v > 0 ? '+' : '';
  return '$sign${v.toStringAsFixed(2)}%';
}

String fmtCompact(num? v) {
  if (v == null) return 'N/A';
  final d = v.toDouble();
  final abs = d.abs();
  if (abs >= 1e12) return '${(d / 1e12).toStringAsFixed(2)}T';
  if (abs >= 1e9) return '${(d / 1e9).toStringAsFixed(2)}B';
  if (abs >= 1e6) return '${(d / 1e6).toStringAsFixed(2)}M';
  if (abs >= 1e3) return '${(d / 1e3).toStringAsFixed(1)}K';
  return _intFmt.format(d);
}

String fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

String fmtDateShort(DateTime d) => DateFormat('dd MMM yy').format(d);

String marketStateLabel(String? state) {
  switch (state) {
    case 'REGULAR':
      return 'Open';
    case 'PRE':
    case 'PREPRE':
      return 'Pre';
    case 'POST':
    case 'POSTPOST':
      return 'Post';
    case 'CLOSED':
      return 'Closed';
    default:
      return '';
  }
}
