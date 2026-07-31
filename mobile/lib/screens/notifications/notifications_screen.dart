import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import 'notification_item.dart';
import 'widgets/notification_detail_modal.dart';
import 'widgets/notification_feed.dart';
import 'widgets/notifications_analytics_footer.dart';
import 'widgets/notifications_filters_bar.dart';
import 'widgets/notifications_kpi_row.dart';
import 'widgets/notifications_sidebar_widgets.dart';
import 'widgets/notifications_timeline_section.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// Notifications/Notifications.tsx (~1,133 lines). Unlike every other
/// screen ported so far, this one has **no backend tie of any kind** in
/// the source -- there's no `apiService` import and no fetch call
/// anywhere in the file, just a fixed local array of 9 notifications
/// mutated via local state (mark read/unread, delete, assign). This port
/// follows the same "port the mock data as designed" approach already
/// used for Overview Dashboard, rather than treating any of it as fake
/// data to trim -- there's no real/fake split within this screen the way
/// there was in, say, History's hybrid real-timeline-plus-fake-system-
/// events. See `notification_item.dart` for the exact mock dataset and
/// `widgets/notifications_timeline_section.dart` /
/// `widgets/notifications_analytics_footer.dart` for the two other fully
/// hardcoded demo sections (Incident Mitigation Timeline, Average
/// Mitigation Time chart).
///
/// Trimmed: the fake per-KPI-card trend badges and SVG sparklines (see
/// `widgets/notifications_kpi_row.dart`) -- arbitrary uncomputed
/// percentages layered onto otherwise-real KPI counts, same reasoning as
/// the equivalent trims on Analytics and History.
///
/// "Assign" is ported as a dialog with a text field (defaulting to "Crew
/// Alpha") instead of the source's `window.prompt`, since Flutter has no
/// direct prompt() equivalent; "Refresh" and the assign-confirmation both
/// show a SnackBar in place of the source's `alert()`.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = buildInitialNotifications();

  String _search = '';
  NotificationFilters _filters = const NotificationFilters();
  String _dateRange = 'All';
  final Set<String> _collapsedGroups = {};
  NotificationItem? _selectedNotif;

  void _handleMarkAllRead() {
    setState(() {
      _notifications = [for (final n in _notifications) n.copyWith(unread: false)];
    });
  }

  void _handleToggleRead(NotificationItem item) {
    setState(() {
      _notifications = [for (final n in _notifications) n.id == item.id ? n.copyWith(unread: !n.unread) : n];
      if (_selectedNotif?.id == item.id) {
        _selectedNotif = _selectedNotif!.copyWith(unread: !_selectedNotif!.unread);
      }
    });
  }

  void _handleDelete(NotificationItem item) {
    setState(() {
      _notifications = _notifications.where((n) => n.id != item.id).toList();
      if (_selectedNotif?.id == item.id) _selectedNotif = null;
    });
  }

  Future<void> _handleAssign(NotificationItem item) async {
    final controller = TextEditingController(text: 'Crew Alpha');
    final crewName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign alert to maintenance crew'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Crew Alpha, Crew Bravo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Assign')),
        ],
      ),
    );
    if (crewName == null || crewName.isEmpty) return;
    setState(() {
      _notifications = [
        for (final n in _notifications)
          if (n.id == item.id) n.copyWith(assignedTo: crewName, priority: 'Medium') else n,
      ];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alert successfully assigned to $crewName.')));
  }

  void _toggleGroupCollapsed(String group) {
    setState(() {
      if (!_collapsedGroups.remove(group)) _collapsedGroups.add(group);
    });
  }

  List<NotificationItem> get _filteredNotifications {
    final query = _search.toLowerCase();
    return _notifications.where((n) {
      final matchesSearch = n.title.toLowerCase().contains(query) ||
          n.message.toLowerCase().contains(query) ||
          (n.roadId?.toLowerCase().contains(query) ?? false) ||
          (n.location?.toLowerCase().contains(query) ?? false);
      if (!matchesSearch) return false;
      if (_filters.priority != 'All' && n.priority != _filters.priority) return false;
      if (_filters.category != 'All' && n.category != _filters.category) return false;
      if (_filters.status == 'Unread' && !n.unread) return false;
      if (_filters.status == 'Read' && n.unread) return false;
      if (_filters.district != 'All' && n.district != _filters.district) return false;
      if (_filters.road != 'All' && n.roadId != _filters.road) return false;
      if (_filters.pipeline != 'All' && n.pipeline != _filters.pipeline) return false;
      if (_dateRange != 'All' && n.dateGroup != _dateRange) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    final unreadCount = _notifications.where((n) => n.unread).length;
    final criticalCount = _notifications.where((n) => n.priority == 'Critical').length;
    final todayCount = _notifications.where((n) => n.dateGroup == 'Today').length;
    final resolvedCount = _notifications.where((n) => n.priority == 'Success').length;

    final categoryCounts = {'Detection': 0, 'Maintenance': 0, 'Reports': 0, 'System': 0, 'GIS': 0, 'Uploads': 0};
    for (final n in filtered) {
      if (categoryCounts.containsKey(n.category)) categoryCounts[n.category] = categoryCounts[n.category]! + 1;
    }

    final trend = [
      const TrendPoint('08:00', 2, 4),
      const TrendPoint('10:00', 5, 8),
      const TrendPoint('12:00', 3, 6),
      const TrendPoint('14:00', 7, 12),
      const TrendPoint('16:00', 4, 9),
      const TrendPoint('18:00', 8, 15),
      TrendPoint('20:00', todayCount, todayCount * 2),
    ];

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(unreadCount),
            const SizedBox(height: 20),
            NotificationsKpiRow(
              unreadCount: unreadCount,
              criticalCount: criticalCount,
              todayCount: todayCount,
              resolvedCount: resolvedCount,
            ),
            const SizedBox(height: 20),
            NotificationsFiltersBar(
              filters: _filters,
              onChanged: (f) => setState(() => _filters = f),
              onClearAll: () => setState(() {
                _filters = const NotificationFilters();
                _search = '';
                _dateRange = 'All';
              }),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final feed = NotificationFeed(
                  notifications: filtered,
                  collapsedGroups: _collapsedGroups,
                  onToggleGroup: _toggleGroupCollapsed,
                  onView: (n) => setState(() => _selectedNotif = n),
                  onAssign: _handleAssign,
                  onToggleRead: _handleToggleRead,
                  onDelete: _handleDelete,
                );
                final sidebar = Column(
                  children: [
                    QuickIncidentSummaryCard(
                      critical: filtered.where((n) => n.priority == 'Critical').length,
                      unread: filtered.where((n) => n.unread).length,
                      maintenance: filtered.where((n) => n.category == 'Maintenance').length,
                      reports: filtered.where((n) => n.category == 'Reports').length,
                      aiJobs: filtered.where((n) => n.category == 'Detection').length,
                    ),
                    const SizedBox(height: 20),
                    AlertCategoriesCard(data: categoryCounts),
                    const SizedBox(height: 20),
                    RecentEventLogCard(items: _notifications),
                  ],
                );
                if (constraints.maxWidth < 1100) {
                  return Column(children: [feed, const SizedBox(height: 20), sidebar]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: feed),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: sidebar),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const NotificationsTimelineSection(),
            const SizedBox(height: 20),
            NotificationsAnalyticsFooter(trend: trend, categoryData: categoryCounts),
          ],
        ),
        if (_selectedNotif != null)
          NotificationDetailModal(
            notification: _selectedNotif!,
            onClose: () => setState(() => _selectedNotif = null),
            onToggleRead: () => _handleToggleRead(_selectedNotif!),
            onAssign: () {
              final notif = _selectedNotif!;
              setState(() => _selectedNotif = null);
              _handleAssign(notif);
            },
            onDelete: () => _handleDelete(_selectedNotif!),
          ),
      ],
    );
  }

  Widget _header(int unreadCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accentBlueLight, borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.bell, size: 22, color: AppColors.accentBlue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Center',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTextLight,
                      shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
                    ),
                  ),
                  Text(
                    'Real-time AI alerts, operational events, maintenance updates, and system notifications.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search notifications...',
                  hintStyle: const TextStyle(fontSize: 12),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cardBorder)),
                ),
              ),
            ),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.cardBg, border: Border.all(color: AppColors.cardBorder), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dateRange,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Time', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Today', child: Text('Today', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Earlier', child: Text('Earlier', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _dateRange = v ?? 'All'),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: unreadCount == 0 ? null : _handleMarkAllRead,
              icon: const Icon(LucideIcons.checkCircle2, size: 14),
              label: const Text('Mark All Read', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
            ),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing operations feed... (Simulated)')),
              ),
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('Refresh', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryTextLight, side: const BorderSide(color: AppColors.secondaryTextLight)),
            ),
          ],
        ),
      ],
    );
  }
}
