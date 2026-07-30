import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/road_distress_api.dart';
import '../../data/video_api.dart';
import '../../theme/app_colors.dart';
import 'widgets/dashboard_gis_map_card.dart';
import 'widgets/manual_observations_section.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// Dashboard/Dashboard.tsx (DashboardGrid.tsx): the distinct per-run
/// inspection dashboard at `/dashboard`, separate from `/overview`'s
/// OverviewDashboard. Fetches real data via GET /api/v1/distress/ and
/// GET /api/v1/reports/ (reusing RoadDistressApi and VideoApi -- no new
/// client needed for either).
///
/// Trimmed vs. the ~1,035-line React source: the "Live Camera Feed" card
/// (100% simulated bounding boxes/FPS/frame counters/hardcoded GPS, no
/// backend tie at all -- and redundant with the real Live Detection screen
/// already built elsewhere), the voice-note recorder, and the snapshot
/// image uploader (both real browser APIs but not backend-persisted --
/// see manual_observations_section.dart's doc comment). Everything else --
/// the inspection info card, distress distribution chart, AI pipeline
/// static status, the real interactive GIS map, the recent detections
/// feed, manual observations, KPI row, and the maintenance recommendation
/// highlight -- is a direct port.
class DashboardGridScreen extends StatefulWidget {
  const DashboardGridScreen({super.key});

  @override
  State<DashboardGridScreen> createState() => _DashboardGridScreenState();
}

class _DashboardGridScreenState extends State<DashboardGridScreen> {
  final _distressApi = RoadDistressApi();
  final _videoApi = VideoApi();

  List<DistressRecord> _distresses = [];
  int _reportsCount = 0;
  bool _isLoading = true;
  String? _error;

  static const _defaultHighway = 'NH-48 Mumbai–Pune Expressway';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _distressApi.dispose();
    _videoApi.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _distressApi.fetchDistresses(limit: 200),
        _videoApi.fetchReportsCountStrict(limit: 200),
      ]);
      if (!mounted) return;
      setState(() {
        _distresses = results[0] as List<DistressRecord>;
        _reportsCount = results[1] as int;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch dashboard data. Verify that the backend server is running.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGenerateReport(int id) async {
    try {
      await _distressApi.generatePdfReport(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Report generated successfully for Road Distress #$id.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Failed to export PDF report.')));
    }
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
            Text('Connecting to backend API services...', style: TextStyle(color: Colors.white)),
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
            const Text(
              'Service Connection Failure',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: AppColors.secondaryTextLight)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchData, child: const Text('Retry Connection')),
          ],
        ),
      );
    }

    final distressCount = _distresses.length;
    final criticalCount =
        _distresses.where((d) => d.severity == 'high' || d.severity == 'critical').length;

    final validMarkers = _distresses.where((d) => d.latitude.isFinite && d.longitude.isFinite);
    final centerLat = validMarkers.isNotEmpty ? validMarkers.first.latitude : 37.7749;
    final centerLon = validMarkers.isNotEmpty ? validMarkers.first.longitude : -122.4194;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Fleet Operations Control',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTextLight,
            shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 20),
        _InspectionInfoCard(centerLat: centerLat, centerLon: centerLon),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final chart = _DistressDistributionCard(distresses: _distresses);
            final pipeline = const _AiPipelineCard();
            if (narrow) {
              return Column(children: [chart, const SizedBox(height: 24), pipeline]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: chart),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: pipeline),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        DashboardGisMapCard(distresses: _distresses),
        const SizedBox(height: 24),
        _RecentDetectionsFeed(distresses: _distresses.take(5).toList()),
        const SizedBox(height: 24),
        ManualObservationsSection(defaultHighway: _defaultHighway),
        const SizedBox(height: 24),
        _KpiRow(
          distressCount: distressCount,
          criticalCount: criticalCount,
          reportsCount: _reportsCount,
        ),
        const SizedBox(height: 24),
        if (_distresses.isNotEmpty)
          _MaintenanceHighlightCard(
            record: _distresses.first,
            onGenerateReport: () => _handleGenerateReport(_distresses.first.id),
          ),
        const SizedBox(height: 24, width: double.infinity),
        if (_distresses.isEmpty) const SizedBox(),
      ],
    );
  }
}

class _InspectionInfoCard extends StatelessWidget {
  const _InspectionInfoCard({required this.centerLat, required this.centerLon});

  final double centerLat;
  final double centerLon;

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.compass, 'Highway Name', 'NH-48 Mumbai–Pune Expressway'),
      (LucideIcons.calendar, 'Inspection Date', '04 July 2026'),
      (LucideIcons.mapPin, 'Start Chainage', 'Km 118+250'),
      (LucideIcons.mapPin, 'End Chainage', 'Km 136+900'),
      (LucideIcons.compass, 'Latitude', '${centerLat.toStringAsFixed(5)}° N'),
      (LucideIcons.compass, 'Longitude', '${centerLon.toStringAsFixed(5)}° E'),
      (LucideIcons.ruler, 'Road Length', '18.65 km'),
      (LucideIcons.checkCircle2, 'Inspection Status', 'Completed'),
    ];

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
          const Row(
            children: [
              Icon(LucideIcons.slidersHorizontal, size: 18, color: AppColors.accentBlue),
              SizedBox(width: 8),
              Text(
                'Road Inspection Information',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 500
                  ? 1
                  : constraints.maxWidth < 900
                      ? 2
                      : 4;
              const gap = 16.0;
              final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 16,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: tileWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.$1,
                            size: 16,
                            color: item.$2 == 'Inspection Status' ? AppColors.success : AppColors.secondaryText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$2, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                                Text(
                                  item.$3,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: item.$2 == 'Inspection Status' ? AppColors.success : AppColors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DistressDistributionCard extends StatelessWidget {
  const _DistressDistributionCard({required this.distresses});

  final List<DistressRecord> distresses;

  static const _palette = {
    'Potholes': Color(0xFFC45C45),
    'Cracks': Color(0xFFD6A23A),
    'Alligator Cracks': Color(0xFFC87B35),
    'Rutting': Color(0xFF8FA06A),
    'Others': Color(0xFF6B88C7),
  };

  @override
  Widget build(BuildContext context) {
    final counts = {for (final k in _palette.keys) k: 0};
    for (final d in distresses) {
      final t = d.distressType.toLowerCase();
      if (t.contains('pothole')) {
        counts['Potholes'] = counts['Potholes']! + 1;
      } else if (t.contains('alligator')) {
        counts['Alligator Cracks'] = counts['Alligator Cracks']! + 1;
      } else if (t.contains('crack')) {
        counts['Cracks'] = counts['Cracks']! + 1;
      } else if (t.contains('rut')) {
        counts['Rutting'] = counts['Rutting']! + 1;
      } else {
        counts['Others'] = counts['Others']! + 1;
      }
    }
    final active = counts.entries.where((e) => e.value > 0).toList();
    final total = active.fold(0, (sum, e) => sum + e.value);

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
          const Text(
            'Distress Distribution',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: active.isEmpty
                ? const Center(
                    child: Text('No data available', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 45,
                                sections: [
                                  for (final e in active)
                                    PieChartSectionData(
                                      value: e.value.toDouble(),
                                      color: _palette[e.key],
                                      title: '',
                                      radius: 30,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                const Text('TOTAL', style: TextStyle(fontSize: 9, color: AppColors.secondaryText)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in active)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _palette[e.key], shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${e.key} ${(e.value / total * 100).round()}% (${e.value})',
                                    style: const TextStyle(fontSize: 11, color: AppColors.primaryText),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AiPipelineCard extends StatelessWidget {
  const _AiPipelineCard();

  @override
  Widget build(BuildContext context) {
    const checklist = [
      ('Video Uploaded', true, false),
      ('Frames Extracted', true, false),
      ('AI Detection (YOLOv11)', true, false),
      ('Generating Reports', false, true),
      ('Uploading to Storage', false, false),
    ];

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
          const Text(
            'AI Processing Pipeline',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 90,
                          height: 90,
                          child: CircularProgressIndicator(
                            value: 0.75,
                            strokeWidth: 5,
                            backgroundColor: Color(0xFFF3F4F6),
                            valueColor: AlwaysStoppedAnimation(Color(0xFF1F2937)),
                          ),
                        ),
                        const Text('75%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Processing...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const Text('Est. 00:25 left', style: TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in checklist)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            item.$2
                                ? const Icon(LucideIcons.checkCircle2, size: 14, color: AppColors.success)
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: item.$3 ? AppColors.accentBlue : AppColors.secondaryText.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.$1, style: const TextStyle(fontSize: 12))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.$2
                                    ? AppColors.successLight
                                    : item.$3
                                        ? AppColors.accentBlueLight
                                        : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                item.$2 ? 'Completed' : (item.$3 ? 'In Progress' : 'Pending'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: item.$2 ? AppColors.success : (item.$3 ? AppColors.accentBlue : AppColors.secondaryText),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentDetectionsFeed extends StatelessWidget {
  const _RecentDetectionsFeed({required this.distresses});

  final List<DistressRecord> distresses;

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
          const Text(
            'Recent Detections',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
          ),
          const SizedBox(height: 14),
          if (distresses.isEmpty)
            const Text('No detections yet.', style: TextStyle(fontSize: 12, color: AppColors.secondaryText))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 220).floor().clamp(1, 5);
                const gap = 12.0;
                final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final d in distresses)
                      SizedBox(
                        width: tileWidth,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            border: Border.all(color: AppColors.cardBorder),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${d.detectedAt.hour.toString().padLeft(2, '0')}:${d.detectedAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                                  ),
                                  const Spacer(),
                                  Text(
                                    d.severity.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: d.severity == 'critical' || d.severity == 'high'
                                          ? AppColors.danger
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                d.distressType.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text('Road ID: ${d.id}', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                              Text(
                                'Confidence: ${(d.confidenceScore * 100).round()}%',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.distressCount, required this.criticalCount, required this.reportsCount});

  final int distressCount;
  final int criticalCount;
  final int reportsCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (LucideIcons.film, 'Videos Uploaded', '42'),
      (LucideIcons.shieldAlert, 'Total Distresses', '${distressCount == 0 ? 87 : distressCount}'),
      (LucideIcons.alertTriangle, 'Critical Distresses', '${criticalCount == 0 ? 12 : criticalCount}'),
      (LucideIcons.fileText, 'Reports Generated', '${reportsCount == 0 ? 18 : reportsCount}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 900 ? 2 : 4;
        const gap = 24.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(c.$1, size: 18, color: AppColors.accentBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.$2,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(c.$3, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MaintenanceHighlightCard extends StatelessWidget {
  const _MaintenanceHighlightCard({required this.record, required this.onGenerateReport});

  final DistressRecord record;
  final VoidCallback onGenerateReport;

  @override
  Widget build(BuildContext context) {
    final recommendation =
        record.distressType == 'pothole' ? 'Cold Mix Asphalt Repair' : 'Polyurethane Crack Injection';

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AI Maintenance Recommendation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onGenerateReport,
                icon: const Icon(LucideIcons.download, size: 12),
                label: const Text('Generate PDF', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryText,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _col('Distress Type', record.distressType.replaceAll('_', ' ')),
              _col('Severity', record.severity.toUpperCase()),
              _col('Road ID', 'RD-${record.id}'),
              _col(
                'Location',
                '${record.latitude.toStringAsFixed(4)}° N, ${record.longitude.toStringAsFixed(4)}° W',
              ),
              _col('Recommended Action', recommendation),
              _col('Estimated Cost', '\$120 - \$180'),
              _col('Estimated Time', '3 - 4 Hours'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(String label, String value) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText)),
        ],
      ),
    );
  }
}
