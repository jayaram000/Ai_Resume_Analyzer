import 'package:flutter/material.dart';

class ProgressBarRow extends StatelessWidget {
  final String label;
  final int percentage;
  final Color barColor;

  const ProgressBarRow({
    super.key,
    required this.label,
    required this.percentage,
    this.barColor = const Color(0xFF22C55E),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: (percentage / 100.0).clamp(0.0, 1.0),
                  backgroundColor: trackColor,
                  color: barColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '$percentage%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
