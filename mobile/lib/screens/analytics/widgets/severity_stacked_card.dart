import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

const kAnalyticsSeverityColors = {
  'critical': Color(0xFFEF4444),
  'high': Color(0xFFF97316),
  'medium': Color(0xFFEAB308),
  'low': Color(0xFF10B981),
};

class SeverityRunData {
  const SeverityRunData({required this.name, required this.counts});
  final String name;

  /// Keyed by 'critical'/'high'/'medium'/'low'.
  final Map<String, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

/// Direct port of AnalyticsDashboard.tsx's "Severity Stacked Distribution"
/// bar chart: per-video-run stacked bars by severity, with a total-count
/// label above each bar and a legend that toggles a severity's visibility
/// on click (the source's Recharts `<Legend onClick={handleLegendClick}>`).
class SeverityStackedCard extends StatelessWidget {
  const SeverityStackedCard({
    super.key,
    required this.data,
    required this.hiddenSeverities,
    required this.onToggleSeverity,
  });

  final List<SeverityRunData> data;
  final Set<String> hiddenSeverities;
  final ValueChanged<String> onToggleSeverity;

  static const _order = ['critical', 'high', 'medium', 'low'];

  @override
  Widget build(BuildContext context) {
    final visibleOrder = _order.where((s) => !hiddenSeverities.contains(s)).toList();
    final maxY = data.isEmpty
        ? 1.0
        : data
            .map((d) => visibleOrder.fold(0, (sum, s) => sum + (d.counts[s] ?? 0)))
            .fold(0, (a, b) => a > b ? a : b)
            .toDouble();

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
          const Text('Severity Stacked Distribution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: data.isEmpty
                ? const Center(child: Text('No data available', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)))
                : BarChart(
                    BarChartData(
                      maxY: maxY * 1.15 + 1,
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
                            reservedSize: 28,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= data.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(data[i].name, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            '${data[groupIndex].name}\n${rod.toY.round()}',
                            const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < data.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: visibleOrder.fold(0, (sum, s) => sum + (data[i].counts[s] ?? 0)).toDouble(),
                                width: 32,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                rodStackItems: _stackItems(data[i]),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final s in _order)
                InkWell(
                  onTap: () => onToggleSeverity(s),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: hiddenSeverities.contains(s) ? AppColors.cardBorder : kAnalyticsSeverityColors[s],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          color: hiddenSeverities.contains(s) ? AppColors.secondaryText : AppColors.primaryText,
                          decoration: hiddenSeverities.contains(s) ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<BarChartRodStackItem> _stackItems(SeverityRunData row) {
    final visibleOrder = _order.where((s) => !hiddenSeverities.contains(s)).toList();
    var y = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final s in visibleOrder) {
      final v = (row.counts[s] ?? 0).toDouble();
      if (v <= 0) continue;
      items.add(BarChartRodStackItem(y, y + v, kAnalyticsSeverityColors[s]!));
      y += v;
    }
    return items;
  }
}
