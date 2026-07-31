import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/data/road_distress_api.dart';
import 'package:mobile/data/video_api.dart';
import 'package:mobile/screens/analytics/widgets/analytics_map_card.dart';
import 'package:mobile/screens/analytics/widgets/distress_donut_card.dart';
import 'package:mobile/screens/analytics/widgets/inspections_table.dart';
import 'package:mobile/screens/analytics/widgets/kpi_grid.dart';
import 'package:mobile/screens/analytics/widgets/priority_cost_row.dart';
import 'package:mobile/screens/analytics/widgets/road_health_gauge.dart';
import 'package:mobile/screens/analytics/widgets/severity_stacked_card.dart';
import 'package:mobile/screens/analytics/widgets/summary_section.dart';
import 'package:mobile/screens/analytics/widgets/timeline_scatter_row.dart';

DistressRecord _distress({required int id, required int videoId, required String severity, required String type}) {
  return DistressRecord(
    id: id,
    distressType: type,
    severity: severity,
    confidenceScore: 0.91,
    latitude: 18.52 + id * 0.001,
    longitude: 73.85 + id * 0.001,
    detectedAt: DateTime(2026, 7, 20 + id % 5),
    status: 'detected',
    videoId: videoId,
    affectedArea: 0.4,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  final distresses = [
    _distress(id: 1, videoId: 10, severity: 'critical', type: 'pothole'),
    _distress(id: 2, videoId: 10, severity: 'high', type: 'alligator_cracks_with_a_very_long_name'),
    _distress(id: 3, videoId: 11, severity: 'medium', type: 'rutting'),
  ];

  final videos = [
    UploadedVideo(
      id: 10,
      filename: 'Video_10_survey_run_with_a_long_filename_for_overflow.mp4',
      processingStatus: 'completed',
      uploadTimestamp: DateTime(2026, 7, 25),
      processingDuration: 42.3,
    ),
    UploadedVideo(id: 11, filename: 'Video_11.mp4', processingStatus: 'completed', uploadTimestamp: DateTime(2026, 7, 26)),
  ];

  testWidgets('AnalyticsKpiGrid renders sample KPIs', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1400,
      child: AnalyticsKpiGrid(kpis: const [
        AnalyticsKpi(icon: Icons.video_camera_back, label: 'Videos Processed', value: '12', borderColor: Colors.blue, trendLabel: '↑ +2 Today'),
        AnalyticsKpi(icon: Icons.layers, label: 'Total Distresses', value: '340', borderColor: Colors.orange),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('VIDEOS PROCESSED'), findsOneWidget);
  });

  testWidgets('RoadHealthGauge renders score', (tester) async {
    await tester.pumpWidget(_wrap(const RoadHealthGauge(score: 82, color: Color(0xFF8FA06A), label: 'Good')));
    await tester.pumpAndSettle();
    expect(find.text('82'), findsOneWidget);
    expect(find.text('GOOD'), findsOneWidget);
  });

  testWidgets('AnalyticsMapCard renders clustered markers', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 900,
      child: AnalyticsMapCard(
        clusters: [
          DistressCluster(lat: 18.521, lng: 73.851, items: [distresses[0], distresses[1]]),
          DistressCluster(lat: 18.523, lng: 73.853, items: [distresses[2]]),
        ],
        center: const LatLng(18.52, 73.85),
        videos: videos,
        allDistresses: distresses,
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Geographic Mapping Summary'), findsOneWidget);
  });

  testWidgets('DistressDonutCard renders with sample counts', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 500,
      child: DistressDonutCard(data: const {'Pothole': 5, 'Alligator cracks': 3, 'Rutting': 2}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL'), findsOneWidget);
  });

  testWidgets('SeverityStackedCard renders with sample runs', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 700,
      child: SeverityStackedCard(
        data: const [
          SeverityRunData(name: 'Run #10', counts: {'critical': 1, 'high': 1, 'medium': 0, 'low': 0}),
          SeverityRunData(name: 'Run #11', counts: {'critical': 0, 'high': 0, 'medium': 1, 'low': 0}),
        ],
        hiddenSeverities: const {},
        onToggleSeverity: (_) {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Severity Stacked Distribution'), findsOneWidget);
  });

  testWidgets('PriorityCostRow renders with sample data', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: PriorityCostRow(
        priorities: const [PriorityCount('P1', 3), PriorityCount('P2', 1), PriorityCount('P3', 0), PriorityCount('P4', 0)],
        costs: const [CostRow(name: 'Pothole', estimated: 120, average: 40, highest: 60)],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Priority Index Distribution'), findsOneWidget);
    expect(find.text('Maintenance Cost Analysis (₹ in Thousands)'), findsOneWidget);
  });

  testWidgets('TimelineScatterRow renders with sample points', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1200,
      child: TimelineScatterRow(
        timeline: const [TimelinePoint('Jul 20', 3), TimelinePoint('Jul 21', 5)],
        period: 'daily',
        onPeriodChanged: (_) {},
        scatter: const [ScatterPoint(area: 0.3, impact: 3.0, severity: 'high')],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Detection Frequency Timeline'), findsOneWidget);
  });

  testWidgets('InspectionsTable renders rows with long filenames', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      width: 1400,
      child: InspectionsTable(
        rows: [
          InspectionRow(video: videos[0], distressCount: 2, healthScore: 92),
          InspectionRow(video: videos[1], distressCount: 1, healthScore: 60),
        ],
        showDuration: true,
        onAnalyze: () {},
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('92%'), findsOneWidget);
  });

  testWidgets('MaintenanceReportsSummaryRow renders sample counts', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 1200,
      child: MaintenanceReportsSummaryRow(
        pending: 2,
        assigned: 1,
        inProgress: 3,
        completed: 5,
        pdfCount: 14,
        excelCount: 8,
        jsonCount: 5,
        latestReportDate: '02/07/2026',
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance Tasks Queue'), findsOneWidget);
  });

  testWidgets('ExecutiveInsightsCard renders insights', (tester) async {
    await tester.pumpWidget(_wrap(const ExecutiveInsightsCard(insights: [
      'Most detected distress is Pothole.',
      'Critical defects account for 20% of detections.',
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Most detected distress is Pothole.'), findsOneWidget);
  });

  testWidgets('AiModelPerformanceCard renders fields', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox(
      width: 1200,
      child: AiModelPerformanceCard(averageConfidence: '91%'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('91%'), findsOneWidget);
    expect(find.text('YOLOv11s'), findsOneWidget);
  });
}
