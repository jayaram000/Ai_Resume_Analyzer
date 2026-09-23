import 'dart:math';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_typography.dart';

/// "Casefile" Score Stamp widget.
///
/// Replaces circular progress gauges with an authentic inked dossier approval stamp:
/// - Circle with a 2px dashed border in semantic color:
///   - `forest` (score ≥ 70)
///   - `ochre` (50 ≤ score < 70)
///   - `brick` (score < 50)
/// - Rotated -6° for that stamped paper feel.
/// - Score number in bold JetBrains Mono.
/// - Lowercase label underneath (e.g. "ats score", "match fit").
class ScoreStamp extends StatelessWidget {
  final int score;
  final int maxScore;
  final String label;
  final double size;
  final bool isAnalyzing;
  final String? subtitle;

  const ScoreStamp({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.label = "ats score",
    this.size = 110,
    this.isAnalyzing = false,
    this.subtitle,
  });

  Color _resolveSemanticColor(bool isDark) {
    if (score >= 70) {
      return AppColors.resolveForest(isDark);
    } else if (score >= 50) {
      return AppColors.resolveOchre(isDark);
    } else {
      return AppColors.resolveBrick(isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stampColor = _resolveSemanticColor(isDark);
    final cobalt = AppColors.resolveCobalt(isDark);
    final inkSoft = AppColors.resolveInkSoft(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The stamped circle rotated -6 degrees
        Transform.rotate(
          angle: -6.0 * (pi / 180.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stampColor.withValues(alpha: 0.04),
            ),
            child: CustomPaint(
              painter: _DashedCirclePainter(
                color: isAnalyzing ? cobalt : stampColor,
                strokeWidth: 2.0,
                dashLength: 6.0,
                gapLength: 4.0,
              ),
              child: Center(
                child: isAnalyzing
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: size * 0.22,
                            height: size * 0.22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: cobalt,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "auditing...",
                            style: AppTypography.monoLabel(
                              color: cobalt,
                              fontSize: size * 0.09,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            score > 0 ? '$score' : '--',
                            style: AppTypography.monoScore(
                              color: stampColor,
                              fontSize: size * 0.32,
                            ).copyWith(height: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label.toLowerCase(),
                            textAlign: TextAlign.center,
                            style: AppTypography.monoLabel(
                              color: stampColor,
                              fontSize: size * 0.095,
                            ).copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        // Optional subtitle below stamp
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: AppTypography.bodyRegular(
              color: inkSoft,
              fontSize: 11.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final radius = (min(size.width, size.height) - strokeWidth) / 2.0;
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final circumference = 2 * pi * radius;

    final double dashAngle = (dashLength / circumference) * 2 * pi;
    final double gapAngle = (gapLength / circumference) * 2 * pi;

    double currentAngle = 0.0;
    while (currentAngle < 2 * pi) {
      final double sweep = min(dashAngle, 2 * pi - currentAngle);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        false,
        paint,
      );
      currentAngle += dashAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}
