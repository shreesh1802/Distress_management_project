import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

class HistoryFilters {
  const HistoryFilters({
    this.activityType = 'All',
    this.status = 'All',
    this.user = 'All',
    this.district = 'All',
    this.road = 'All',
    this.modelVersion = 'All',
  });

  final String activityType;
  final String status;
  final String user;
  final String district;
  final String road;
  final String modelVersion;

  HistoryFilters copyWith({
    String? activityType,
    String? status,
    String? user,
    String? district,
    String? road,
    String? modelVersion,
  }) {
    return HistoryFilters(
      activityType: activityType ?? this.activityType,
      status: status ?? this.status,
      user: user ?? this.user,
      district: district ?? this.district,
      road: road ?? this.road,
      modelVersion: modelVersion ?? this.modelVersion,
    );
  }
}

/// Direct port of History.tsx's sticky filters row: 6 dropdowns plus 3
/// quick-toggle chips and a "Clear All" chip.
///
/// The `activityType` dropdown drops the source's `Maintenance`/`GIS`/
/// `Notifications` options -- those categories only ever appeared on the
/// 8 hardcoded fake "system events" this port doesn't seed (see
/// `timeline_event.dart`'s doc comment), so keeping those filter options
/// would just be dead UI that can never match anything.
class HistoryFiltersBar extends StatelessWidget {
  const HistoryFiltersBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClearAll,
  });

  final HistoryFilters filters;
  final ValueChanged<HistoryFilters> onChanged;
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
              Text('Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _dropdown('Activity Type', filters.activityType, const ['All', 'Reports', 'Inference', 'Uploads'],
                  (v) => onChanged(filters.copyWith(activityType: v))),
              _dropdown('Status', filters.status, const ['All', 'Success', 'Failed', 'Info', 'Warning'],
                  (v) => onChanged(filters.copyWith(status: v))),
              _dropdown('User', filters.user, const ['All', 'John', 'Sarah', 'Prasad', 'System'],
                  (v) => onChanged(filters.copyWith(user: v))),
              _dropdown('District', filters.district, const ['All', 'Mumbai', 'Pune', 'Nagpur', 'Thane', 'Satara'],
                  (v) => onChanged(filters.copyWith(district: v))),
              _dropdown('Road', filters.road, const ['All', 'NH-48', 'SH-4', 'Western Express Highway', 'Eastern Freeway'],
                  (v) => onChanged(filters.copyWith(road: v))),
              _dropdown('Model Version', filters.modelVersion, const ['All', 'v1.2.0', 'v1.3.1', 'v2.0.0'],
                  (v) => onChanged(filters.copyWith(modelVersion: v))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('⚠️ Failed Ops', filters.status == 'Failed',
                  () => onChanged(filters.copyWith(status: filters.status == 'Failed' ? 'All' : 'Failed'))),
              _chip('📄 PDF/Excel Reports', filters.activityType == 'Reports',
                  () => onChanged(filters.copyWith(activityType: filters.activityType == 'Reports' ? 'All' : 'Reports'))),
              _chip('🤖 Inference Runs', filters.activityType == 'Inference',
                  () => onChanged(filters.copyWith(activityType: filters.activityType == 'Inference' ? 'All' : 'Inference'))),
              OutlinedButton(
                onPressed: onClearAll,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondaryText, side: BorderSide(color: AppColors.cardBorder)),
                child: const Text('Clear All', style: TextStyle(fontSize: 11)),
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
