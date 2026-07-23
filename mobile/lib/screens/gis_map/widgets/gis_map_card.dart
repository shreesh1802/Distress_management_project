import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/gis_api.dart';
import '../../../theme/app_colors.dart';
import '../severity_colors.dart';

/// Direct(ish) port of GISMapContainer.tsx + LeafletMap.tsx: a real pannable
/// /zoomable OpenStreetMap view (via flutter_map, the closest Flutter
/// equivalent to the React source's react-leaflet map) with real distress
/// markers, a KPI strip, a live filter-count summary bar, a GPS/telemetry
/// HUD, and a legend/scale footer.
///
/// Deliberately trimmed vs. the React source: no multi-basemap layer
/// switcher (OSM only), no marker clustering, no simulated survey-vehicle
/// marker/route animation, and no highway-route polylines/chainage
/// milestones -- those are decorative simulations not tied to real backend
/// data, so they were dropped to keep this screen's scope to the real,
/// data-driven parts.
class GisMapCard extends StatefulWidget {
  const GisMapCard({
    super.key,
    required this.allDistresses,
    required this.distresses,
    required this.selectedDistress,
    required this.onSelect,
    required this.isLoading,
  });

  /// Unfiltered-by-map-bounds list, used for the KPI strip counts (matches
  /// the React source using the full `distresses` prop there).
  final List<RoadDistress> allDistresses;
  final List<RoadDistress> distresses;
  final RoadDistress? selectedDistress;
  final ValueChanged<RoadDistress?> onSelect;
  final bool isLoading;

  @override
  State<GisMapCard> createState() => _GisMapCardState();
}

class _GisMapCardState extends State<GisMapCard> {
  final MapController _mapController = MapController();
  double _zoom = 5;
  LatLng _center = const LatLng(20.5937, 78.9629);

  @override
  void didUpdateWidget(covariant GisMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedDistress;
    if (selected != null && selected.id != oldWidget.selectedDistress?.id) {
      _mapController.move(
        LatLng(selected.latitude, selected.longitude),
        13,
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  double get _localHealthScore {
    final penalty = widget.distresses.fold<double>(0, (sum, d) {
      final w = switch (d.severity) {
        'critical' => 5.0,
        'high' => 3.0,
        'medium' => 1.5,
        _ => 0.5,
      };
      return sum + w;
    });
    return (100 - penalty).clamp(0, 100);
  }

  Map<String, int> get _summaryCounts {
    final counts = {'critical': 0, 'high': 0, 'medium': 0, 'low': 0};
    for (final d in widget.distresses) {
      if (counts.containsKey(d.severity)) counts[d.severity] = counts[d.severity]! + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _summaryCounts;
    final criticalTotal =
        widget.allDistresses.where((d) => d.severity == 'critical').length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapHeader(
            zoom: _zoom.round(),
            onZoomIn: () => _mapController.move(_mapController.camera.center, _zoom + 1),
            onZoomOut: () => _mapController.move(_mapController.camera.center, _zoom - 1),
          ),
          _KpiStrip(
            vehiclesLabel: '1 Active',
            activeDistresses: widget.isLoading ? null : widget.allDistresses.length,
            criticalAlerts: widget.isLoading ? null : criticalTotal,
          ),
          _FilterSummaryBar(isLoading: widget.isLoading, counts: counts),
          SizedBox(
            height: 580,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _zoom,
                    onPositionChanged: (camera, hasGesture) {
                      setState(() {
                        _zoom = camera.zoom;
                        _center = camera.center;
                      });
                    },
                    onTap: (tapPosition, point) => widget.onSelect(null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.thapar.akcm.road_distress',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final d in widget.distresses)
                          Marker(
                            point: LatLng(d.latitude, d.longitude),
                            width: 28,
                            height: 28,
                            child: _DistressMarker(
                              distress: d,
                              isSelected: widget.selectedDistress?.id == d.id,
                              onTap: () => widget.onSelect(d),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (widget.isLoading)
                  const _LoadingOverlay()
                else ...[
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _CountBadge(count: widget.distresses.length),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: _GpsHud(
                      center: _center,
                      totalDetections: widget.allDistresses.length,
                      visibleDetections: widget.distresses.length,
                      healthScore: _localHealthScore.round(),
                    ),
                  ),
                  if (widget.selectedDistress != null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: _FloatingSelectedCard(
                        distress: widget.selectedDistress!,
                        onClose: () => widget.onSelect(null),
                      ),
                    ),
                  if (widget.distresses.isEmpty)
                    const _EmptyMapOverlay(),
                ],
              ],
            ),
          ),
          _MapFooter(cursor: null),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({
    required this.zoom,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final int zoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.map, size: 20, color: AppColors.primaryText),
          const SizedBox(width: 8),
          const Text(
            'Road Distress Map',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const Spacer(),
          Text(
            'Zoom: $zoom',
            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
          const SizedBox(width: 12),
          _HeaderIconButton(icon: LucideIcons.zoomIn, onTap: onZoomIn, tooltip: 'Zoom In'),
          const SizedBox(width: 6),
          _HeaderIconButton(icon: LucideIcons.zoomOut, onTap: onZoomOut, tooltip: 'Zoom Out'),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: AppColors.primaryText),
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.vehiclesLabel,
    required this.activeDistresses,
    required this.criticalAlerts,
  });

  final String vehiclesLabel;
  final int? activeDistresses;
  final int? criticalAlerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0x1F000000))),
      ),
      child: Row(
        children: [
          Expanded(child: _KpiTile(label: 'Vehicles', value: vehiclesLabel)),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiTile(
              label: 'Active Distresses',
              value: activeDistresses == null ? '...' : '$activeDistresses',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiTile(
              label: 'Critical Alerts',
              value: criticalAlerts == null ? '...' : '$criticalAlerts',
              valueColor: const Color(0xFFEF4444),
              tinted: true,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: _KpiTile(label: 'Surveyed Today', value: '412.8 km')),
          const SizedBox(width: 12),
          Expanded(
            child: _KpiTile(
              label: 'AI Accuracy',
              value: '94.6%',
              valueColor: AppColors.accentBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.tinted = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tinted ? const Color(0x06EF4444) : Colors.white,
        border: Border.all(
          color: tinted ? const Color(0x40EF4444) : const Color(0x1F000000),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSummaryBar extends StatelessWidget {
  const _FilterSummaryBar({required this.isLoading, required this.counts});

  final bool isLoading;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _SummaryPill(label: 'Total', value: isLoading ? '...' : '$total', dot: AppColors.secondaryText),
          _SummaryPill(
            label: 'Critical',
            value: isLoading ? '...' : '${counts['critical']}',
            dot: severityColor('critical'),
          ),
          _SummaryPill(
            label: 'High',
            value: isLoading ? '...' : '${counts['high']}',
            dot: severityColor('high'),
          ),
          _SummaryPill(
            label: 'Medium',
            value: isLoading ? '...' : '${counts['medium']}',
            dot: severityColor('medium'),
          ),
          _SummaryPill(
            label: 'Low',
            value: isLoading ? '...' : '${counts['low']}',
            dot: severityColor('low'),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value, required this.dot});

  final String label;
  final String value;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistressMarker extends StatelessWidget {
  const _DistressMarker({
    required this.distress,
    required this.isSelected,
    required this.onTap,
  });

  final RoadDistress distress;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(distress.severity);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.35 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 4),
            ],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.accentBlue,
            ),
          ),
          const Text(
            'VISIBLE',
            style: TextStyle(fontSize: 8, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _GpsHud extends StatelessWidget {
  const _GpsHud({
    required this.center,
    required this.totalDetections,
    required this.visibleDetections,
    required this.healthScore,
  });

  final LatLng center;
  final int totalDetections;
  final int visibleDetections;
  final int healthScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF20F172A),
        border: Border.all(color: const Color(0x33FFFFFF)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'GPS TELEMETRY HUD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _HudRow('Center Lat:', '${center.latitude.toStringAsFixed(5)}°'),
          _HudRow('Center Lon:', '${center.longitude.toStringAsFixed(5)}°'),
          _HudRow('Total Detections:', '$totalDetections'),
          _HudRow('Visible Detections:', '$visibleDetections', valueColor: const Color(0xFF60A5FA)),
          _HudRow('Section Health:', '$healthScore%', valueColor: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _HudRow extends StatelessWidget {
  const _HudRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingSelectedCard extends StatelessWidget {
  const _FloatingSelectedCard({required this.distress, required this.onClose});

  final RoadDistress distress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(distress.severity);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldAlert, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  distress.id,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Icon(LucideIcons.x, size: 14, color: AppColors.secondaryText),
              ),
            ],
          ),
          const Divider(height: 14),
          _FloatingRow('Location:', distress.location),
          _FloatingRow('Type:', formatDistressType(distress.distressType)),
          _FloatingRow(
            'Severity:',
            distress.severity.toUpperCase(),
            valueColor: color,
          ),
          _FloatingRow('Confidence:', '${distress.confidence}%'),
          _FloatingRow('Last Updated:', distress.lastInspectionDate),
        ],
      ),
    );
  }
}

class _FloatingRow extends StatelessWidget {
  const _FloatingRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('', style: TextStyle(fontSize: 0)),
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.85),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Loading Geospatial Data...',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMapOverlay extends StatelessWidget {
  const _EmptyMapOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No distress data matches the current filters.',
                style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFooter extends StatelessWidget {
  const _MapFooter({required this.cursor});

  final String? cursor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          const Text(
            'Legend:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(width: 12),
          _LegendDot(color: severityColor('critical'), label: 'Critical'),
          const SizedBox(width: 10),
          _LegendDot(color: severityColor('high'), label: 'High'),
          const SizedBox(width: 10),
          _LegendDot(color: severityColor('medium'), label: 'Medium'),
          const SizedBox(width: 10),
          _LegendDot(color: severityColor('low'), label: 'Low'),
          const Spacer(),
          const Text(
            'Scale 1 : 250,000',
            style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}
