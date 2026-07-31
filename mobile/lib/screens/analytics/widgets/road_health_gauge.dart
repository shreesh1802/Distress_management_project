import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Direct port of AnalyticsDashboard.tsx's "Road Health Gauge" card: an SVG
/// circular dial (ported here via a `CustomPainter` arc) showing the
/// animated count-up health score, plus the 4-band condition legend.
class RoadHealthGauge extends StatelessWidget {
  const RoadHealthGauge({super.key, required this.score, required this.color, required this.label});

  final int score;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Road Health Gauge', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _GaugePainter(score: score, color: color),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
                    const Text('CONDITION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
                    Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: const [
              _LegendDot(color: Color(0xFFEF4444), label: 'Critical (<60)'),
              _LegendDot(color: Color(0xFFF97316), label: 'Fair (60-79)'),
              _LegendDot(color: Color(0xFF8FA06A), label: 'Good (80-94)'),
              _LegendDot(color: Color(0xFF10B981), label: 'Excellent (95-100)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    final trackPaint = Paint()
      ..color = AppColors.cardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * (score.clamp(0, 100) / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
