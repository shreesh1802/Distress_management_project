import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/road_distress_api.dart';
import '../distress_colors.dart';

const _kFallbackImage =
    'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300';

/// Direct port of RoadDistresses.tsx's side inspection drawer: full detail
/// readout, maintenance guideline, an activity timeline, and Download
/// PDF / Locate GIS actions.
class InspectionDrawer extends StatelessWidget {
  const InspectionDrawer({
    super.key,
    required this.record,
    required this.onClose,
    required this.onDownloadPdf,
    required this.onLocateGis,
  });

  final DistressRecord record;
  final VoidCallback onClose;
  final VoidCallback onDownloadPdf;
  final VoidCallback onLocateGis;

  @override
  Widget build(BuildContext context) {
    final d = record;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 420,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFA0F172A),
          border: Border(left: BorderSide(color: Color(0x1AFFFFFF))),
          boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(-6, 0))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'INSPECTION DETAILS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                        ),
                        Text(
                          'RD-${d.id}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    child: const Icon(LucideIcons.x, size: 20, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        d.resolvedImageUrl ?? _kFallbackImage,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => Image.network(_kFallbackImage),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _row('Tracking ID:', d.trackingId?.toString() ?? 'TRK-MOCK-${d.id}'),
                    _row('Distress Type:', formatDistressType(d.distressType)),
                    _rowWidget(
                      'Severity:',
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: severityColor(d.severity).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          d.severity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: severityColor(d.severity),
                          ),
                        ),
                      ),
                    ),
                    _row('AI Confidence:', '${(d.confidenceScore * 100).round()}%'),
                    _row('Priority Score:', '${priorityScore(d.severity)}', valueColor: const Color(0xFFF59E0B)),
                    _row('Health Impact:', healthImpactScore(d.severity), valueColor: const Color(0xFFEF4444)),
                    _row('Video source:', d.videoId != null ? 'video_${d.videoId}.mp4' : 'manual_upload'),
                    _row(
                      'Frame & Time:',
                      'F: ${d.frameNumber ?? 0} | T: ${(d.videoTimestamp ?? 0).toStringAsFixed(2)}s',
                    ),
                    _row('Bounding Box:', 'W: ${d.boxWidth ?? 120}px | H: ${d.boxHeight ?? 80}px'),
                    _row('Damage Area:', '${d.affectedArea ?? 0.125} sq.m'),
                    _row(
                      'GPS Coordinates:',
                      '${d.latitude.toStringAsFixed(5)}° N, ${d.longitude.toStringAsFixed(5)}° E',
                    ),
                    _row('Est. Repair Cost:', estimatedCost(d.severity), valueColor: const Color(0xFF10B981), isLast: true),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        border: Border.all(color: const Color(0x1AFFFFFF)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MAINTENANCE GUIDELINE',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            getRecommendation(d.distressType),
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ACTIVITY TIMELINE LOG',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TimelineEntry(
                            dotColor: const Color(0xFF10B981),
                            title: 'Initial detection created',
                            subtitle: d.detectedAt.toLocal().toString(),
                          ),
                          _TimelineEntry(
                            dotColor: d.status == 'detected' ? const Color(0xFF94A3B8) : const Color(0xFF3B82F6),
                            title: 'Review status: ${d.status.replaceAll('_', ' ')}',
                            subtitle: 'Synchronized metadata mapping log',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0x1AFFFFFF)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDownloadPdf,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                      ),
                      child: const Text('Download PDF', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onLocateGis,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C7354),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Locate GIS', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool isLast = false}) {
    return _rowWidget(
      label,
      Text(
        value,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? Colors.white),
      ),
      isLast: isLast,
    );
  }

  Widget _rowWidget(String label, Widget value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          Flexible(child: value),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.dotColor, required this.title, required this.subtitle});

  final Color dotColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
