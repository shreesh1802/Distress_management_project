import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../notification_item.dart';

const kNotificationsPieColors = [
  Color(0xFFC45C45),
  Color(0xFFC87B35),
  Color(0xFFD6A23A),
  Color(0xFF6B88C7),
  Color(0xFF7B8260),
  Color(0xFF8FA06A),
];

/// Direct port of Notifications.tsx's "Quick Incident Summary" widget.
class QuickIncidentSummaryCard extends StatelessWidget {
  const QuickIncidentSummaryCard({
    super.key,
    required this.critical,
    required this.unread,
    required this.maintenance,
    required this.reports,
    required this.aiJobs,
  });

  final int critical;
  final int unread;
  final int maintenance;
  final int reports;
  final int aiJobs;

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
          const Text('Quick Incident Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _row('⚠️ Critical Incidents', critical, const Color(0xFFEF4444)),
          _row('📬 Unread Messages', unread, AppColors.accentBlue),
          _row('🔧 Maintenance Tasks', maintenance, AppColors.primaryText),
          _row('📄 PDF & Excel Reports', reports, AppColors.primaryText),
          _row('🤖 Active AI Pipelines', aiJobs, AppColors.primaryText),
        ],
      ),
    );
  }

  Widget _row(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text('$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// Direct port of Notifications.tsx's "Alert Categories" donut chart widget.
class AlertCategoriesCard extends StatelessWidget {
  const AlertCategoriesCard({super.key, required this.data});

  /// category -> count, source order (Detection, Maintenance, Reports,
  /// System, GIS, Uploads).
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
          const Text('Alert Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No category matches.', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))),
            )
          else ...[
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: kNotificationsPieColors[i % kNotificationsPieColors.length],
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
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: kNotificationsPieColors[i % kNotificationsPieColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('${entries[i].key}: ${entries[i].value}', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
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

/// Direct port of Notifications.tsx's "Recent Event Log" widget (first 5
/// notifications, unfiltered, matching `notifications.slice(0, 5)`).
class RecentEventLogCard extends StatelessWidget {
  const RecentEventLogCard({super.key, required this.items});

  final List<NotificationItem> items;

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
          const Text('Recent Event Log', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final n in items.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(width: 8, height: 8, decoration: BoxDecoration(color: priorityColor(n.priority), shape: BoxShape.circle)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text(n.time, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
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
