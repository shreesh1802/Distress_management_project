import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/road_distress_api.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/distress_icons.dart';
import '../video_review_helpers.dart';

/// Direct port of VideoReview.tsx's right sidebar: a "Detections (N)" /
/// "Inspector Details" tab header, a detections table, and the selected-
/// detection inspector pane (visual crop, metadata grid, maintenance
/// guideline, prev/nearest/next navigation).
class DetectionsSidebar extends StatelessWidget {
  const DetectionsSidebar({
    super.key,
    required this.detections,
    required this.selectedDetection,
    required this.activeTab,
    required this.isLoading,
    required this.onTabChanged,
    required this.onSelect,
    required this.onNavigate,
  });

  final List<DistressRecord> detections;
  final DistressRecord? selectedDetection;
  final String activeTab; // 'list' or 'details'
  final bool isLoading;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<DistressRecord> onSelect;
  final ValueChanged<String> onNavigate; // 'prev', 'next', 'nearest'

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _tabBtn('Detections (${detections.length})', 'list')),
              Expanded(child: _tabBtn('Inspector Details', 'details', enabled: selectedDetection != null)),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: activeTab == 'details' && selectedDetection != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: _inspector(selectedDetection!),
                  )
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: _list(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, String tab, {bool enabled = true}) {
    final active = activeTab == tab;
    return InkWell(
      onTap: enabled ? () => onTabChanged(tab) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.accentBlue : Colors.transparent, width: 2))),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: enabled ? (active ? AppColors.accentBlue : AppColors.primaryText) : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  // (label, width) per column. A real processed video can carry hundreds or
  // thousands of tracked detections -- rendering that many rows via
  // DataTable (which builds its entire `rows` list eagerly, with no
  // virtualization) locks up the tab for as long as that build takes,
  // which can look and feel exactly like a page freeze. Fixed-width
  // columns + ListView.builder below only ever build the rows actually
  // visible in the viewport, however large `detections` gets.
  static const List<(String, double)> _kColumns = [
    ('Tracking ID', 64),
    ('Type', 158),
    ('Severity', 72),
    ('Time', 56),
    ('Frame', 56),
    ('Conf', 48),
  ];
  static const double _kColumnSpacing = 16;
  static double get _kTableWidth =>
      _kColumns.fold(0.0, (sum, c) => sum + c.$2) + _kColumnSpacing * (_kColumns.length - 1);

  Widget _list() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('Loading video diagnostics...', style: TextStyle(color: AppColors.secondaryText))),
      );
    }
    if (detections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('No road distresses detected in this run.', style: TextStyle(color: AppColors.secondaryText))),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _kTableWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerRow(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: detections.length,
                itemExtent: 40,
                itemBuilder: (context, index) => _dataRow(detections[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (int i = 0; i < _kColumns.length; i++) ...[
            if (i > 0) const SizedBox(width: _kColumnSpacing),
            SizedBox(
              width: _kColumns[i].$2,
              child: Text(_kColumns[i].$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dataRow(DistressRecord det) {
    final selected = selectedDetection?.id == det.id;
    return InkWell(
      onTap: () => onSelect(det),
      child: Container(
        height: 40,
        color: selected ? AppColors.accentBlueLight : null,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            SizedBox(
              width: _kColumns[0].$2,
              child: Text('#${det.trackingId ?? det.id}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
            const SizedBox(width: _kColumnSpacing),
            SizedBox(
              width: _kColumns[1].$2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(distressTypeIcon(det.distressType), size: 13, color: distressTypeIconColor(det.distressType)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      formatDistressType(det.distressType),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _kColumnSpacing),
            SizedBox(
              width: _kColumns[2].$2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: severityColor(det.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(det.severity.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: severityColor(det.severity))),
              ),
            ),
            const SizedBox(width: _kColumnSpacing),
            SizedBox(
              width: _kColumns[3].$2,
              child: Text(formatTime(Duration(milliseconds: ((det.videoTimestamp ?? 0) * 1000).round())), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
            const SizedBox(width: _kColumnSpacing),
            SizedBox(
              width: _kColumns[4].$2,
              child: Text('${det.frameNumber ?? ((det.videoTimestamp ?? 0) * 30).floor()}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
            const SizedBox(width: _kColumnSpacing),
            SizedBox(
              width: _kColumns[5].$2,
              child: Text('${((det.confidenceScore == 0 ? 0.85 : det.confidenceScore) * 100).round()}%', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inspector(DistressRecord det) {
    final color = severityColor(det.severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: det.resolvedImageUrl != null
                    ? Image.network(
                        det.resolvedImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: AppColors.primaryBg,
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.image, color: AppColors.secondaryText),
                        ),
                      )
                    : Container(color: AppColors.primaryBg, alignment: Alignment.center, child: const Icon(LucideIcons.image, color: AppColors.secondaryText)),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(4)),
                child: const Text('Annotated Visual Crop', style: TextStyle(fontSize: 9, color: Colors.white)),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
                child: Icon(distressTypeIcon(det.distressType), size: 14, color: distressTypeIconColor(det.distressType)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _field('Tracking ID:', '#${det.trackingId ?? det.id}'),
        _fieldWidget(
          'Distress Type:',
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(distressTypeIcon(det.distressType), size: 13, color: distressTypeIconColor(det.distressType)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  formatDistressType(det.distressType),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        _fieldWidget(
          'Severity Rating:',
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(det.severity.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ),
        _field('AI Confidence:', '${((det.confidenceScore == 0 ? 0.85 : det.confidenceScore) * 100).round()}%'),
        _field('Priority Score:', '${priorityScore(det.severity)}', valueColor: AppColors.warning),
        _field('Road Health Impact:', healthImpactScore(det.severity), valueColor: AppColors.danger),
        _field('Detected Frame:', 'F: ${det.frameNumber ?? ((det.videoTimestamp ?? 0) * 30).floor()}'),
        _field('Detected Time:', '${(det.videoTimestamp ?? 0).toStringAsFixed(2)}s'),
        _field('Bounding box size:', 'W: ${det.boxWidth ?? 120}px | H: ${det.boxHeight ?? 80}px'),
        _field('Damage Area:', '${det.affectedArea ?? 0.125} sq.m'),
        _field('GPS Coordinates:', '${det.latitude.toStringAsFixed(5)}° N, ${det.longitude.toStringAsFixed(5)}° E'),
        _field('Est. Repair Cost:', estimatedCost(det.severity), valueColor: AppColors.success),
        _field('Review Status:', det.status.replaceAll('_', ' ')),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MAINTENANCE GUIDELINE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
              const SizedBox(height: 4),
              Text(recommendationFor(det.distressType), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onNavigate('prev'),
                icon: const Icon(LucideIcons.chevronLeft, size: 14),
                label: const Text('Previous', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.cardBorder)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton(
                onPressed: () => onNavigate('nearest'),
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.cardBorder)),
                child: const Text('Nearest', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onNavigate('next'),
                icon: const Icon(LucideIcons.chevronRight, size: 14),
                label: const Text('Next', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.cardBorder)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(String label, String value, {Color? valueColor}) {
    return _fieldWidget(label, Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor)));
  }

  Widget _fieldWidget(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
          const SizedBox(width: 8),
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}
