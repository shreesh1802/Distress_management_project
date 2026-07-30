import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/maintenance_api.dart';
import '../../data/road_distress_api.dart';
import '../../theme/app_colors.dart';
import 'combined_task.dart';
import 'widgets/calendar_view.dart';
import 'widgets/kanban_board.dart';
import 'widgets/maintenance_charts.dart';
import 'widgets/task_drawer.dart';
import 'widgets/task_table.dart';

enum _ViewMode { kanban, table, calendar }

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// Maintenance/MaintenanceDashboard.tsx: real backend data joined
/// client-side exactly as the React source does (GET
/// /api/v1/maintenance/recommendations + GET /api/v1/distress/ + GET
/// /api/v1/users/, combined into `CombinedTask`s -- there's no backend
/// endpoint that returns this joined shape directly). The
/// components/maintenance/*.tsx files in the React source are dead code
/// (never imported by any page or route), so nothing there needed porting.
///
/// Trimmed vs. the ~1,067-line React source: the CSV/Excel export buttons
/// and the "PDF Print" button (`window.print()`) -- pure frontend
/// conveniences with no backend tie, same reasoning as the export buttons
/// trimmed from GIS Map and Road Distresses. Everything else -- the KPI
/// row, all three view modes (Kanban/Table/Calendar), the filter bar, the
/// task details drawer, and both analytics charts -- is a direct port.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _maintenanceApi = MaintenanceApi();
  final _distressApi = RoadDistressApi();

  List<CombinedTask> _tasks = [];
  List<AppUser> _engineers = [];
  bool _isLoading = true;
  String? _error;

  _ViewMode _viewMode = _ViewMode.kanban;

  String _searchQuery = '';
  String _priorityFilter = 'All';
  String _severityFilter = 'All';
  String _statusFilter = 'All';
  String _engineerFilter = 'All';
  String _dateFilter = 'All';

  CombinedTask? _selectedTask;

  int _currentYear = 2026;
  int _currentMonth = 6;

  int _currentPage = 1;
  static const _itemsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _maintenanceApi.dispose();
    _distressApi.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _maintenanceApi.fetchRecommendations(),
        _distressApi.fetchDistresses(limit: 1000),
        _maintenanceApi.fetchUsers(limit: 200),
      ]);
      final recs = results[0] as List<MaintenanceRecommendation>;
      final distresses = results[1] as List<DistressRecord>;
      final users = results[2] as List<AppUser>;
      if (!mounted) return;
      setState(() {
        _tasks = CombinedTask.combine(recs, distresses, users);
        _engineers = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch backend maintenance data. Verify server status.';
        _tasks = [];
        _isLoading = false;
      });
    }
  }

  CombinedTask? get _drawerTask {
    final selected = _selectedTask;
    if (selected == null) return null;
    return _tasks.where((t) => t.taskId == selected.taskId).firstOrNull ?? selected;
  }

  List<String> get _uniqueEngineers {
    final set = <String>{};
    for (final t in _tasks) {
      if (t.assignedEngineer != 'Unassigned') set.add(t.assignedEngineer);
    }
    return set.toList();
  }

  List<String> get _uniqueMonths {
    final set = <String>{};
    for (final t in _tasks) {
      if (t.dueDate.length >= 7) set.add(t.dueDate.substring(0, 7));
    }
    final list = set.toList()..sort();
    return list;
  }

  List<CombinedTask> get _filteredTasks {
    final query = _searchQuery.toLowerCase();
    return _tasks.where((t) {
      final matchesSearch = query.isEmpty ||
          t.trackingId.toLowerCase().contains(query) ||
          t.assignedEngineer.toLowerCase().contains(query) ||
          t.priority.toLowerCase().contains(query) ||
          t.status.toLowerCase().contains(query) ||
          t.distressType.toLowerCase().contains(query);
      final matchesPriority = _priorityFilter == 'All' || t.priority == _priorityFilter;
      final matchesSeverity = _severityFilter == 'All' || t.severity == _severityFilter;
      final matchesStatus = _statusFilter == 'All' || t.status == _statusFilter;
      final matchesEngineer = _engineerFilter == 'All' || t.assignedEngineer == _engineerFilter;
      final matchesDate = _dateFilter == 'All' || t.dueDate.startsWith(_dateFilter);
      return matchesSearch && matchesPriority && matchesSeverity && matchesStatus && matchesEngineer && matchesDate;
    }).toList();
  }

  void _handleResetFilters() {
    setState(() {
      _searchQuery = '';
      _priorityFilter = 'All';
      _severityFilter = 'All';
      _statusFilter = 'All';
      _engineerFilter = 'All';
      _dateFilter = 'All';
      _currentPage = 1;
    });
  }

  void _updateStatus(int taskId, String status) {
    setState(() {
      _tasks = [for (final t in _tasks) t.taskId == taskId ? t.copyWith(status: status) : t];
    });
  }

  void _updateEngineer(int taskId, String engineer) {
    setState(() {
      _tasks = [
        for (final t in _tasks)
          if (t.taskId == taskId)
            t.copyWith(
              assignedEngineer: engineer,
              status: engineer != 'Unassigned' && t.status == 'Pending'
                  ? 'Assigned'
                  : (engineer == 'Unassigned' ? 'Pending' : null),
            )
          else
            t,
      ];
    });
  }

  void _updateDueDate(int taskId, String dueDate) {
    setState(() {
      _tasks = [for (final t in _tasks) t.taskId == taskId ? t.copyWith(dueDate: dueDate) : t];
    });
  }

  void _handlePrevMonth() {
    setState(() {
      if (_currentMonth == 0) {
        _currentMonth = 11;
        _currentYear -= 1;
      } else {
        _currentMonth -= 1;
      }
    });
  }

  void _handleNextMonth() {
    setState(() {
      if (_currentMonth == 11) {
        _currentMonth = 0;
        _currentYear += 1;
      } else {
        _currentMonth += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        heightFactor: 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Synchronizing maintenance operations registry...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        heightFactor: 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('Operations Database Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.secondaryTextLight)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Reload Registry Cache')),
          ],
        ),
      );
    }

    final filtered = _filteredTasks;
    final totalPages = (filtered.length / _itemsPerPage).ceil().clamp(1, 1 << 30);
    final paginated = filtered.skip((_currentPage - 1) * _itemsPerPage).take(_itemsPerPage).toList();

    final pending = _tasks.where((t) => t.status == 'Pending').length;
    final completed = _tasks.where((t) => t.status == 'Completed' || t.status == 'Closed').length;
    final critical = _tasks.where((t) => t.priority == 'Critical').length;
    final totalCost = _tasks.fold(0, (sum, t) => sum + t.estimatedCost);
    final avgCost = _tasks.isEmpty ? 0 : (totalCost / _tasks.length).round();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Maintenance Operations Center',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryTextLight,
                shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Analyze, allocate, and schedule road repair workflows, operations budgets, and crew dispatches.',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
            ),
            const SizedBox(height: 20),
            _kpiGrid(pending, completed, critical, totalCost, avgCost),
            const SizedBox(height: 20),
            _viewSelector(),
            const SizedBox(height: 16),
            _filterBar(),
            const SizedBox(height: 20),
            switch (_viewMode) {
              _ViewMode.kanban => KanbanBoard(
                  tasks: filtered,
                  onSelect: (t) => setState(() => _selectedTask = t),
                  onAdvance: (t, status) => _updateStatus(t.taskId, status),
                ),
              _ViewMode.table => TaskTable(
                  paginatedTasks: paginated,
                  totalFiltered: filtered.length,
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  itemsPerPage: _itemsPerPage,
                  onSelect: (t) => setState(() => _selectedTask = t),
                  onPrev: () => setState(() => _currentPage = (_currentPage - 1).clamp(1, totalPages)),
                  onNext: () => setState(() => _currentPage = (_currentPage + 1).clamp(1, totalPages)),
                ),
              _ViewMode.calendar => CalendarView(
                  year: _currentYear,
                  month: _currentMonth,
                  tasks: _tasks,
                  onPrevMonth: _handlePrevMonth,
                  onNextMonth: _handleNextMonth,
                  onToday: () => setState(() {
                    final now = DateTime.now();
                    _currentYear = now.year;
                    _currentMonth = now.month - 1;
                  }),
                  onSelectTask: (t) => setState(() => _selectedTask = t),
                ),
            },
            const SizedBox(height: 24),
            MaintenanceCharts(tasks: filtered),
          ],
        ),
        if (_drawerTask != null)
          TaskDrawer(
            task: _drawerTask!,
            engineers: _engineers,
            onClose: () => setState(() => _selectedTask = null),
            onStatusChanged: (v) => _updateStatus(_drawerTask!.taskId, v),
            onEngineerChanged: (v) => _updateEngineer(_drawerTask!.taskId, v),
            onDueDateChanged: (v) => _updateDueDate(_drawerTask!.taskId, v),
          ),
      ],
    );
  }

  Widget _kpiGrid(int pending, int completed, int critical, int totalCost, int avgCost) {
    final cards = [
      (LucideIcons.clipboardList, 'Pending Tasks', '$pending', 'Awaiting allocation', AppColors.accentBlue),
      (LucideIcons.checkCircle2, 'Completed Tasks', '$completed', 'Resolved work orders', AppColors.success),
      (LucideIcons.alertTriangle, 'Critical Repairs', '$critical', 'P1 critical priority', AppColors.danger),
      (LucideIcons.indianRupee, 'Estimated Budget', formatCost(totalCost), 'Total estimated cost', AppColors.accentBlue),
      (LucideIcons.indianRupee, 'Average Repair Cost', formatCost(avgCost), 'Average per ticket', AppColors.accentBlue),
      (LucideIcons.clock, 'Avg Completion Time', '1.8 Days', 'Operations SLA benchmark', AppColors.accentBlue),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700 ? 2 : (constraints.maxWidth < 1200 ? 3 : 6);
        const gap = 16.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.$2.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                            ),
                          ),
                          Icon(c.$1, size: 15, color: c.$5),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(c.$3, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.$5)),
                      const SizedBox(height: 2),
                      Text(c.$4, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _viewSelector() {
    Widget tab(_ViewMode mode, IconData icon, String label) {
      final active = _viewMode == mode;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => setState(() => _viewMode = mode),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.accentBlue : AppColors.cardBg,
              border: Border.all(color: active ? AppColors.accentBlue : AppColors.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: active ? Colors.white : AppColors.primaryText),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : AppColors.primaryText)),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      children: [
        tab(_ViewMode.kanban, LucideIcons.wrench, 'Kanban Board'),
        tab(_ViewMode.table, LucideIcons.clipboardList, 'Table Registry'),
        tab(_ViewMode.calendar, LucideIcons.calendar, 'Calendar Schedule'),
      ],
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _currentPage = 1;
              }),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(LucideIcons.search, size: 14),
                hintText: 'Search tasks, types, engineers...',
                hintStyle: const TextStyle(fontSize: 11),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.cardBorder)),
              ),
            ),
          ),
          _dropdown('All Statuses', _statusFilter, ['All', 'Pending', 'Assigned', 'In Progress', 'Completed', 'Closed'],
              (v) => setState(() { _statusFilter = v; _currentPage = 1; })),
          _dropdown('All Priorities', _priorityFilter, ['All', 'Critical', 'High', 'Medium', 'Low'],
              (v) => setState(() { _priorityFilter = v; _currentPage = 1; })),
          _dropdown('All Severities', _severityFilter, ['All', 'Critical', 'High', 'Medium', 'Low'],
              (v) => setState(() { _severityFilter = v; _currentPage = 1; })),
          _dropdown('All Engineers', _engineerFilter, ['All', 'Unassigned', ..._uniqueEngineers],
              (v) => setState(() { _engineerFilter = v; _currentPage = 1; })),
          _dropdown('All Months', _dateFilter, ['All', ..._uniqueMonths],
              (v) => setState(() { _dateFilter = v; _currentPage = 1; })),
          OutlinedButton(
            onPressed: _handleResetFilters,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryText, side: BorderSide(color: AppColors.cardBorder)),
            child: const Text('Reset', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String allLabel, String value, List<String> options, ValueChanged<String> onChanged) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(6)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: AppColors.primaryText),
          items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o == 'All' ? allLabel : o))],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}
