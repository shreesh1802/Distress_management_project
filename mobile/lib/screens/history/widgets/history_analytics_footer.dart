import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class DayCount {
  const DayCount(this.label, this.count);
  final String label;
  final int count;
}

class EventTypeCount {
  const EventTypeCount(this.name, this.count);
  final String name;
  final int count;
}

/// Direct port of History.tsx's bottom analytics row: "Activity Trend"
/// (7-day area chart), "Operation Success Rate" (donut), and "Top Event
/// Types" (horizontal bar, rendered here as labeled progress bars -- same
/// approach already used for Analytics' priority chart, since fl_chart has
/// no native horizontal-bar orientation).
class HistoryAnalyticsFooter extends StatelessWidget {
  const HistoryAnalyticsFooter({
    super.key,
    required this.areaChart,
    required this.successCount,
    required this.failedCount,
    required this.infoWarningCount,
    required this.topEventTypes,
  });

  final List<DayCount> areaChart;
  final int successCount;
  final int failedCount;
  final int infoWarningCount;
  final List<EventTypeCount> topEventTypes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 1100;
        final trend = _trendCard();
        final donut = _donutCard();
        final bar = _barCard();
        if (narrow) {
          return Column(children: [trend, const SizedBox(height: 20), donut, const SizedBox(height: 20), bar]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: trend),
            const SizedBox(width: 20),
            Expanded(child: donut),
            const SizedBox(width: 20),
            Expanded(child: bar),
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
      title: 'Activity Trend',
      subtitle: 'Audit operations count logged over the past 7 days',
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
                    if (i < 0 || i >= areaChart.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(areaChart[i].label, style: const TextStyle(fontSize: 8, color: AppColors.secondaryText)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < areaChart.length; i++) FlSpot(i.toDouble(), areaChart[i].count.toDouble())],
                isCurved: true,
                color: AppColors.accentBlue,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: AppColors.accentBlueLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _donutCard() {
    final total = successCount + failedCount + infoWarningCount;
    return _cardShell(
      title: 'Operation Success Rate',
      subtitle: 'Distribution of successful vs failed system events',
      child: total == 0
          ? const SizedBox(height: 160, child: Center(child: Text('No data', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))))
          : Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 32,
                      sections: [
                        if (successCount > 0) PieChartSectionData(value: successCount.toDouble(), color: AppColors.success, title: '', radius: 20),
                        if (failedCount > 0) PieChartSectionData(value: failedCount.toDouble(), color: AppColors.danger, title: '', radius: 20),
                        if (infoWarningCount > 0) PieChartSectionData(value: infoWarningCount.toDouble(), color: AppColors.warning, title: '', radius: 20),
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
                      if (successCount > 0) _legendRow(AppColors.success, 'Success', successCount),
                      if (failedCount > 0) _legendRow(AppColors.danger, 'Failed', failedCount),
                      if (infoWarningCount > 0) _legendRow(AppColors.warning, 'Info/Warning', infoWarningCount),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legendRow(Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
          Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _barCard() {
    final maxVal = topEventTypes.isEmpty ? 1 : topEventTypes.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return _cardShell(
      title: 'Top Event Types',
      subtitle: 'Most frequently logged operational actions',
      child: topEventTypes.isEmpty
          ? const SizedBox(height: 100, child: Center(child: Text('No data', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))))
          : Column(
              children: [
                for (final e in topEventTypes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(e.name, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.count / maxVal,
                              minHeight: 10,
                              backgroundColor: AppColors.primaryBg,
                              valueColor: const AlwaysStoppedAnimation(AppColors.accentBlue),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 20, child: Text('${e.count}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
