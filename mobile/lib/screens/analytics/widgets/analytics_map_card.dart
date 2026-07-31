import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/road_distress_api.dart';
import '../../../data/video_api.dart';
import '../../../theme/app_colors.dart';

Color _severityColor(String severity) {
  switch (severity.toLowerCase()) {
    case 'critical':
      return const Color(0xFFEF4444);
    case 'high':
      return const Color(0xFFF97316);
    case 'medium':
      return const Color(0xFFEAB308);
    case 'low':
      return const Color(0xFF10B981);
    default:
      return const Color(0xFF3B82F6);
  }
}

class DistressCluster {
  const DistressCluster({required this.lat, required this.lng, required this.items});
  final double lat;
  final double lng;
  final List<DistressRecord> items;
}

/// Direct port of AnalyticsDashboard.tsx's "Geographic Mapping Summary"
/// card: a real OpenStreetMap view (via flutter_map, the closest Flutter
/// equivalent to the source's react-leaflet map) with detections clustered
/// by rounded lat/lng exactly as the source's `clusteredMarkers` does.
/// Tapping a marker shows a floating info card in place of Leaflet's
/// anchored `Popup` (the closest Flutter-idiomatic equivalent, matching the
/// approach already used for GIS Map's marker detail card).
class AnalyticsMapCard extends StatefulWidget {
  const AnalyticsMapCard({
    super.key,
    required this.clusters,
    required this.center,
    required this.videos,
    required this.allDistresses,
  });

  final List<DistressCluster> clusters;
  final LatLng center;
  final List<UploadedVideo> videos;
  final List<DistressRecord> allDistresses;

  @override
  State<AnalyticsMapCard> createState() => _AnalyticsMapCardState();
}

class _AnalyticsMapCardState extends State<AnalyticsMapCard> {
  DistressCluster? _selected;

  String _videoName(int? videoId) {
    if (videoId == null) return 'Unknown Video';
    for (final v in widget.videos) {
      if (v.id == videoId) return v.filename;
    }
    return 'Unknown Video';
  }

  int _roadHealthScoreFor(int? videoId) {
    final vidDists = widget.allDistresses.where((d) => d.videoId == videoId);
    final penalty = vidDists.fold<double>(0, (sum, d) {
      final w = switch (d.severity) {
        'critical' => 5.0,
        'high' => 3.0,
        'medium' => 1.5,
        _ => 0.5,
      };
      return sum + w;
    });
    return (100 - penalty).clamp(0, 100).round();
  }

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
          Row(
            children: [
              const Expanded(
                child: Text('Geographic Mapping Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              const Icon(LucideIcons.mapPin, size: 16, color: AppColors.accentBlue),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: widget.clusters.isEmpty
                ? Container(
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🗺️', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text('Leaflet Map Data Unavailable', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
                        ],
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: widget.center,
                            initialZoom: 11,
                            onTap: (_, _) => setState(() => _selected = null),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.thapar.akcm.road_distress',
                            ),
                            MarkerLayer(
                              markers: [
                                for (final cluster in widget.clusters)
                                  Marker(
                                    point: LatLng(cluster.lat, cluster.lng),
                                    width: 30,
                                    height: 30,
                                    child: _ClusterMarker(
                                      cluster: cluster,
                                      onTap: () => setState(() => _selected = cluster),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (_selected != null)
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: _ClusterInfoCard(
                              cluster: _selected!,
                              videoName: _videoName,
                              healthScoreFor: _roadHealthScoreFor,
                              onClose: () => setState(() => _selected = null),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  const _ClusterMarker({required this.cluster, required this.onTap});
  final DistressCluster cluster;
  final VoidCallback onTap;

  String get _highestSeverity {
    const levels = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1};
    var max = 'low';
    for (final d in cluster.items) {
      final s = d.severity.toLowerCase();
      if ((levels[s] ?? 0) > (levels[max] ?? 0)) max = s;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(cluster.items.length > 1 ? _highestSeverity : cluster.items.first.severity);
    final isCluster = cluster.items.length > 1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCluster ? 28 : 14,
        height: isCluster ? 28 : 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 6)],
        ),
        child: isCluster
            ? Text('${cluster.items.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))
            : null,
      ),
    );
  }
}

class _ClusterInfoCard extends StatelessWidget {
  const _ClusterInfoCard({
    required this.cluster,
    required this.videoName,
    required this.healthScoreFor,
    required this.onClose,
  });

  final DistressCluster cluster;
  final String Function(int?) videoName;
  final int Function(int?) healthScoreFor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isCluster = cluster.items.length > 1;
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isCluster ? '${cluster.items.length} Detections Clustered' : 'Detection RD-${cluster.items.first.id}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              InkWell(onTap: onClose, child: const Icon(LucideIcons.x, size: 14)),
            ],
          ),
          const Divider(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [for (final d in cluster.items) _detectionRow(d)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detectionRow(DistressRecord d) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Video: ${videoName(d.videoId)}', style: const TextStyle(fontSize: 11)),
          Text('Type: ${d.distressType.replaceAll('_', ' ')}', style: const TextStyle(fontSize: 11)),
          Row(
            children: [
              const Text('Severity: ', style: TextStyle(fontSize: 11)),
              Text(
                d.severity.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _severityColor(d.severity)),
              ),
            ],
          ),
          Text('Road Health Score: ${healthScoreFor(d.videoId)}%', style: const TextStyle(fontSize: 11)),
          Text('Confidence: ${(d.confidenceScore * 100).round()}%', style: const TextStyle(fontSize: 11)),
          const Divider(height: 8),
        ],
      ),
    );
  }
}
