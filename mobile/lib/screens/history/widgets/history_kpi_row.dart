import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

/// Direct port of History.tsx's Row 2 KPI grid (4 cards: Total Activity
/// Logs, Reports Exported, AI Inference Runs, Failed Operations).
///
/// Trimmed: the fake "↑ 12.4% vs last week"-style trend badge and the
/// hardcoded SVG sparkline polyline on every card -- both are pure
/// decoration with arbitrary, uncomputed percentages (unlike a single
/// static fallback label elsewhere, e.g. Maintenance's "Avg Completion
/// Time: 1.8 Days", these actively misrepresent trend data that was never
/// computed), so they were dropped rather than ported as fake numbers.
class HistoryKpiRow extends StatelessWidget {
  const HistoryKpiRow({super.key, required this.totalLogs, required this.reportsExported, required this.inferenceRuns, required this.failedOps});

  final int totalLogs;
  final int reportsExported;
  final int inferenceRuns;
  final int failedOps;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (LucideIcons.history, 'Total Activity Logs', '$totalLogs', AppColors.accentBlue),
      (LucideIcons.fileSpreadsheet, 'Reports Exported', '$reportsExported', AppColors.accentBlue),
      (LucideIcons.brain, 'AI Inference Runs', '$inferenceRuns', AppColors.success),
      (LucideIcons.alertTriangle, 'Failed Operations', '$failedOps', AppColors.danger),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700 ? 2 : 4;
        const gap = 16.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: c.$4.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Icon(c.$1, size: 16, color: c.$4),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.$2,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(c.$3, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
