import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

const kHistoryPieColors = [
  Color(0xFF6B88C7),
  Color(0xFF7B8260),
  Color(0xFF8FA06A),
  Color(0xFFD6A23A),
  Color(0xFFC87B35),
  Color(0xFFC45C45),
];

/// Direct port of History.tsx's "System Statistics" widget: real
/// success/failed operation counts (from the full, unfiltered activity
/// list) plus two single hardcoded fallback fields the source itself never
/// computes from real data (`processingTime`/`avgRuntime`).
///
/// Trimmed: the "Recent Active Users" widget below it in the source -- a
/// fully static array of 4 fabricated names/roles/timestamps with zero
/// backend tie, unlike the deterministic-fake-but-DB-id-derived user names
/// used elsewhere in this screen.
class SystemStatisticsCard extends StatelessWidget {
  const SystemStatisticsCard({
    super.key,
    required this.successOps,
    required this.failedOps,
    required this.successRate,
  });

  final int successOps;
  final int failedOps;
  final String successRate;

  static const _processingTime = '4.8s / frame';
  static const _avgRuntime = '48.2s';

  @override
  Widget build(BuildContext context) {
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
          const Text('System Statistics', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statBox('Successful Operations', '$successOps', AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _statBox('Failed Operations', '$failedOps', AppColors.danger)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statBox('Processing Time', _processingTime, AppColors.primaryText)),
              const SizedBox(width: 10),
              Expanded(child: _statBox('Average Runtime', _avgRuntime, AppColors.primaryText)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Success Rate', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
              Text('$successRate%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (double.tryParse(successRate) ?? 100) / 100,
              minHeight: 8,
              backgroundColor: AppColors.primaryBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// Direct port of History.tsx's "System Activity Distribution" pie chart
/// widget: a per-category donut of the filtered timeline plus a legend.
class ActivityDistributionCard extends StatelessWidget {
  const ActivityDistributionCard({super.key, required this.data});

  /// category -> count, source order (Inference, Reports, Uploads).
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => e.value > 0).toList();
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
          const Text('System Activity Distribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No distribution data.', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))),
            )
          else ...[
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: kHistoryPieColors[i % kHistoryPieColors.length],
                        title: '',
                        radius: 22,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: kHistoryPieColors[i % kHistoryPieColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('${entries[i].key} (${entries[i].value})', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
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
