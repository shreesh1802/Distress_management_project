import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/gis_api.dart';
import '../../theme/app_colors.dart';
import 'severity_colors.dart';
import 'widgets/distress_summary_panel.dart';
import 'widgets/gis_filters_panel.dart';
import 'widgets/gis_map_card.dart';
import 'widgets/road_details_panel.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/pages/
/// GISMap/GISMap.tsx: fetches real distress records from the backend
/// (`GET /api/v1/distress/`, same as `apiService.getDistressLogs`), same as
/// the React source does -- not mock data, matching the Live Detection
/// screen's precedent for screens with a real backend call.
///
/// The map itself is a real interactive OpenStreetMap view (flutter_map).
/// See gis_map_card.dart's doc comment for what was deliberately trimmed
/// from the React source's decorative-only features (basemap switcher,
/// marker clustering, simulated survey vehicle/route).
class GisMapScreen extends StatefulWidget {
  const GisMapScreen({super.key});

  @override
  State<GisMapScreen> createState() => _GisMapScreenState();
}

class _GisMapScreenState extends State<GisMapScreen> {
  final _api = GisApi();

  List<RoadDistress> _all = [];
  GisFiltersState _appliedFilters = const GisFiltersState();
  RoadDistress? _selected;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _api.fetchDistressLogs(limit: 100);
      if (!mounted) return;
      setState(() {
        _all = logs;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not reach the backend to load distress records.';
      });
    }
  }

  List<RoadDistress> _applyFilters(GisFiltersState f, List<RoadDistress> source) {
    return source.where((d) {
      if (f.state.isNotEmpty && d.state != f.state) return false;
      if (f.district.isNotEmpty && d.district != f.district) return false;
      if (f.distressType.isNotEmpty && d.distressType != f.distressType) return false;
      if (f.severity.isNotEmpty && d.severity != f.severity) return false;
      if (f.startDate.isNotEmpty && d.reportedDate.compareTo(f.startDate) < 0) return false;
      if (f.endDate.isNotEmpty && d.reportedDate.compareTo(f.endDate) > 0) return false;
      return true;
    }).toList();
  }

  List<RoadDistress> get _filtered => _applyFilters(_appliedFilters, _all);

  void _handleSelect(RoadDistress? d) => setState(() => _selected = d);

  void _handleApply(GisFiltersState filters) {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _appliedFilters = filters;
        _isLoading = false;
        final stillVisible = _applyFilters(filters, _all);
        if (_selected != null && !stillVisible.any((d) => d.id == _selected!.id)) {
          _selected = null;
        }
      });
    });
  }

  void _handleReset() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _appliedFilters = const GisFiltersState();
        _selected = null;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final roadsCovered = filtered.map((d) => d.roadId).toSet().length;
    final avgConfidence = filtered.isEmpty
        ? 0
        : (filtered.map((d) => d.confidence).reduce((a, b) => a + b) / filtered.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Road Distress GIS Intelligence',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTextLight,
            shadows: [
              Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Live visualization, spatial overlays, and distress density tracking across routes.',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryTextLight),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                ),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        _KpiRow(
          total: filtered.length,
          critical: filtered.where((d) => d.severity == 'critical').length,
          roadsCovered: roadsCovered,
          avgConfidence: avgConfidence,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 1024;
            final sidebar = GisFiltersPanel(
              initialFilters: _appliedFilters,
              onApply: _handleApply,
              onReset: _handleReset,
            );
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GisMapCard(
                  allDistresses: filtered,
                  distresses: filtered,
                  selectedDistress: _selected,
                  onSelect: _handleSelect,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final bottomNarrow = innerConstraints.maxWidth < 900;
                    final details = RoadDetailsPanel(
                      selectedDistress: _selected,
                      isLoading: _isLoading,
                    );
                    final summary = DistressSummaryPanel(
                      distresses: filtered,
                      isLoading: _isLoading,
                    );
                    if (bottomNarrow) {
                      return Column(
                        children: [details, const SizedBox(height: 24), summary],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: details),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: summary),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _HistoryTable(distresses: filtered, onSelect: _handleSelect),
              ],
            );

            if (narrow) {
              return Column(children: [sidebar, const SizedBox(height: 24), main]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 320, child: sidebar),
                const SizedBox(width: 24),
                Expanded(child: main),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.total,
    required this.critical,
    required this.roadsCovered,
    required this.avgConfidence,
  });

  final int total;
  final int critical;
  final int roadsCovered;
  final int avgConfidence;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCardData(label: 'Total Distresses', value: '$total'),
      _KpiCardData(label: 'Critical Alerts', value: '$critical', valueColor: AppColors.danger),
      _KpiCardData(label: 'Roads Covered', value: '$roadsCovered'),
      _KpiCardData(
        label: 'Avg Confidence',
        value: avgConfidence > 0 ? '$avgConfidence%' : 'N/A',
        valueColor: AppColors.accentBlue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 768 ? 2 : (constraints.maxWidth < 1400 ? 3 : 6);
        final gap = 24.0;
        final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards) SizedBox(width: tileWidth, child: _KpiCard(data: c)),
            SizedBox(
              width: tileWidth,
              child: _KpiCard(
                data: _KpiCardData(
                  label: 'AI Status',
                  value: '',
                  valueWidget: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LiveDot(),
                      SizedBox(width: 6),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _KpiCard(data: _KpiCardData(label: 'Synchronization', value: 'Just Now')),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCardData {
  const _KpiCardData({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          data.valueWidget ??
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: data.valueColor ?? AppColors.primaryText,
                ),
              ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
    );
  }
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.distresses, required this.onSelect});

  final List<RoadDistress> distresses;
  final ValueChanged<RoadDistress?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Spatial Distress Records Registry',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.primaryBg),
              columns: const [
                DataColumn(label: _TableHeader('Road ID')),
                DataColumn(label: _TableHeader('District')),
                DataColumn(label: _TableHeader('Severity')),
                DataColumn(label: _TableHeader('Confidence')),
                DataColumn(label: _TableHeader('Detection Time')),
                DataColumn(label: _TableHeader('Status')),
                DataColumn(label: _TableHeader('Actions')),
              ],
              rows: distresses.isEmpty
                  ? [
                      const DataRow(
                        cells: [
                          DataCell(
                            Text(
                              'No distress records match active filtering rules.',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                          ),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                        ],
                      ),
                    ]
                  : [for (final d in distresses) _row(context, d)],
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, RoadDistress d) {
    final color = severityColor(d.severity);
    return DataRow(
      onSelectChanged: (_) => onSelect(d),
      cells: [
        DataCell(Text('RD-${d.roadId.split('-').last}', style: const TextStyle(fontWeight: FontWeight.w700))),
        DataCell(Text(d.district)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              d.severity.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
        DataCell(Text('${d.confidence}%', style: const TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.w700))),
        DataCell(Text(d.reportedDate)),
        DataCell(
          Text(
            d.maintenanceStatus.replaceAll('_', ' '),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Report generated successfully for ${d.id}')),
                  );
                },
                child: const Text('Report', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => onSelect(d),
                child: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.secondaryText,
      ),
    );
  }
}
