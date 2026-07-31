import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'notifications_sidebar_widgets.dart' show kNotificationsPieColors;

class TrendPoint {
  const TrendPoint(this.label, this.alerts, this.detections);
  final String label;
  final int alerts;
  final int detections;
}

/// Direct port of Notifications.tsx's Row 7 bottom analytics: "Alert Rate
/// Trend" (hourly line chart, hardcoded synthetic data except the last
/// point which uses the real `todayCount`), "Distribution Ratio" (the same
/// category donut as the sidebar, first 3 legend entries), and "Average
/// Mitigation Time" (a hardcoded-per-category bar chart -- this whole
/// screen is a mock/demo screen in the source, see
/// notification_item.dart's doc comment).
class NotificationsAnalyticsFooter extends StatelessWidget {
  const NotificationsAnalyticsFooter({super.key, required this.trend, required this.categoryData});

  final List<TrendPoint> trend;
  final Map<String, int> categoryData;

  static const _resolutionTimeData = [
    ('Detection', 1.5),
    ('Maintenance', 4.2),
    ('Reports', 0.1),
    ('System', 0.5),
    ('GIS', 2.8),
    ('Uploads', 0.8),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 1100;
        final trendCard = _trendCard();
        final donutCard = _donutCard();
        final barCard = _barCard();
        if (narrow) {
          return Column(children: [trendCard, const SizedBox(height: 20), donutCard, const SizedBox(height: 20), barCard]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: trendCard),
            const SizedBox(width: 20),
            Expanded(child: donutCard),
            const SizedBox(width: 20),
            Expanded(child: barCard),
          ],
        );
      },
    );
  }

  Widget _cardShell({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _trendCard() {
    return _cardShell(
      title: 'Alert Rate Trend',
      subtitle: 'Line graph of hourly logged incident alerts',
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(trend[i].label, style: const TextStyle(fontSize: 8, color: AppColors.secondaryText)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i].alerts.toDouble())],
                isCurved: true,
                color: const Color(0xFFEF4444),
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i].detections.toDouble())],
                isCurved: true,
                color: const Color(0xFF3B82F6),
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _donutCard() {
    final entries = categoryData.entries.where((e) => e.value > 0).toList();
    return _cardShell(
      title: 'Distribution Ratio',
      subtitle: 'Relative classification of operations events',
      child: entries.isEmpty
          ? const SizedBox(height: 150, child: Center(child: Text('No data', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))))
          : Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 30,
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(value: entries[i].value.toDouble(), color: kNotificationsPieColors[i % kNotificationsPieColors.length], title: '', radius: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < entries.length && i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: kNotificationsPieColors[i % kNotificationsPieColors.length], shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('${entries[i].key}: ', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                              Text('${entries[i].value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _barCard() {
    final maxVal = _resolutionTimeData.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return _cardShell(
      title: 'Average Mitigation Time',
      subtitle: 'Standard resolution time (in hours) per category',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxVal * 1.2,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) => Text('${v.toInt()}h', style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= _resolutionTimeData.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_resolutionTimeData[i].$1, style: const TextStyle(fontSize: 8, color: AppColors.secondaryText)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < _resolutionTimeData.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _resolutionTimeData[i].$2,
                      color: const Color(0xFF10B981),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
