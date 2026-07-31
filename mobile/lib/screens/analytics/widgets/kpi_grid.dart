import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AnalyticsKpi {
  const AnalyticsKpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.borderColor,
    this.valueColor,
    this.trendLabel,
    this.trendBadgeColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color borderColor;
  final Color? valueColor;
  final String? trendLabel;
  final Color? trendBadgeColor;
}

/// Direct port of AnalyticsDashboard.tsx's Row 1 KPI grid: 8 cards with a
/// 4px colored top border per card (`.kpi-card--0` through `--7` in the
/// source CSS) and an "↑ +N Today" trend badge on the 3 KPIs the source
/// tracks a same-day count for.
class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({super.key, required this.kpis});

  final List<AnalyticsKpi> kpis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700
            ? 2
            : (constraints.maxWidth < 1000 ? 3 : (constraints.maxWidth < 1300 ? 4 : 4));
        const gap = 16.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final k in kpis)
              SizedBox(
                width: tileWidth,
                // A `Border` with per-side colors can't be combined with
                // `borderRadius` in a single BoxDecoration (Flutter throws
                // "borderRadius can only be given on borders with uniform
                // colors"), so the colored top accent is drawn as a plain
                // Container strip inside a ClipRRect instead of a border side.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(height: 4, color: k.borderColor),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      k.label.toUpperCase(),
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                                    ),
                                  ),
                                  Icon(k.icon, size: 15, color: k.borderColor),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(k.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: k.valueColor)),
                              const SizedBox(height: 6),
                              if (k.trendLabel != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (k.trendBadgeColor ?? AppColors.success).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    k.trendLabel!,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.trendBadgeColor ?? AppColors.success),
                                  ),
                                )
                              else
                                const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
