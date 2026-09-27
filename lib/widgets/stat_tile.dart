import 'package:flutter/material.dart';


class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const StatTile({super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 44});

  Color get _color {
    if (score >= 70) return const Color(0xFF16A34A);
    if (score >= 45) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              strokeWidth: 4,
              strokeCap: StrokeCap.round,
              color: _color,
              backgroundColor: _color.withOpacity(0.15),
            ),
          ),
          Text(
            score.round().toString(),
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class FlagChip extends StatelessWidget {
  final String label;
  final bool positive;

  const FlagChip({super.key, required this.label, required this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: positive
            ? Colors.green.withOpacity(0.12)
            : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: positive
              ? Colors.green.shade700
              : Colors.red.shade700,
        ),
      ),
    );
  }
}

String recommendationLabel(String? key) {
  switch (key) {
    case 'strongBuy':
      return 'Strong Buy';
    case 'buy':
      return 'Buy';
    case 'hold':
      return 'Hold';
    case 'underperform':
      return 'Underperform';
    case 'sell':
      return 'Sell';
    default:
      return 'N/A';
  }
}
