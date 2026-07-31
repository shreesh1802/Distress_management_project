import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/maintenance_api.dart';
import '../../../theme/app_colors.dart';
import '../combined_task.dart';

const _kStatusOptions = ['Pending', 'Assigned', 'In Progress', 'Completed', 'Closed'];
const _kFallbackEngineers = [
  'Rajesh Kulkarni',
  'Suresh Patil',
  'Vikram Jadhav',
  'Pradeep More',
  'Sanjay Bhosale',
  'Amit Deshmukh',
];

/// Direct port of MaintenanceDashboard.tsx's slide-out details drawer.
/// Status/engineer/due-date edits are local-state-only, matching the React
/// source (there's no backend PATCH endpoint wired up there either).
class TaskDrawer extends StatelessWidget {
  const TaskDrawer({
    super.key,
    required this.task,
    required this.engineers,
    required this.onClose,
    required this.onStatusChanged,
    required this.onEngineerChanged,
    required this.onDueDateChanged,
  });

  final CombinedTask task;
  final List<AppUser> engineers;
  final VoidCallback onClose;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onEngineerChanged;
  final ValueChanged<String> onDueDateChanged;

  @override
  Widget build(BuildContext context) {
    final engineerNames = engineers.map((e) => e.fullName ?? e.email).toList();
    final engineerOptions = engineerNames.isNotEmpty ? engineerNames : _kFallbackEngineers;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 420,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: AppColors.cardBorder)),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(-6, 0))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WORK ORDER DETAILS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText),
                        ),
                        Text(task.trackingId, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(LucideIcons.x, size: 18)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _imageBox(task.detectionImage, 'Detection Frame\n[CCTV Source]', 'RAW CAMERA')),
                        const SizedBox(width: 12),
                        Expanded(child: _imageBox(task.annotatedImage, 'YOLO Annotated Frame\n[Analytics Source]', 'AI ANNOTATION')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
                      child: Row(
                        children: [
                          Expanded(
                            child: _labeledDropdown('Stage Status', task.status, _kStatusOptions, onStatusChanged),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _labeledDropdown(
                              'Assign Engineer',
                              engineerOptions.contains(task.assignedEngineer) ? task.assignedEngineer : 'Unassigned',
                              ['Unassigned', ...engineerOptions],
                              onEngineerChanged,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row('Distress Classification:', task.distressType),
                    _rowWidget('Severity:', _pill(task.severity, Color(priorityColors[task.severity] ?? 0xFF999999))),
                    _rowWidget('Priority level:', _pill(task.priority, Color(priorityColors[task.priority] ?? 0xFF999999))),
                    _row('Damage Area (m²):', task.damageArea),
                    _row('Estimated Cost:', formatCost(task.estimatedCost)),
                    _row('Road Health Impact:', task.roadHealthImpact, valueColor: const Color(0xFFC45C45)),
                    _rowWidget(
                      'Due Date:',
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(task.dueDate) ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            onDueDateChanged(
                              '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(4)),
                          child: Text(task.dueDate, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                    _rowWidget(
                      'GPS Coordinates:',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.mapPin, size: 12, color: AppColors.accentBlue),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              task.gps,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => launchUrl(
                              Uri.parse('https://www.google.com/maps/search/?api=1&query=${task.gps}'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: const Icon(LucideIcons.externalLink, size: 12, color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                      isLast: true,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.cardBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI TELEMETRY RECOMMENDATION',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText),
                          ),
                          const SizedBox(height: 6),
                          Text(task.recommendation, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageBox(String? url, String placeholder, String tag) {
    return Stack(
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(color: AppColors.primaryBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
          clipBehavior: Clip.antiAlias,
          child: url != null
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Center(
                    child: Text(placeholder, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                  ),
                )
              : Center(
                  child: Text(placeholder, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(3)),
            child: Text(tag, style: const TextStyle(fontSize: 8, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _labeledDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6), color: Colors.white),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(value) ? value : options.first,
              isExpanded: true,
              isDense: true,
              items: [
                for (final o in options)
                  DropdownMenuItem(
                    value: o,
                    child: Text(o, style: const TextStyle(fontSize: 12, color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                  ),
              ],
              onChanged: (v) => onChanged(v ?? value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9999)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool isLast = false}) {
    return _rowWidget(
      label,
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor)),
      isLast: isLast,
    );
  }

  Widget _rowWidget(String label, Widget value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: AppColors.cardBorder))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
          const SizedBox(width: 8),
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
        ],
      ),
    );
  }
}
