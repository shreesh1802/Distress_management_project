import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/maintenance/combined_task.dart';
import 'package:mobile/screens/maintenance/widgets/calendar_view.dart';
import 'package:mobile/screens/maintenance/widgets/kanban_board.dart';
import 'package:mobile/screens/maintenance/widgets/maintenance_charts.dart';
import 'package:mobile/screens/maintenance/widgets/task_drawer.dart';
import 'package:mobile/screens/maintenance/widgets/task_table.dart';

List<CombinedTask> _sampleTasks() {
  return [
    const CombinedTask(
      taskId: 1,
      distressId: 10,
      trackingId: 'RD-TRK-10',
      distressType: 'Pothole',
      priority: 'Critical',
      severity: 'Critical',
      estimatedCost: 95000,
      roadHealthImpact: 'Penalty: -5.0 pts',
      assignedEngineer: 'Rajesh Kulkarni',
      dueDate: '2026-07-15',
      damageArea: '0.75 sq m',
      gps: '18.520430, 73.856743',
      recommendation: 'Clean pothole crater, fill with hot asphalt mix.',
      status: 'Pending',
    ),
    const CombinedTask(
      taskId: 2,
      distressId: 11,
      trackingId: 'RD-TRK-11',
      distressType: 'Crack',
      priority: 'Medium',
      severity: 'Medium',
      estimatedCost: 45000,
      roadHealthImpact: 'Penalty: -1.5 pts',
      assignedEngineer: 'Unassigned',
      dueDate: '2026-07-20',
      damageArea: '0.30 sq m',
      gps: '18.5300, 73.8500',
      recommendation: 'Seal crack with elastomeric hot-pour sealant.',
      status: 'Assigned',
    ),
    const CombinedTask(
      taskId: 3,
      distressId: 12,
      trackingId: 'RD-TRK-12',
      distressType: 'Rutting',
      priority: 'High',
      severity: 'High',
      estimatedCost: 65000,
      roadHealthImpact: 'Penalty: -3.0 pts',
      assignedEngineer: 'Suresh Patil',
      dueDate: '2026-07-18',
      damageArea: '1.10 sq m',
      gps: '18.5400, 73.8600',
      recommendation: 'Mill and repave rut channels.',
      status: 'Completed',
    ),
  ];
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('KanbanBoard renders with sample tasks', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1400,
        child: KanbanBoard(tasks: _sampleTasks(), onSelect: (_) {}, onAdvance: (task, status) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('RD-TRK-10'), findsOneWidget);
  });

  testWidgets('TaskTable renders with sample tasks', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1400,
        child: TaskTable(
          paginatedTasks: _sampleTasks(),
          totalFiltered: 3,
          currentPage: 1,
          totalPages: 1,
          itemsPerPage: 8,
          onSelect: (_) {},
          onPrev: () {},
          onNext: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('RD-TRK-11'), findsOneWidget);
  });

  testWidgets('CalendarView renders a month grid', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1400,
        height: 800,
        child: CalendarView(
          year: 2026,
          month: 6,
          tasks: _sampleTasks(),
          onPrevMonth: () {},
          onNextMonth: () {},
          onToday: () {},
          onSelectTask: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('TaskDrawer renders task details', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1400,
        height: 900,
        child: TaskDrawer(
          task: _sampleTasks().first,
          engineers: const [],
          onClose: () {},
          onStatusChanged: (_) {},
          onEngineerChanged: (_) {},
          onDueDateChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('RD-TRK-10'), findsOneWidget);
  });

  testWidgets('MaintenanceCharts renders with sample tasks', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1400,
        child: MaintenanceCharts(tasks: _sampleTasks()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Priority Workload Distribution'), findsOneWidget);
    expect(find.text('Operations Stage Allocation'), findsOneWidget);
  });
}
