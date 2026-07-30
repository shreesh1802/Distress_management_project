import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import '../combined_task.dart';

const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _kWeekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class CalendarCell {
  const CalendarCell({required this.day, required this.isCurrentMonth, required this.dateString});
  final int day;
  final bool isCurrentMonth;
  final String dateString;
}

/// Direct port of MaintenanceDashboard.tsx's Calendar Schedule view: a
/// month grid with up to 3 task badges per day (colored by status).
class CalendarView extends StatelessWidget {
  const CalendarView({
    super.key,
    required this.year,
    required this.month,
    required this.tasks,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onToday,
    required this.onSelectTask,
  });

  final int year;
  final int month;
  final List<CombinedTask> tasks;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;
  final ValueChanged<CombinedTask> onSelectTask;

  List<CalendarCell> _buildCells() {
    final firstDayOfWeek = DateTime(year, month + 1, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 2, 0).day;
    final daysInPrevMonth = DateTime(year, month + 1, 0).day;
    final cells = <CalendarCell>[];

    for (var i = firstDayOfWeek - 1; i >= 0; i--) {
      final prevDay = daysInPrevMonth - i;
      final prevMonth = month == 0 ? 11 : month - 1;
      final prevYear = month == 0 ? year - 1 : year;
      cells.add(CalendarCell(
        day: prevDay,
        isCurrentMonth: false,
        dateString: '$prevYear-${(prevMonth + 1).toString().padLeft(2, '0')}-${prevDay.toString().padLeft(2, '0')}',
      ));
    }
    for (var i = 1; i <= daysInMonth; i++) {
      cells.add(CalendarCell(
        day: i,
        isCurrentMonth: true,
        dateString: '$year-${(month + 1).toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}',
      ));
    }
    final remaining = 42 - cells.length;
    for (var i = 1; i <= remaining; i++) {
      final nextMonth = month == 11 ? 0 : month + 1;
      final nextYear = month == 11 ? year + 1 : year;
      cells.add(CalendarCell(
        day: i,
        isCurrentMonth: false,
        dateString: '$nextYear-${(nextMonth + 1).toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}',
      ));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    final todayString = DateTime.now().toIso8601String().split('T').first;

    return Container(
      padding: const EdgeInsets.all(16),
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
              Text(
                '${_kMonthNames[month]} $year',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(onPressed: onPrevMonth, icon: const Icon(LucideIcons.chevronLeft, size: 16)),
              OutlinedButton(
                onPressed: onToday,
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.cardBorder)),
                child: const Text('Today', style: TextStyle(fontSize: 12)),
              ),
              IconButton(onPressed: onNextMonth, icon: const Icon(LucideIcons.chevronRight, size: 16)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            children: [
              for (final d in _kWeekdayNames)
                Center(
                  child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondaryText)),
                ),
              for (final cell in cells)
                _DayCell(
                  cell: cell,
                  isToday: cell.dateString == todayString,
                  tasks: tasks.where((t) => t.dueDate == cell.dateString).toList(),
                  onSelectTask: onSelectTask,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.cell, required this.isToday, required this.tasks, required this.onSelectTask});

  final CalendarCell cell;
  final bool isToday;
  final List<CombinedTask> tasks;
  final ValueChanged<CombinedTask> onSelectTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isToday ? AppColors.accentBlueLight : (cell.isCurrentMonth ? Colors.white : AppColors.primaryBg),
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cell.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: cell.isCurrentMonth ? AppColors.primaryText : AppColors.secondaryText.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final t in tasks.take(3))
                    InkWell(
                      onTap: () => onSelectTask(t),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Color(statusColors[t.status] ?? 0xFF76B900),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${t.trackingId} - ${t.distressType}',
                          style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  if (tasks.length > 3)
                    Text('+${tasks.length - 3} more', style: const TextStyle(fontSize: 7, color: AppColors.secondaryText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
