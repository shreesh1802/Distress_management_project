import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

const kAnalyticsChartColors = [
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF06B6D4),
  Color(0xFF10B981),
];

/// Direct port of AnalyticsDashboard.tsx's "Distress Classification" donut
/// chart card: a donut with a centered total count and a wrapped legend.
/// The PNG-export and fullscreen-expand buttons the source puts in this
/// card's header are dropped -- see the screen's doc comment for why.
class DistressDonutCard extends StatelessWidget {
  const DistressDonutCard({super.key, required this.data});

  /// name -> count, in the source's insertion order (first-seen distress type).
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);
    final entries = data.entries.toList();

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
          const Text('Distress Classification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const SizedBox(
              height: 220,
              child: Center(child: Text('No data available', style: TextStyle(fontSize: 13, color: AppColors.secondaryText))),
            )
          else ...[
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          PieChartSectionData(
                            value: entries[i].value.toDouble(),
                            color: kAnalyticsChartColors[i % kAnalyticsChartColors.length],
                            title: '',
                            radius: 25,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const Text('TOTAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: kAnalyticsChartColors[i % kAnalyticsChartColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('${entries[i].key}: ', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                      Text('${entries[i].value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
