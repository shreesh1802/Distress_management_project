import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

/// Direct port of Notifications.tsx's Row 2 KPI grid (4 cards: Unread
/// Alerts, Critical Alerts, Today's Notifications, Resolved Events).
///
/// Trimmed: the fake "↑ 12%"-style trend badge and hardcoded SVG
/// sparkline on every card -- arbitrary, uncomputed decoration, same
/// reasoning as the equivalent trim on History's KPI row.
class NotificationsKpiRow extends StatelessWidget {
  const NotificationsKpiRow({
    super.key,
    required this.unreadCount,
    required this.criticalCount,
    required this.todayCount,
    required this.resolvedCount,
  });

  final int unreadCount;
  final int criticalCount;
  final int todayCount;
  final int resolvedCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (LucideIcons.bell, 'Unread Alerts', '$unreadCount', const Color(0xFFEF4444)),
      (LucideIcons.shieldAlert, 'Critical Alerts', '$criticalCount', const Color(0xFFEF4444)),
      (LucideIcons.activity, "Today's Notifications", '$todayCount', const Color(0xFF3B82F6)),
      (LucideIcons.checkCircle2, 'Resolved Events', '$resolvedCount', const Color(0xFF10B981)),
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
