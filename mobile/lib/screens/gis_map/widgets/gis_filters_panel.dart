import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/gis_api.dart';
import '../../../theme/app_colors.dart';

/// Direct port of GISFilters.tsx/.css: state/district/distress-type/severity
/// dropdowns plus a date range, applied only when "Apply Filters" is tapped
/// (mirrors the React source's local-vs-applied filter state split).
const Map<String, List<String>> _statesAndDistricts = {
  'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Thane'],
  'Karnataka': ['Bengaluru', 'Mysore', 'Hubli', 'Mangaluru'],
  'Delhi': ['New Delhi', 'South Delhi', 'North Delhi', 'East Delhi'],
  'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Trichy'],
};

const List<MapEntry<String, String>> _distressTypeOptions = [
  MapEntry('pothole', 'Pothole'),
  MapEntry('crack', 'Crack (Alligator/Longitudinal)'),
  MapEntry('raveling', 'Raveling'),
  MapEntry('rutting', 'Rutting'),
  MapEntry('shoving', 'Shoving'),
  MapEntry('bleeding', 'Bleeding'),
];

const List<MapEntry<String, String>> _severityOptions = [
  MapEntry('low', 'Low'),
  MapEntry('medium', 'Medium'),
  MapEntry('high', 'High'),
  MapEntry('critical', 'Critical'),
];

class GisFiltersPanel extends StatefulWidget {
  const GisFiltersPanel({
    super.key,
    required this.initialFilters,
    required this.onApply,
    required this.onReset,
  });

  final GisFiltersState initialFilters;
  final ValueChanged<GisFiltersState> onApply;
  final VoidCallback onReset;

  @override
  State<GisFiltersPanel> createState() => _GisFiltersPanelState();
}

class _GisFiltersPanelState extends State<GisFiltersPanel> {
  late GisFiltersState _local = widget.initialFilters;

  @override
  void didUpdateWidget(covariant GisFiltersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilters != widget.initialFilters) {
      setState(() => _local = widget.initialFilters);
    }
  }

  List<String> get _availableDistricts =>
      _statesAndDistricts[_local.state] ?? const [];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.filter, size: 18, color: AppColors.primaryText),
              SizedBox(width: 8),
              Text(
                'Filter Distress Data',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _FieldLabel(icon: LucideIcons.mapPin, text: 'State'),
          const SizedBox(height: 6),
          _FilterDropdown(
            value: _local.state,
            placeholder: 'All States',
            items: _statesAndDistricts.keys
                .map((s) => MapEntry(s, s))
                .toList(),
            onChanged: (v) => setState(() {
              _local = _local.copyWith(state: v, district: '');
            }),
          ),
          const SizedBox(height: 14),
          _FieldLabel(icon: LucideIcons.mapPin, text: 'District'),
          const SizedBox(height: 6),
          _FilterDropdown(
            value: _local.district,
            placeholder: _local.state.isEmpty
                ? 'Select State First'
                : 'All Districts',
            items: _availableDistricts.map((d) => MapEntry(d, d)).toList(),
            enabled: _local.state.isNotEmpty,
            onChanged: (v) => setState(() => _local = _local.copyWith(district: v)),
          ),
          const SizedBox(height: 14),
          _FieldLabel(icon: LucideIcons.layers, text: 'Distress Type'),
          const SizedBox(height: 6),
          _FilterDropdown(
            value: _local.distressType,
            placeholder: 'All Types',
            items: _distressTypeOptions,
            onChanged: (v) =>
                setState(() => _local = _local.copyWith(distressType: v)),
          ),
          const SizedBox(height: 14),
          _FieldLabel(icon: LucideIcons.alertTriangle, text: 'Severity Level'),
          const SizedBox(height: 6),
          _FilterDropdown(
            value: _local.severity,
            placeholder: 'All Severities',
            items: _severityOptions,
            onChanged: (v) => setState(() => _local = _local.copyWith(severity: v)),
          ),
          const SizedBox(height: 14),
          _FieldLabel(icon: LucideIcons.calendar, text: 'Date Range'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'From',
                  value: _local.startDate,
                  onPick: (v) =>
                      setState(() => _local = _local.copyWith(startDate: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateField(
                  label: 'To',
                  value: _local.endDate,
                  onPick: (v) =>
                      setState(() => _local = _local.copyWith(endDate: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onApply(_local),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _local = const GisFiltersState());
                widget.onReset();
              },
              icon: const Icon(LucideIcons.rotateCcw, size: 14),
              label: const Text('Reset', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryText,
                side: BorderSide(color: AppColors.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.secondaryText),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

/// A tap-to-open select field. Deliberately not DropdownButtonFormField --
/// that widget's selected-value text has rendered invisible on other screens
/// in this app (see _SurveyDropdown in survey_screen.dart) even after
/// explicit styling, so every dropdown here uses this same modal-sheet
/// picker pattern instead.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.placeholder,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final String placeholder;
  final List<MapEntry<String, String>> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                placeholder,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontWeight: value.isEmpty ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              trailing: value.isEmpty
                  ? const Icon(LucideIcons.check, color: AppColors.accentBlue, size: 18)
                  : null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final item in items)
              ListTile(
                title: Text(
                  item.value,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight:
                        item.key == value ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                trailing: item.key == value
                    ? const Icon(LucideIcons.check, color: AppColors.accentBlue, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(item.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final label = items
        .where((e) => e.key == value)
        .map((e) => e.value)
        .firstOrNull;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? () => _openPicker(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryBg : AppColors.primaryBg.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label ?? placeholder,
                style: TextStyle(
                  fontSize: 13,
                  color: label != null
                      ? AppColors.primaryText
                      : AppColors.secondaryText,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: enabled ? AppColors.secondaryText : AppColors.secondaryText.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final String value;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final iso =
              '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          onPick(iso);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryBg,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.secondaryText),
            ),
            Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 12, color: AppColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
