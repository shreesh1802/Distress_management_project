import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/reports_api.dart';
import 'package:mobile/screens/reports/widgets/registry_overview_card.dart';
import 'package:mobile/screens/reports/widgets/report_preview_modal.dart';
import 'package:mobile/screens/reports/widgets/reports_registry_card.dart';

List<ReportItem> _sampleReports() {
  return const [
    ReportItem(
      id: 'Safety_Audit_Report_Video_12_with_a_very_long_report_name_for_overflow_testing',
      roadId: 'Road-12',
      district: 'Nagpur',
      distressType: 'Alligator Cracks',
      severity: 'Critical',
      generatedDate: '2026-07-29',
      status: 'Exported',
      reportType: 'PDF',
      size: '1.8 MB',
      generatedBy: 'Rajesh Kulkarni',
      downloadCount: 40,
      reportId: 101,
      filepath: 'reports/pdf_101.pdf',
    ),
    ReportItem(
      id: 'Excel_Safety_Audit_Report_Video_7',
      roadId: 'Road-7',
      district: 'Pune',
      distressType: 'Rutting',
      severity: 'Medium',
      generatedDate: '2026-07-01',
      status: 'Exported',
      reportType: 'EXCEL',
      size: '240 KB',
      generatedBy: 'System Auditor',
      downloadCount: 25,
      reportId: 102,
      filepath: 'reports/excel_102.xlsx',
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
  testWidgets('ReportsRegistryCard renders with sample reports', (tester) async {
    final reports = _sampleReports();
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1400,
        child: ReportsRegistryCard(
          filteredReports: reports,
          paginatedReports: reports,
          favorites: {reports.first.id},
          selectedIds: {},
          searchQuery: '',
          typeFilter: 'All',
          severityFilter: 'All',
          statusFilter: 'All',
          startDate: '',
          endDate: '',
          showFavoritesOnly: false,
          currentPage: 1,
          totalPages: 1,
          itemsPerPage: 8,
          onRefresh: () {},
          onSearchChanged: (_) {},
          onTypeChanged: (_) {},
          onSeverityChanged: (_) {},
          onStatusChanged: (_) {},
          onStartDateChanged: (_) {},
          onEndDateChanged: (_) {},
          onFavoritesOnlyChanged: (_) {},
          onSelectAllFiltered: () {},
          onToggleSelect: (_) {},
          onToggleFavorite: (_) {},
          onPreview: (_) {},
          onDownload: (_) {},
          onDelete: (_) {},
          onPrevPage: () {},
          onNextPage: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Generated Reports Registry'), findsOneWidget);
    expect(find.text('Road-12'), findsOneWidget);
    expect(find.text('Road-7'), findsOneWidget);
  });

  testWidgets('RegistryOverviewCard renders with sample reports', (tester) async {
    final reports = _sampleReports();
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 500,
        child: RegistryOverviewCard(allReports: reports, filteredReports: reports),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Registry Overview'), findsOneWidget);
    expect(find.text('Database Sync Status:'), findsOneWidget);
  });

  testWidgets('ReportPreviewModal renders PDF cover preview', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1200,
        height: 900,
        child: ReportPreviewModal(
          report: _sampleReports()[0],
          onClose: () {},
          onDownload: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ROAD DISTRESS AUDIT DOCUMENT'), findsOneWidget);
  });

  testWidgets('ReportPreviewModal renders Excel mock preview', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 1200,
        height: 900,
        child: ReportPreviewModal(
          report: _sampleReports()[1],
          onClose: () {},
          onDownload: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sheet1 -'), findsOneWidget);
  });
}
