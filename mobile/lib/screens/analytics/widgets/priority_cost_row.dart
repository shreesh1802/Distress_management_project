import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class PriorityCount {
  const PriorityCount(this.name, this.count);
  final String name;
  final int count;
}

class CostRow {
  const CostRow({required this.name, required this.estimated, required this.average, required this.highest});
  final String name;
  final int estimated;
  final int average;
  final int highest;
}

/// Direct port of AnalyticsDashboard.tsx's Row 4: "Priority Index
/// Distribution" (the source's Recharts horizontal bar chart, ported here
/// as labeled progress bars -- the same horizontal-bar approach already
/// used for Maintenance's priority workload chart, since fl_chart has no
/// native horizontal-bar orientation) and "Maintenance Cost Analysis"
/// (grouped bar chart: estimated/average/highest cost per distress class).
class PriorityCostRow extends StatelessWidget {
  const PriorityCostRow({super.key, required this.priorities, required this.costs});

  final List<PriorityCount> priorities;
  final List<CostRow> costs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final priorityCard = _priorityCard();
        final costCard = _costCard();
        if (narrow) {
          return Column(children: [priorityCard, const SizedBox(height: 20), costCard]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: priorityCard),
            const SizedBox(width: 24),
            Expanded(flex: 6, child: costCard),
          ],
        );
      },
    );
  }

  Widget _priorityCard() {
    final hasData = priorities.any((p) => p.count > 0);
    final maxVal = priorities.fold(1, (a, b) => a > b.count ? a : b.count);
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
          const Text('Priority Index Distribution', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (!hasData)
            const SizedBox(
              height: 200,
              child: Center(child: Text('No data available', style: TextStyle(fontSize: 13, color: AppColors.secondaryText))),
            )
          else
            for (final p in priorities)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.count / maxVal,
                          minHeight: 16,
                          backgroundColor: AppColors.primaryBg,
                          valueColor: const AlwaysStoppedAnimation(AppColors.accentBlue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 24, child: Text('${p.count}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _costCard() {
    final maxY = costs.isEmpty
        ? 1.0
        : costs
            .map((c) => [c.estimated, c.average, c.highest].reduce((a, b) => a > b ? a : b))
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
          const Text('Maintenance Cost Analysis (₹ in Thousands)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: costs.isEmpty
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
                              if (i < 0 || i >= costs.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(costs[i].name, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < costs.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(toY: costs[i].estimated.toDouble(), color: AppColors.accentBlue, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                              BarChartRodData(toY: costs[i].average.toDouble(), color: AppColors.success, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                              BarChartRodData(toY: costs[i].highest.toDouble(), color: AppColors.danger, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            alignment: WrapAlignment.center,
            children: const [
              _LegendDot(color: AppColors.accentBlue, label: 'Estimated Cost'),
              _LegendDot(color: AppColors.success, label: 'Average Cost'),
              _LegendDot(color: AppColors.danger, label: 'Highest Cost'),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
      ],
    );
  }
}
