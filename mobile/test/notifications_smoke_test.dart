import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/notifications/notification_item.dart';
import 'package:mobile/screens/notifications/widgets/notification_detail_modal.dart';
import 'package:mobile/screens/notifications/widgets/notification_feed.dart';
import 'package:mobile/screens/notifications/widgets/notifications_analytics_footer.dart';
import 'package:mobile/screens/notifications/widgets/notifications_filters_bar.dart';
import 'package:mobile/screens/notifications/widgets/notifications_kpi_row.dart';
import 'package:mobile/screens/notifications/widgets/notifications_sidebar_widgets.dart';
import 'package:mobile/screens/notifications/widgets/notifications_timeline_section.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  final sample = buildInitialNotifications();

  testWidgets('NotificationsKpiRow renders sample counts', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 1200,
      child: NotificationsKpiRow(unreadCount: 4, criticalCount: 3, todayCount: 3, resolvedCount: 2),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Unread Alerts'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('NotificationsFiltersBar renders and shows selections', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: NotificationsFiltersBar(
        filters: const NotificationFilters(priority: 'Critical'),
        onChanged: (_) {},
        onClearAll: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Filter Incident Streams'), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);
  });

  testWidgets('NotificationFeed renders full mock dataset', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1000,
      child: NotificationFeed(
        notifications: sample,
        collapsedGroups: const {},
        onToggleGroup: (_) {},
        onView: (_) {},
        onAssign: (_) {},
        onToggleRead: (_) {},
        onDelete: (_) {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Incident Alert Feed'), findsOneWidget);
    expect(find.text('Critical Distress Found'), findsOneWidget);
    expect(find.text('Work Order Closed'), findsOneWidget);
  });

  testWidgets('NotificationDetailModal renders with thumbnail simulation', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      height: 900,
      child: NotificationDetailModal(
        notification: sample.first,
        onClose: () {},
        onToggleRead: () {},
        onAssign: () {},
        onDelete: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Critical Distress Found'), findsOneWidget);
    expect(find.text('CAM-04 FEED'), findsOneWidget);
  });

  testWidgets('QuickIncidentSummaryCard, AlertCategoriesCard, RecentEventLogCard render', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 400,
      child: Column(
        children: [
          const QuickIncidentSummaryCard(critical: 3, unread: 4, maintenance: 1, reports: 1, aiJobs: 3),
          AlertCategoriesCard(data: const {'Detection': 3, 'Maintenance': 1, 'Reports': 1, 'System': 2, 'GIS': 1, 'Uploads': 1}),
          RecentEventLogCard(items: sample),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Quick Incident Summary'), findsOneWidget);
    expect(find.text('Alert Categories'), findsOneWidget);
    expect(find.text('Recent Event Log'), findsOneWidget);
  });

  testWidgets('NotificationsTimelineSection renders 5 steps', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(width: 1200, child: NotificationsTimelineSection())));
    await tester.pumpAndSettle();
    expect(find.text('Incident Mitigation Timeline'), findsOneWidget);
    expect(find.text('Patching Repair Completed'), findsOneWidget);
  });

  testWidgets('NotificationsAnalyticsFooter renders three charts', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1400,
      child: NotificationsAnalyticsFooter(
        trend: const [TrendPoint('08:00', 2, 4), TrendPoint('20:00', 3, 6)],
        categoryData: const {'Detection': 3, 'Maintenance': 1, 'Reports': 1, 'System': 2, 'GIS': 1, 'Uploads': 1},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Alert Rate Trend'), findsOneWidget);
    expect(find.text('Distribution Ratio'), findsOneWidget);
    expect(find.text('Average Mitigation Time'), findsOneWidget);
  });
}
