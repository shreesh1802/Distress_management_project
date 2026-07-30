import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import '../combined_task.dart';

/// Direct port of MaintenanceDashboard.tsx's Table Registry view.
class TaskTable extends StatelessWidget {
  const TaskTable({
    super.key,
    required this.paginatedTasks,
    required this.totalFiltered,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
    required this.onSelect,
    required this.onPrev,
    required this.onNext,
  });

  final List<CombinedTask> paginatedTasks;
  final int totalFiltered;
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;
  final ValueChanged<CombinedTask> onSelect;
  final VoidCallback onPrev;
  final VoidCallback onNext;

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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.primaryBg),
              columns: const [
                DataColumn(label: _Header('Tracking ID')),
                DataColumn(label: _Header('Distress Type')),
                DataColumn(label: _Header('Severity')),
                DataColumn(label: _Header('Priority')),
                DataColumn(label: _Header('Impact')),
                DataColumn(label: _Header('Engineer')),
                DataColumn(label: _Header('Status')),
                DataColumn(label: _Header('Cost')),
                DataColumn(label: _Header('Due Date')),
              ],
              rows: paginatedTasks.isEmpty
                  ? [
                      const DataRow(cells: [
                        DataCell(Text('No tasks found matching current filters.', style: TextStyle(color: AppColors.secondaryText))),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                        DataCell(SizedBox()),
                      ]),
                    ]
                  : [for (final t in paginatedTasks) _row(t)],
            ),
          ),
          if (totalFiltered > 0) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Showing ${((currentPage - 1) * itemsPerPage) + 1} to ${(currentPage * itemsPerPage).clamp(0, totalFiltered)} of $totalFiltered tasks',
                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: currentPage == 1 ? null : onPrev, icon: const Icon(LucideIcons.chevronLeft, size: 16)),
                    Text('Page $currentPage of $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    IconButton(onPressed: currentPage == totalPages ? null : onNext, icon: const Icon(LucideIcons.chevronRight, size: 16)),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DataRow _row(CombinedTask t) {
    return DataRow(
      onSelectChanged: (_) => onSelect(t),
      cells: [
        DataCell(Text(t.trackingId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        DataCell(Text(t.distressType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        DataCell(_pill(t.severity, Color(priorityColors[t.severity] ?? 0xFF999999))),
        DataCell(_pill(t.priority, Color(priorityColors[t.priority] ?? 0xFF999999))),
        DataCell(Text(t.roadHealthImpact, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        DataCell(Text(t.assignedEngineer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        DataCell(_pill(t.status, Color(statusColors[t.status] ?? 0xFF999999))),
        DataCell(Text(formatCost(t.estimatedCost), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        DataCell(Text(t.dueDate, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9999)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
    );
  }
}
