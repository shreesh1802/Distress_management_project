import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import '../combined_task.dart';

const _kColumns = ['Pending', 'Assigned', 'In Progress', 'Completed', 'Closed'];
const _kNextStatus = {
  'Pending': 'Assigned',
  'Assigned': 'In Progress',
  'In Progress': 'Completed',
  'Completed': 'Closed',
};
const _kNextLabel = {
  'Pending': 'Assign',
  'Assigned': 'Start',
  'In Progress': 'Complete',
  'Completed': 'Close',
};

/// Direct port of MaintenanceDashboard.tsx's Kanban Board view: 5 status
/// columns, each a scrollable list of task cards with a quick-advance
/// button (Pending -> Assigned -> In Progress -> Completed -> Closed).
class KanbanBoard extends StatelessWidget {
  const KanbanBoard({
    super.key,
    required this.tasks,
    required this.onSelect,
    required this.onAdvance,
  });

  final List<CombinedTask> tasks;
  final ValueChanged<CombinedTask> onSelect;
  final void Function(CombinedTask task, String newStatus) onAdvance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 620,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in _kColumns)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _KanbanColumn(
                  status: column,
                  tasks: tasks.where((t) => t.status == column).toList(),
                  onSelect: onSelect,
                  onAdvance: onAdvance,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.tasks,
    required this.onSelect,
    required this.onAdvance,
  });

  final String status;
  final List<CombinedTask> tasks;
  final ValueChanged<CombinedTask> onSelect;
  final void Function(CombinedTask task, String newStatus) onAdvance;

  @override
  Widget build(BuildContext context) {
    final color = Color(statusColors[status] ?? 0xFFCCCCCC);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9999)),
                child: Text('${tasks.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: tasks.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cardBorder, width: 2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text('No tasks in this stage', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) => _KanbanCard(
                      task: tasks[index],
                      onSelect: onSelect,
                      onAdvance: onAdvance,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({required this.task, required this.onSelect, required this.onAdvance});

  final CombinedTask task;
  final ValueChanged<CombinedTask> onSelect;
  final void Function(CombinedTask task, String newStatus) onAdvance;

  @override
  Widget build(BuildContext context) {
    final priorityColor = Color(priorityColors[task.priority] ?? 0xFF999999);
    final severityColor = Color(priorityColors[task.severity] ?? 0xFF999999);
    final nextStatus = _kNextStatus[task.status];
    final nextLabel = _kNextLabel[task.status];
    final initials = task.assignedEngineer.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();

    return InkWell(
      onTap: () => onSelect(task),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(task.trackingId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9999)),
                  child: Text(task.priority, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: priorityColor)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(task.distressType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _metaRow('Severity:', task.severity, valueColor: severityColor),
            _metaRow('Impact:', task.roadHealthImpact),
            _metaRow('Due Date:', task.dueDate),
            const Divider(height: 12),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accentBlueLight, shape: BoxShape.circle),
                  child: Text(initials, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.assignedEngineer.split(' ').first,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(formatCost(task.estimatedCost), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
            if (nextStatus != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => onAdvance(task, nextStatus),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 24),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: BorderSide(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nextLabel ?? '', style: const TextStyle(fontSize: 9)),
                      const SizedBox(width: 2),
                      const Icon(LucideIcons.arrowRight, size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}
