import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/gis_api.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/distress_icons.dart';
import '../severity_colors.dart';

/// Direct port of DistressSummary.tsx: severity split bars on the left,
/// derived insights (most affected state/district, most common type,
/// average confidence, last detection) on the right.
class DistressSummaryPanel extends StatelessWidget {
  const DistressSummaryPanel({
    super.key,
    required this.distresses,
    required this.isLoading,
  });

  final List<RoadDistress> distresses;
  final bool isLoading;

  String _mostFrequent(Iterable<String> values) {
    if (values.isEmpty) return 'N/A';
    final counts = <String, int>{};
    var best = '';
    var bestCount = 0;
    for (final v in values) {
      final c = (counts[v] ?? 0) + 1;
      counts[v] = c;
      if (c > bestCount) {
        bestCount = c;
        best = v;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SummaryShell(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final total = distresses.length;
    final critical = distresses.where((d) => d.severity == 'critical').length;
    final high = distresses.where((d) => d.severity == 'high').length;
    final medium = distresses.where((d) => d.severity == 'medium').length;
    final low = distresses.where((d) => d.severity == 'low').length;

    final mostAffectedState = _mostFrequent(distresses.map((d) => d.state));
    final mostAffectedDistrict = _mostFrequent(distresses.map((d) => d.district));
    final rawType = _mostFrequent(distresses.map((d) => d.distressType));
    final mostCommonType = rawType == 'N/A' ? 'N/A' : formatDistressType(rawType);
    final avgConfidence = total > 0
        ? (distresses.map((d) => d.confidence).reduce((a, b) => a + b) / total).round()
        : 0;

    String lastDetection = 'N/A';
    if (distresses.isNotEmpty) {
      final sorted = [...distresses]
        ..sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
      lastDetection = sorted.first.reportedDate;
    }

    int pct(int count) => total == 0 ? 0 : ((count / total) * 100).round();

    return _SummaryShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.trendingUp, size: 18, color: AppColors.primaryText),
              SizedBox(width: 8),
              Text(
                'Distress Summary Analytics',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 480;
              final metrics = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Distresses',
                          style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                        ),
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SplitRow(label: 'Critical', count: critical, pct: pct(critical), color: severityColor('critical')),
                  _SplitRow(label: 'High', count: high, pct: pct(high), color: severityColor('high')),
                  _SplitRow(label: 'Medium', count: medium, pct: pct(medium), color: severityColor('medium')),
                  _SplitRow(label: 'Low', count: low, pct: pct(low), color: severityColor('low')),
                ],
              );

              final insights = Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Additional Insights',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InsightRow(LucideIcons.mapPin, 'Most Affected State', mostAffectedState),
                    _InsightRow(LucideIcons.compass, 'Most Affected District', mostAffectedDistrict),
                    _InsightRow(
                      rawType == 'N/A' ? LucideIcons.layers : distressTypeIcon(rawType),
                      'Most Common Type',
                      mostCommonType,
                      iconColor: rawType == 'N/A' ? null : distressTypeIconColor(rawType),
                    ),
                    _InsightRow(
                      LucideIcons.alertTriangle,
                      'Avg Confidence Score',
                      avgConfidence > 0 ? '$avgConfidence%' : 'N/A',
                    ),
                    _InsightRow(LucideIcons.calendar, 'Last Detection Time', lastDetection),
                  ],
                ),
              );

              if (narrow) {
                return Column(children: [metrics, const SizedBox(height: 12), insights]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: metrics),
                  const SizedBox(width: 16),
                  Expanded(child: insights),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.label,
    required this.count,
    required this.pct,
    required this.color,
  });

  final String label;
  final int count;
  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primaryText)),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: AppColors.primaryBg,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow(this.icon, this.label, this.value, {this.iconColor});

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor ?? AppColors.secondaryText),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryShell extends StatelessWidget {
  const _SummaryShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
