import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

class NotificationFilters {
  const NotificationFilters({
    this.priority = 'All',
    this.category = 'All',
    this.status = 'All',
    this.district = 'All',
    this.road = 'All',
    this.pipeline = 'All',
  });

  final String priority;
  final String category;
  final String status;
  final String district;
  final String road;
  final String pipeline;

  NotificationFilters copyWith({
    String? priority,
    String? category,
    String? status,
    String? district,
    String? road,
    String? pipeline,
  }) {
    return NotificationFilters(
      priority: priority ?? this.priority,
      category: category ?? this.category,
      status: status ?? this.status,
      district: district ?? this.district,
      road: road ?? this.road,
      pipeline: pipeline ?? this.pipeline,
    );
  }
}

/// Direct port of Notifications.tsx's sticky filter row: 6 dropdowns plus
/// 6 quick-toggle chips and a "Clear Filters" chip.
class NotificationsFiltersBar extends StatelessWidget {
  const NotificationsFiltersBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClearAll,
  });

  final NotificationFilters filters;
  final ValueChanged<NotificationFilters> onChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.filter, size: 14, color: AppColors.secondaryText),
              SizedBox(width: 6),
              Text('Filter Incident Streams', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _dropdown('Priority', filters.priority, const ['All', 'Critical', 'High', 'Medium', 'Information', 'Success'],
                  (v) => onChanged(filters.copyWith(priority: v))),
              _dropdown('Category', filters.category, const ['All', 'Detection', 'Maintenance', 'Reports', 'System', 'GIS', 'Uploads'],
                  (v) => onChanged(filters.copyWith(category: v))),
              _dropdown('Status', filters.status, const ['All', 'Unread', 'Read'], (v) => onChanged(filters.copyWith(status: v))),
              _dropdown('District', filters.district, const ['All', 'Mumbai', 'Pune', 'Nagpur', 'Thane'],
                  (v) => onChanged(filters.copyWith(district: v))),
              _dropdown('Road', filters.road, const ['All', 'NH-48', 'SH-4', 'WEH-01'], (v) => onChanged(filters.copyWith(road: v))),
              _dropdown('Pipeline', filters.pipeline, const ['All', 'YOLOv11-Heavy', 'YOLOv11-Base'],
                  (v) => onChanged(filters.copyWith(pipeline: v))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('🚨 Critical Alerts', filters.priority == 'Critical',
                  () => onChanged(filters.copyWith(priority: filters.priority == 'Critical' ? 'All' : 'Critical'))),
              _chip('📬 Unread Tray', filters.status == 'Unread',
                  () => onChanged(filters.copyWith(status: filters.status == 'Unread' ? 'All' : 'Unread'))),
              _chip('🤖 AI Tagged Detections', filters.category == 'Detection',
                  () => onChanged(filters.copyWith(category: filters.category == 'Detection' ? 'All' : 'Detection'))),
              _chip('👷 Workforce Updates', filters.category == 'Maintenance',
                  () => onChanged(filters.copyWith(category: filters.category == 'Maintenance' ? 'All' : 'Maintenance'))),
              _chip('📄 PDF Summary Logs', filters.category == 'Reports',
                  () => onChanged(filters.copyWith(category: filters.category == 'Reports' ? 'All' : 'Reports'))),
              _chip('⚙️ Hardware/Backup', filters.category == 'System',
                  () => onChanged(filters.copyWith(category: filters.category == 'System' ? 'All' : 'System'))),
              OutlinedButton(
                onPressed: onClearAll,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondaryText, side: BorderSide(color: AppColors.cardBorder)),
                child: const Text('Clear Filters', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Text(o == 'All' ? '$label: All' : o, style: const TextStyle(fontSize: 12, color: AppColors.primaryText)),
              ),
          ],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.accentBlue : AppColors.primaryBg,
          border: Border.all(color: active ? AppColors.accentBlue : AppColors.cardBorder),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.primaryText)),
      ),
    );
  }
}
