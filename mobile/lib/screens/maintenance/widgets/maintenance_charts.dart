import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../combined_task.dart';

/// Direct port of the "Priority Workload Distribution" bar chart and
/// "Operations Stage Allocation" pie chart at the bottom of
/// MaintenanceDashboard.tsx.
class MaintenanceCharts extends StatelessWidget {
  const MaintenanceCharts({super.key, required this.tasks});

  final List<CombinedTask> tasks;

  @override
  Widget build(BuildContext context) {
    final priorityCounts = {'Critical': 0, 'High': 0, 'Medium': 0, 'Low': 0};
    for (final t in tasks) {
      if (priorityCounts.containsKey(t.priority)) priorityCounts[t.priority] = priorityCounts[t.priority]! + 1;
    }
    final statusCounts = {'Pending': 0, 'Assigned': 0, 'In Progress': 0, 'Completed': 0, 'Closed': 0};
    for (final t in tasks) {
      if (statusCounts.containsKey(t.status)) statusCounts[t.status] = statusCounts[t.status]! + 1;
    }
    final activeStatus = statusCounts.entries.where((e) => e.value > 0).toList();
    final maxPriority = priorityCounts.values.fold(1, (a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final bar = _priorityCard(priorityCounts, maxPriority);
        final pie = _statusCard(activeStatus);
        if (narrow) {
          return Column(children: [bar, const SizedBox(height: 24), pie]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: bar),
            const SizedBox(width: 24),
            Expanded(flex: 5, child: pie),
          ],
        );
      },
    );
  }

  Widget _priorityCard(Map<String, int> counts, int max) {
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
          const Text('Priority Workload Distribution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          for (final entry in counts.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(width: 80, child: Text(entry.key, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontWeight: FontWeight.w600))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value / max,
                        minHeight: 8,
                        backgroundColor: AppColors.primaryBg,
                        valueColor: AlwaysStoppedAnimation(Color(priorityColors[entry.key] ?? 0xFFCCCCCC)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 30, child: Text('${entry.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusCard(List<MapEntry<String, int>> active) {
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
          const Text('Operations Stage Allocation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: active.isEmpty
                ? const Center(child: Text('No Data', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)))
                : Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 36,
                            sections: [
                              for (final e in active)
                                PieChartSectionData(
                                  value: e.value.toDouble(),
                                  color: Color(statusColors[e.key] ?? 0xFFCCCCCC),
                                  title: '',
                                  radius: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final e in active)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(statusColors[e.key] ?? 0xFFCCCCCC), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                  ],
                                ),
                              ),
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
}
