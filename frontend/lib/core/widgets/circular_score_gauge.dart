import 'dart:math';
import 'package:flutter/material.dart';

class CircularScoreGauge extends StatefulWidget {
  final int score;
  final int maxScore;
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final String label;
  final String statusText;
  final Color statusTextColor;
  final bool isAnalyzing;

  const CircularScoreGauge({
    super.key,
    required this.score,
    this.maxScore = 100,
    this.size = 130,
    this.strokeWidth = 12,
    this.trackColor = const Color(0xFFE2E8F0),
    this.progressColor = const Color(0xFF22C55E),
    this.label = '',
    this.statusText = '',
    this.statusTextColor = const Color(0xFF22C55E),
    this.isAnalyzing = false,
  });

  @override
  State<CircularScoreGauge> createState() => _CircularScoreGaugeState();
}

class _CircularScoreGaugeState extends State<CircularScoreGauge> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.isAnalyzing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CircularScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnalyzing != oldWidget.isAnalyzing) {
      if (widget.isAnalyzing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
        _rotationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTrackColor = isDark ? const Color(0xFF334155) : widget.trackColor;
    final double targetPercentage = (widget.score / widget.maxScore).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. ROTATING SCANNER ARC WHEN ANALYZING
              if (widget.isAnalyzing)
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * pi,
                      child: CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: _ScanningArcPainter(
                          strokeWidth: widget.strokeWidth,
                          trackColor: effectiveTrackColor,
                          scanColor: const Color(0xFF6366F1),
                        ),
                      ),
                    );
                  },
                )
              // 2. SMOOTHLY ANIMATED PROGRESS GAUGE WHEN NOT ANALYZING
              else
                TweenAnimationBuilder<double>(
                  key: ValueKey('score_${widget.score}'),
                  tween: Tween<double>(begin: 0.0, end: targetPercentage),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, child) {
                    final int displayedScore = (animValue * widget.maxScore).round();
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size(widget.size, widget.size),
                          painter: _GaugePainter(
                            percentage: animValue,
                            strokeWidth: widget.strokeWidth,
                            trackColor: effectiveTrackColor,
                            progressColor: widget.score == 0
                                ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                                : widget.progressColor,
                          ),
                        ),
                        // Center Score text counting up
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$displayedScore',
                                  style: TextStyle(
                                    fontSize: widget.size * 0.28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                    color: widget.score == 0
                                        ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  '/${widget.maxScore}',
                                  style: TextStyle(
                                    fontSize: widget.size * 0.13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

              // Center content when analyzing
              if (widget.isAnalyzing)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF6366F1),
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Scanning...",
                      style: TextStyle(
                        fontSize: widget.size * 0.11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Status Text & Label below the circle
        if (widget.isAnalyzing) ...[
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
              ),
              SizedBox(width: 6),
              Text(
                "AI Analyzing...",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Extracting ATS metrics & skills",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          if (widget.statusText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.statusText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: widget.score == 0
                    ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
                    : widget.statusTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percentage;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;

  _GaugePainter({
    required this.percentage,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Draw Background Track Circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (percentage > 0.001) {
      // Draw Progress Arc starting from top (-pi / 2)
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * percentage;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _ScanningArcPainter extends CustomPainter {
  final double strokeWidth;
  final Color trackColor;
  final Color scanColor;

  _ScanningArcPainter({
    required this.strokeWidth,
    required this.trackColor,
    required this.scanColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Glowing rotating scan head
    final scanPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          scanColor.withValues(alpha: 0.0),
          scanColor.withValues(alpha: 0.3),
          scanColor,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5 * pi,
      false,
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanningArcPainter oldDelegate) => false;
}
