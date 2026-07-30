import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/road_distress_api.dart';
import '../../../theme/app_colors.dart';

/// Direct-ish port of DashboardGrid.tsx's embedded Leaflet map: a real
/// interactive OpenStreetMap view (flutter_map, same approach as the GIS Map
/// screen) with severity-colored markers for every distress with valid
/// coordinates. The React source's four floating map-control buttons
/// (Compass/Plus/Minus/Layers) have no `onClick` handlers at all -- they're
/// decorative in the reference app too -- so only Plus/Minus are wired here
/// (a natural free win since a MapController is already needed for the
/// legend/marker rendering), while Compass/Layers stay decorative to match.
class DashboardGisMapCard extends StatefulWidget {
  const DashboardGisMapCard({super.key, required this.distresses});

  final List<DistressRecord> distresses;

  @override
  State<DashboardGisMapCard> createState() => _DashboardGisMapCardState();
}

class _DashboardGisMapCardState extends State<DashboardGisMapCard> {
  final _mapController = MapController();
  double _zoom = 12;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _markerColor(String severity) {
    final s = severity.toLowerCase();
    if (s == 'critical' || s == 'high') return const Color(0xFFEF4444);
    if (s == 'medium') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final validMarkers = widget.distresses
        .where((d) => d.latitude.isFinite && d.longitude.isFinite)
        .toList();
    final center = validMarkers.isNotEmpty
        ? LatLng(validMarkers.first.latitude, validMarkers.first.longitude)
        : const LatLng(37.7749, -122.4194);

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.map, size: 16, color: AppColors.primaryText),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Geospatial Mapping (GIS)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text(
                    'ONLINE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _legendDot(const Color(0xFFEF4444), 'Critical'),
                const SizedBox(width: 10),
                _legendDot(const Color(0xFFEF4444), 'High'),
                const SizedBox(width: 10),
                _legendDot(const Color(0xFFF59E0B), 'Medium'),
                const SizedBox(width: 10),
                _legendDot(const Color(0xFF10B981), 'Low'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _zoom,
                    onPositionChanged: (camera, hasGesture) => setState(() => _zoom = camera.zoom),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.thapar.akcm.road_distress',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final d in validMarkers)
                          Marker(
                            point: LatLng(d.latitude, d.longitude),
                            width: 16,
                            height: 16,
                            child: GestureDetector(
                              onTap: () => _showInfo(context, d),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _markerColor(d.severity),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    children: [
                      _mapBtn(LucideIcons.compass, () {}),
                      const SizedBox(height: 6),
                      _mapBtn(LucideIcons.plus, () => _mapController.move(_mapController.camera.center, _zoom + 1)),
                      const SizedBox(height: 6),
                      _mapBtn(LucideIcons.minus, () => _mapController.move(_mapController.camera.center, _zoom - 1)),
                      const SizedBox(height: 6),
                      _mapBtn(LucideIcons.layers, () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, DistressRecord d) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(d.distressType.replaceAll('_', ' ')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Severity: ${d.severity.toUpperCase()}'),
            Text('Confidence: ${(d.confidenceScore * 100).round()}%'),
            Text('GPS: ${d.latitude.toStringAsFixed(5)}°, ${d.longitude.toStringAsFixed(5)}°'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
      ],
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
        ),
        child: Icon(icon, size: 14, color: AppColors.primaryText),
      ),
    );
  }
}
