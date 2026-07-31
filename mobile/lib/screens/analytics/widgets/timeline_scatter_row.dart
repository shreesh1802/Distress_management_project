import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import 'severity_stacked_card.dart' show kAnalyticsSeverityColors;

class TimelinePoint {
  const TimelinePoint(this.label, this.detections);
  final String label;
  final int detections;
}

class ScatterPoint {
  const ScatterPoint({required this.area, required this.impact, required this.severity});
  final double area;
  final double impact;
  final String severity;
}

/// Direct port of AnalyticsDashboard.tsx's Row 5: "Detection Frequency
/// Timeline" (a daily/weekly/monthly line chart) and "Damage Area vs Health
/// Impact Analysis" (a scatter plot colored by severity).
class TimelineScatterRow extends StatelessWidget {
  const TimelineScatterRow({
    super.key,
    required this.timeline,
    required this.period,
    required this.onPeriodChanged,
    required this.scatter,
  });

  final List<TimelinePoint> timeline;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final List<ScatterPoint> scatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final timelineCard = _timelineCard();
        final scatterCard = _scatterCard();
        if (narrow) {
          return Column(children: [timelineCard, const SizedBox(height: 20), scatterCard]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: timelineCard),
            const SizedBox(width: 24),
            Expanded(flex: 5, child: scatterCard),
          ],
        );
      },
    );
  }

  Widget _timelineCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.trendingUp, size: 16, color: AppColors.accentBlue),
                  SizedBox(width: 8),
                  Text('Detection Frequency Timeline', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in ['daily', 'weekly', 'monthly'])
                      InkWell(
                        onTap: () => onPeriodChanged(p),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: period == p ? AppColors.accentBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: period == p ? Colors.white : AppColors.primaryText),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: timeline.isEmpty
                ? const Center(child: Text('No data available', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, meta) =>
                                Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= timeline.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(timeline[i].label, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < timeline.length; i++) FlSpot(i.toDouble(), timeline[i].detections.toDouble())],
                          isCurved: true,
                          color: AppColors.accentBlue,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _scatterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Damage Area vs Health Impact Analysis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: scatter.isEmpty
                ? const Center(child: Text('No data available', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)))
                : ScatterChart(
                    ScatterChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (v, meta) =>
                                Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (v, meta) =>
                                Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                          ),
                        ),
                      ),
                      scatterSpots: [
                        for (final p in scatter)
                          ScatterSpot(
                            p.area,
                            p.impact,
                            dotPainter: FlDotCirclePainter(
                              color: kAnalyticsSeverityColors[p.severity.toLowerCase()] ?? AppColors.accentBlue,
                              radius: 5,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
