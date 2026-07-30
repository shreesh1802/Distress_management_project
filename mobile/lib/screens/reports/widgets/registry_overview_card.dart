import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/reports_api.dart';
import '../../../theme/app_colors.dart';

/// Direct port of ReportsDashboard.tsx's "Registry Overview" card: the
/// distress-classification pie chart (computed from `filteredReports`, with
/// the source's own hardcoded non-zero fallback minimums so no slice ever
/// shows a true zero), the severity breakdown bars (computed from *all*
/// `reports`, not the filtered list -- a faithfully-preserved quirk of the
/// React source), and the static database-sync-status block.
class RegistryOverviewCard extends StatelessWidget {
  const RegistryOverviewCard({super.key, required this.allReports, required this.filteredReports});

  final List<ReportItem> allReports;
  final List<ReportItem> filteredReports;

  static const _pieColors = {
    'Potholes': 0xFFEF4444,
    'Cracks': 0xFFF97316,
    'Rutting': 0xFFFACC15,
    'Patches': 0xFF10B981,
  };

  Map<String, int> get _pieCounts {
    final counts = {'Potholes': 0, 'Cracks': 0, 'Rutting': 0, 'Patches': 0};
    for (final r in filteredReports) {
      final type = r.distressType.toLowerCase();
      if (type.contains('pothole')) {
        counts['Potholes'] = counts['Potholes']! + 1;
      } else if (type.contains('crack')) {
        counts['Cracks'] = counts['Cracks']! + 1;
      } else if (type.contains('rutting')) {
        counts['Rutting'] = counts['Rutting']! + 1;
      } else {
        counts['Patches'] = counts['Patches']! + 1;
      }
    }
    return {
      'Potholes': counts['Potholes'] != 0 ? counts['Potholes']! : 3,
      'Cracks': counts['Cracks'] != 0 ? counts['Cracks']! : 4,
      'Rutting': counts['Rutting'] != 0 ? counts['Rutting']! : 1,
      'Patches': counts['Patches'] != 0 ? counts['Patches']! : 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pieCounts = _pieCounts;

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
          const Text('Registry Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Text('DISTRESS CLASSIFICATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
          const SizedBox(height: 6),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: [
                  for (final entry in pieCounts.entries)
                    PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: Color(_pieColors[entry.key] ?? 0xFFCCCCCC),
                      title: '',
                      radius: 18,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in pieCounts.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: Color(_pieColors[entry.key] ?? 0xFFCCCCCC), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('${entry.key}: ', style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                    Text('${entry.value}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text('SEVERITY BREAKDOWN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
          const SizedBox(height: 6),
          for (final entry in kReportSeverityColors.entries) _severityRow(entry.key, Color(entry.value)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _statusRow('Database Sync Status:', 'Synchronized', AppColors.success),
          const SizedBox(height: 4),
          _statusRow('Operations Queue:', 'Idle', AppColors.primaryText),
        ],
      ),
    );
  }

  Widget _severityRow(String name, Color color) {
    final count = allReports.where((r) => r.severity == name).length;
    final pct = allReports.isEmpty ? 0.0 : count / allReports.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(name, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.primaryBg,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 20, child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }
}
