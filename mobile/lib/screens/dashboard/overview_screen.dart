import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// Dashboard/OverviewDashboard.tsx and OverviewDashboard.css.
///
/// The React source fetches its datasets from `apiService`; there is no
/// Flutter backend client yet, so this renders the same layout against a
/// representative in-memory dataset shaped like the API responses
/// (RoadDistressResponse / UploadedVideoResponse / MaintenanceTaskResponse).
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = _mockOverviewData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(),
        const SizedBox(height: 24),
        _KpiGrid(kpis: data.kpis),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1024;
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecentInspectionsCard(runs: data.videoRuns),
                const SizedBox(height: 24),
                _ChartsRow(
                  distressDistribution: data.distressDistribution,
                  severityData: data.severityData,
                ),
              ],
            );
            final right = _GisMapCard(
              distressLogs: data.distressLogs,
              criticalCount: data.distressLogs
                  .where((d) => d.severity == 'critical')
                  .length,
            );

            if (narrow) {
              return Column(
                children: [left, const SizedBox(height: 24), right],
              );
            }

            // Not wrapped in IntrinsicHeight: fl_chart's CustomPaint-based
            // charts don't implement intrinsic-height computation properly,
            // which was corrupting this Row's measured height enough to
            // break the ancestor SingleChildScrollView's scroll extent.
            // The two columns don't need to match height exactly.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: left),
                const SizedBox(width: 24),
                Expanded(child: right),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const shadow = [
      Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
      Shadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 2),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Overview Dashboard',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTextLight,
            shadows: shadow,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Global operational metrics, inspect status logs, and spatial '
          'distress density.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondaryTextLight,
            shadows: shadow,
          ),
        ),
      ],
    );
  }
}

class _Kpis {
  const _Kpis({
    required this.totalVideos,
    required this.totalDistresses,
    required this.healthScore,
    required this.totalCostFormatted,
    required this.totalReports,
  });

  final int totalVideos;
  final int totalDistresses;
  final int healthScore;
  final String totalCostFormatted;
  final int totalReports;
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final _Kpis kpis;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCardData(
        icon: LucideIcons.video,
        iconColor: const Color(0xFF6C7354),
        label: 'Total Videos Processed',
        value: '${kpis.totalVideos}',
      ),
      _KpiCardData(
        icon: LucideIcons.shieldAlert,
        iconColor: AppColors.danger,
        label: 'Total Distresses Detected',
        value: '${kpis.totalDistresses}',
      ),
      _KpiCardData(
        icon: LucideIcons.activity,
        iconColor: AppColors.success,
        label: 'Overall Road Health',
        value: '${kpis.healthScore}%',
        valueColor: kpis.healthScore >= 70
            ? AppColors.success
            : AppColors.danger,
      ),
      _KpiCardData(
        icon: LucideIcons.wrench,
        iconColor: AppColors.warning,
        label: 'Estimated Maintenance Cost',
        value: kpis.totalCostFormatted,
      ),
      _KpiCardData(
        icon: LucideIcons.fileText,
        iconColor: const Color(0xFF3B82F6),
        label: 'Total Reports Generated',
        value: '${kpis.totalReports}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 20.0;
        const minTileWidth = 200.0;
        final columns = max(1, (constraints.maxWidth / minTileWidth).floor())
            .clamp(1, cards.length);
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: tileWidth, child: _KpiCard(data: card)),
          ],
        );
      },
    );
  }
}

class _KpiCardData {
  const _KpiCardData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 16, color: data.iconColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  data.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // JetBrainsMono-Variable.ttf has no ₹ glyph (renders as tofu), so
          // that leading character is spanned in Inter, which does.
          Text.rich(
            TextSpan(
              children: [
                if (data.value.startsWith('₹'))
                  const TextSpan(
                    text: '₹',
                    style: TextStyle(fontFamily: 'Inter'),
                  ),
                TextSpan(
                  text: data.value.startsWith('₹')
                      ? data.value.substring(1)
                      : data.value,
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrains Mono',
              color: data.valueColor ?? AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.icon});

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: const Color(0xFF6C7354)),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _RecentInspectionsCard extends StatelessWidget {
  const _RecentInspectionsCard({required this.runs});

  final List<_VideoRun> runs;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Inspections Log',
      child: runs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No videos processed yet. Use the Upload tab to submit '
                  'surveillance feeds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < runs.length && i < 5; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  _InspectionItem(run: runs[i]),
                ],
              ],
            ),
    );
  }
}

class _InspectionItem extends StatelessWidget {
  const _InspectionItem({required this.run});

  final _VideoRun run;

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeFg;
    switch (run.processingStatus) {
      case 'Completed':
        badgeBg = const Color(0xFFE8F5E9);
        badgeFg = const Color(0xFF2E7D32);
      case 'Processing':
        badgeBg = const Color(0xFFFFF3E0);
        badgeFg = const Color(0xFFEF6C00);
      default:
        badgeBg = const Color(0xFFF3F4F6);
        badgeFg = const Color(0xFF6B7280);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  run.filename,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(run.uploadTimestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              run.processingStatus.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeFg,
              ),
            ),
          ),
          _MiniStat(
            label: 'Road Health',
            value: '${run.healthScore}%',
            valueColor: run.healthScore >= 75
                ? AppColors.success
                : AppColors.danger,
          ),
          _MiniStat(
            label: 'Distresses',
            value: '${run.totalDistresses}',
            valueColor: AppColors.primaryText,
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('/inspection/${run.id} is not wired up yet.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C7354),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text('View Inspection'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrains Mono',
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartsRow extends StatelessWidget {
  const _ChartsRow({
    required this.distressDistribution,
    required this.severityData,
  });

  final List<_NamedValue> distressDistribution;
  final List<_SeverityValue> severityData;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 768;
        final pie = _SectionCard(
          title: 'Distress Distribution',
          child: SizedBox(
            height: 200,
            child: _DistressPieChart(data: distressDistribution),
          ),
        );
        final bar = _SectionCard(
          title: 'Severity Level Detections',
          child: SizedBox(
            height: 200,
            child: _SeverityBarChart(data: severityData),
          ),
        );

        if (narrow) {
          return Column(children: [pie, const SizedBox(height: 20), bar]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: pie),
            const SizedBox(width: 20),
            Expanded(child: bar),
          ],
        );
      },
    );
  }
}

class _NamedValue {
  const _NamedValue(this.name, this.value);
  final String name;
  final int value;
}

class _SeverityValue {
  const _SeverityValue(this.name, this.value, this.color);
  final String name;
  final int value;
  final Color color;
}

class _DistressPieChart extends StatelessWidget {
  const _DistressPieChart({required this.data});

  final List<_NamedValue> data;

  static const _palette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 45,
              sections: [
                for (var i = 0; i < data.length; i++)
                  PieChartSectionData(
                    value: data[i].value.toDouble(),
                    color: _palette[i % _palette.length],
                    title: '',
                    radius: 30,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < data.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _palette[i % _palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${data[i].name} (${data[i].value})',
                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SeverityBarChart extends StatelessWidget {
  const _SeverityBarChart({required this.data});

  final List<_SeverityValue> data;

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((d) => d.value).fold(0, max);
    return BarChart(
      BarChartData(
        maxY: (maxVal + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[i].name,
                    style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].value.toDouble(),
                  color: data[i].color,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GisMapCard extends StatelessWidget {
  const _GisMapCard({required this.distressLogs, required this.criticalCount});

  final List<_DistressLog> distressLogs;
  final int criticalCount;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Overall Spatial GIS Map',
      icon: LucideIcons.map,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: CustomPaint(
                size: Size.infinite,
                painter: _GisPainter(distressLogs.take(10).toList()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _GisStatRow(
            label: 'Active GIS Markers:',
            value: '${distressLogs.length}',
            valueColor: AppColors.primaryText,
          ),
          const SizedBox(height: 8),
          _GisStatRow(
            label: 'Critical Zones:',
            value: '$criticalCount',
            valueColor: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _GisStatRow extends StatelessWidget {
  const _GisStatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _GisPainter extends CustomPainter {
  _GisPainter(this.logs);

  final List<_DistressLog> logs;

  static const _viewW = 800.0;
  static const _viewH = 450.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _viewW;
    final sy = size.height / _viewH;
    canvas.save();
    canvas.scale(sx, sy);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _viewW, _viewH),
      Paint()..color = const Color(0xFFF3F4F6),
    );

    final casing = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final grid = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(50, 20)
      ..lineTo(750, 430)
      ..moveTo(100, 430)
      ..lineTo(700, 20)
      ..moveTo(50, 225)
      ..lineTo(750, 225);

    canvas.drawPath(path, casing);
    canvas.drawPath(path, grid);

    for (final d in logs) {
      final x = 100 + (d.latitude * 15) % 600;
      final y = 50 + (d.longitude * 12) % 350;
      final fill = d.severity == 'critical'
          ? AppColors.danger
          : d.severity == 'high'
              ? AppColors.warning
              : AppColors.success;

      canvas.drawCircle(Offset(x, y), 10, Paint()..color = fill.withValues(alpha: 0.3));
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = fill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GisPainter oldDelegate) => oldDelegate.logs != logs;
}

// --- Mock dataset, shaped like apiService's RoadDistressResponse /
// UploadedVideoResponse / MaintenanceTaskResponse until a Flutter API client
// exists. ---

class _DistressLog {
  const _DistressLog({
    required this.videoId,
    required this.severity,
    required this.distressType,
    required this.latitude,
    required this.longitude,
  });

  final int videoId;
  final String severity;
  final String distressType;
  final double latitude;
  final double longitude;
}

class _VideoRun {
  const _VideoRun({
    required this.id,
    required this.filename,
    required this.uploadTimestamp,
    required this.processingStatus,
    required this.totalDistresses,
    required this.healthScore,
  });

  final int id;
  final String filename;
  final DateTime uploadTimestamp;
  final String processingStatus;
  final int totalDistresses;
  final int healthScore;
}

class _OverviewData {
  const _OverviewData({
    required this.kpis,
    required this.videoRuns,
    required this.distressLogs,
    required this.distressDistribution,
    required this.severityData,
  });

  final _Kpis kpis;
  final List<_VideoRun> videoRuns;
  final List<_DistressLog> distressLogs;
  final List<_NamedValue> distressDistribution;
  final List<_SeverityValue> severityData;
}

double _severityWeight(String severity) {
  switch (severity) {
    case 'critical':
      return 5;
    case 'high':
      return 3;
    case 'medium':
      return 1.5;
    default:
      return 0.5;
  }
}

int _healthScoreFor(Iterable<_DistressLog> logs) {
  final penalty = logs.fold(0.0, (sum, d) => sum + _severityWeight(d.severity));
  return max(0, (100 - penalty).round());
}

_OverviewData _mockOverviewData() {
  final now = DateTime.now();

  const distressSeeds = [
    (1, 'critical', 'pothole'),
    (1, 'high', 'crack'),
    (1, 'high', 'crack'),
    (1, 'medium', 'rutting'),
    (1, 'medium', 'edge_break'),
    (2, 'high', 'pothole'),
    (2, 'medium', 'crack'),
    (2, 'medium', 'crack'),
    (2, 'low', 'raveling'),
    (2, 'low', 'raveling'),
    (3, 'critical', 'pothole'),
    (3, 'critical', 'pothole'),
    (3, 'high', 'rutting'),
    (3, 'medium', 'crack'),
    (4, 'high', 'pothole'),
    (4, 'medium', 'edge_break'),
    (4, 'medium', 'rutting'),
    (4, 'low', 'raveling'),
    (5, 'medium', 'crack'),
    (5, 'medium', 'crack'),
    (5, 'low', 'raveling'),
    (5, 'low', 'edge_break'),
  ];

  final distressLogs = <_DistressLog>[
    for (var i = 0; i < distressSeeds.length; i++)
      _DistressLog(
        videoId: distressSeeds[i].$1,
        severity: distressSeeds[i].$2,
        distressType: distressSeeds[i].$3,
        // Spread mock points across the GIS projection's 0-40/0-35 degree
        // span instead of clustering tightly like real nearby NH-48 chainage
        // coordinates would, so the demo map isn't just one overlapping dot.
        latitude: 28.0 + (i * 2.7) % 40,
        longitude: 77.0 + (i * 3.9) % 35,
      ),
  ];

  final videos = <(int, String, int, String)>[
    (1, 'NH48_KM118_Segment_A.mp4', 1, 'Completed'),
    (2, 'NH48_KM122_Segment_B.mp4', 2, 'Completed'),
    (3, 'NH48_KM128_Segment_C.mp4', 3, 'Processing'),
    (4, 'SH12_Bypass_North.mp4', 5, 'Completed'),
    (5, 'SH12_Bypass_South.mp4', 6, 'Pending'),
  ];

  final videoRuns = videos.map((v) {
    final vidLogs = distressLogs.where((d) => d.videoId == v.$1);
    return _VideoRun(
      id: v.$1,
      filename: v.$2,
      uploadTimestamp: now.subtract(Duration(days: v.$3)),
      processingStatus: v.$4,
      totalDistresses: vidLogs.length,
      healthScore: _healthScoreFor(vidLogs),
    );
  }).toList()
    ..sort((a, b) => b.uploadTimestamp.compareTo(a.uploadTimestamp));

  final typeCounts = <String, int>{};
  for (final d in distressLogs) {
    final label = d.distressType.replaceAll('_', ' ');
    final capitalized = label[0].toUpperCase() + label.substring(1);
    typeCounts[capitalized] = (typeCounts[capitalized] ?? 0) + 1;
  }
  final distressDistribution = [
    for (final entry in typeCounts.entries) _NamedValue(entry.key, entry.value),
  ];

  final severityCounts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0};
  for (final d in distressLogs) {
    severityCounts[d.severity] = (severityCounts[d.severity] ?? 0) + 1;
  }
  final severityData = [
    _SeverityValue('Critical', severityCounts['critical']!, AppColors.danger),
    _SeverityValue('High', severityCounts['high']!, AppColors.warning),
    _SeverityValue('Medium', severityCounts['medium']!, const Color(0xFFEAB308)),
    _SeverityValue('Low', severityCounts['low']!, AppColors.success),
  ];

  const maintenanceCosts = [45000.0, 120000.0, 75000.0, 230000.0, 60000.0, 95000.0];
  final totalCost = maintenanceCosts.fold(0.0, (a, b) => a + b);

  final kpis = _Kpis(
    totalVideos: videos.length,
    totalDistresses: distressLogs.length,
    healthScore: _healthScoreFor(distressLogs),
    totalCostFormatted: totalCost > 0
        ? '₹${(totalCost / 100000).toStringAsFixed(2)}L'
        : '₹0.00',
    totalReports: 9,
  );

  return _OverviewData(
    kpis: kpis,
    videoRuns: videoRuns,
    distressLogs: distressLogs,
    distressDistribution: distressDistribution,
    severityData: severityData,
  );
}
