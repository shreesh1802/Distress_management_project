import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

/// Direct port of AnalyticsDashboard.tsx's Rows 7-9: the "Maintenance Tasks
/// Queue" + "Exported Documents Archive" summary cards, the "Executive
/// Summary Insights" list, and the dark-themed "AI Model Performance
/// Indicators" card.
class MaintenanceReportsSummaryRow extends StatelessWidget {
  const MaintenanceReportsSummaryRow({
    super.key,
    required this.pending,
    required this.assigned,
    required this.inProgress,
    required this.completed,
    required this.pdfCount,
    required this.excelCount,
    required this.jsonCount,
    required this.latestReportDate,
  });

  final int pending;
  final int assigned;
  final int inProgress;
  final int completed;
  final int pdfCount;
  final int excelCount;
  final int jsonCount;
  final String latestReportDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 800;
        final maintenance = _card(
          title: 'Maintenance Tasks Queue',
          tiles: [
            _Tile('PENDING', '$pending', AppColors.danger),
            _Tile('ASSIGNED', '$assigned', AppColors.accentBlue),
            _Tile('IN PROGRESS', '$inProgress', AppColors.warning),
            _Tile('COMPLETED', '$completed', AppColors.success),
          ],
          footerLabel: 'Average repair turnaround time:',
          footerValue: '4.5 Days (SLA benchmark)',
        );
        final reports = _card(
          title: 'Exported Documents Archive',
          tiles: [
            _Tile('PDF REPORTS', '$pdfCount', AppColors.primaryText),
            _Tile('EXCEL SHEETS', '$excelCount', AppColors.primaryText),
            _Tile('JSON EXPORTS', '$jsonCount', AppColors.primaryText),
          ],
          footerLabel: 'Last generated report timestamp:',
          footerValue: latestReportDate,
        );
        if (narrow) {
          return Column(children: [maintenance, const SizedBox(height: 20), reports]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: maintenance),
            const SizedBox(width: 24),
            Expanded(child: reports),
          ],
        );
      },
    );
  }

  Widget _card({required String title, required List<_Tile> tiles, required String footerLabel, required String footerValue}) {
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
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final t in tiles) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      children: [
                        Text(t.label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
                        const SizedBox(height: 4),
                        Text(t.value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.color, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
                if (t != tiles.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
            child: Row(
              children: [
                Expanded(
                  child: Text(footerLabel, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    footerValue,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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

class _Tile {
  const _Tile(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}

class ExecutiveInsightsCard extends StatelessWidget {
  const ExecutiveInsightsCard({super.key, required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
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
          const Text('Executive Summary Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final insight in insights)
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 240, maxWidth: 360),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(insight, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The source reads `model_name`/`yolo_version`/`model_size`/
/// `inference_device`/`inference_speed` off `GET /api/v1/detection/summary`,
/// but the backend's `get_detection_analytics` never actually returns any
/// of those keys -- so all five always fall back to the source's own
/// hardcoded defaults in practice. Only `averageConfidence` (sourced from
/// the real `kpis.avgConfidence`, not from the summary payload) varies.
/// Those five are hardcoded here to match rather than modeled as fetched
/// data that never arrives.
class AiModelPerformanceCard extends StatelessWidget {
  const AiModelPerformanceCard({super.key, required this.averageConfidence});

  final String averageConfidence;

  @override
  Widget build(BuildContext context) {
    final fields = [
      ('Model Name', 'YOLOv11 Road Distress Detector'),
      ('YOLO Version', 'YOLOv11s'),
      ('Model Size', '21.5 MB'),
      ('Inference Device', 'CUDA (NVIDIA RTX 4060)'),
      ('Average Confidence', averageConfidence),
      ('Inference Speed', '82 FPS'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryText,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.cpu, size: 16, color: Color(0xFF76B900)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('AI Model Performance Indicators', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const Text('Active Model Instance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF76B900), fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 700 ? 2 : (constraints.maxWidth < 1100 ? 3 : 6);
              const gap = 16.0;
              final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final f in fields)
                    SizedBox(
                      width: tileWidth,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(f.$1.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                            const SizedBox(height: 6),
                            Text(
                              f.$2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: (f.$1 == 'Average Confidence' || f.$1 == 'Inference Speed') ? const Color(0xFF76B900) : Colors.white,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
