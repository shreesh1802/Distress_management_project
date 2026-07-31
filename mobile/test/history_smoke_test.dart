import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/reports_api.dart';
import 'package:mobile/data/video_api.dart';
import 'package:mobile/screens/history/timeline_event.dart';
import 'package:mobile/screens/history/widgets/activity_timeline.dart';
import 'package:mobile/screens/history/widgets/history_analytics_footer.dart';
import 'package:mobile/screens/history/widgets/history_filters_bar.dart';
import 'package:mobile/screens/history/widgets/history_kpi_row.dart';
import 'package:mobile/screens/history/widgets/history_sidebar_widgets.dart';
import 'package:mobile/screens/history/widgets/inference_run_logs.dart';
import 'package:mobile/screens/history/widgets/reports_archive_table.dart';

List<TimelineEvent> _sampleEvents() {
  return [
    TimelineEvent(
      id: 'report-101',
      type: 'Report Exported',
      category: 'Reports',
      title: 'Report Exported',
      description:
          'Exported summary list "Safety_Audit_Report_Video_12_with_an_extremely_long_report_name_for_overflow_testing" in PDF format.',
      timestamp: DateTime(2026, 7, 28, 14, 30),
      status: 'Success',
      user: 'Admin John',
      reportId: 101,
      reportType: 'PDF',
      size: '18.6 MB',
    ),
    TimelineEvent(
      id: 'inference-7',
      type: 'AI Inference Failed',
      category: 'Inference',
      title: 'AI Inference Failed',
      description: 'Pipeline analysis failed for "Video_7.mp4" due to frame parsing timeout.',
      timestamp: DateTime(2026, 7, 27, 9, 15),
      status: 'Failed',
      user: 'System AI',
      videoId: 7,
      district: 'Pune',
      road: 'SH-4',
      modelVersion: 'v1.3.1',
    ),
  ];
}

List<ReportRecord> _sampleReports() {
  return const [
    ReportRecord(id: 101, reportName: 'Safety_Audit_Report_Video_12', reportType: 'PDF', createdAt: '2026-07-28T14:30:00', generatedAt: '2026-07-28T14:30:00'),
    ReportRecord(id: 102, reportName: 'Excel_Safety_Audit_Report_Video_7', reportType: 'EXCEL', createdAt: '2026-07-27T10:00:00', generatedAt: '2026-07-27T10:00:00'),
  ];
}

List<UploadedVideo> _sampleVideos() {
  return [
    UploadedVideo(id: 12, filename: 'Video_12_with_a_very_long_filename_for_overflow_testing.mp4', processingStatus: 'completed', uploadTimestamp: DateTime(2026, 7, 28)),
    UploadedVideo(id: 7, filename: 'Video_7.mp4', processingStatus: 'failed', uploadTimestamp: DateTime(2026, 7, 27)),
  ];
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('HistoryKpiRow renders sample counts', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 1200,
      child: HistoryKpiRow(totalLogs: 40, reportsExported: 12, inferenceRuns: 8, failedOps: 2),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Total Activity Logs'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets('HistoryFiltersBar renders and reflects selections', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: HistoryFiltersBar(
        filters: const HistoryFilters(status: 'Failed'),
        onChanged: (_) {},
        onClearAll: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Clear All'), findsOneWidget);
  });

  testWidgets('ActivityTimeline renders events with long descriptions', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1000,
      child: ActivityTimeline(
        events: _sampleEvents(),
        isLoading: false,
        onDownloadReport: (_) {},
        onViewReport: (_) {},
        onDeleteReport: (_) {},
        onRetryVideo: (_) {},
        onDeleteVideo: (_) {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Activity Timeline'), findsOneWidget);
    expect(find.text('Report Exported'), findsWidgets);
  });

  testWidgets('SystemStatisticsCard and ActivityDistributionCard render', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 400,
      child: Column(
        children: [
          const SystemStatisticsCard(successOps: 30, failedOps: 3, successRate: '90.9'),
          ActivityDistributionCard(data: const {'Inference': 5, 'Reports': 3, 'Uploads': 2}),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('System Statistics'), findsOneWidget);
    expect(find.text('System Activity Distribution'), findsOneWidget);
  });

  testWidgets('ReportsArchiveTable renders rows with long report names', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1400,
      child: ReportsArchiveTable(
        paginatedReports: _sampleReports(),
        totalFiltered: 2,
        sort: const ReportsSort(ReportSortKey.generatedAt, false),
        onSortChanged: (_) {},
        currentPage: 1,
        totalPages: 1,
        itemsPerPage: 5,
        onPageChanged: (_) {},
        onDownload: (_) {},
        onView: (_) {},
        onDelete: (_) {},
        isLoading: false,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Reports Export Archive'), findsOneWidget);
  });

  testWidgets('InferenceRunLogs renders and expands a card', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: InferenceRunLogs(
        videos: _sampleVideos(),
        reports: _sampleReports(),
        isLoading: false,
        onRetry: (_) {},
        onDelete: (_) {},
        onReviewVideo: (_) {},
        onOpenReport: (_, _) {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Inference Run Logs'), findsOneWidget);

    await tester.tap(find.textContaining('Video_12').first);
    await tester.pumpAndSettle();
    expect(find.text('District Jurisdiction'), findsOneWidget);
  });

  testWidgets('HistoryAnalyticsFooter renders three charts', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1400,
      child: HistoryAnalyticsFooter(
        areaChart: const [DayCount('Jul 20', 3), DayCount('Jul 21', 5)],
        successCount: 10,
        failedCount: 2,
        infoWarningCount: 1,
        topEventTypes: const [EventTypeCount('Report Exported', 6), EventTypeCount('Video Uploaded', 4)],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Activity Trend'), findsOneWidget);
    expect(find.text('Operation Success Rate'), findsOneWidget);
    expect(find.text('Top Event Types'), findsOneWidget);
  });
}
