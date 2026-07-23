import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/road_distress_api.dart';
import '../distress_colors.dart';

const _kFallbackImage =
    'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=800';

/// Direct-ish port of RoadDistresses.tsx's lightbox modal: full-size image
/// view + a metadata side panel. Pan/zoom is implemented with Flutter's
/// built-in `InteractiveViewer` (pinch/drag/double-tap zoom) instead of
/// manually re-implementing the React source's mouse-drag + zoom-button
/// transform math -- same real capability, idiomatic Flutter widget.
class ImageLightbox extends StatefulWidget {
  const ImageLightbox({super.key, required this.record});

  final DistressRecord record;

  @override
  State<ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<ImageLightbox> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _controller.value.clone();
    _controller.value = current..scaleByDouble(factor, factor, factor, 1);
  }

  void _reset() => _controller.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    final d = widget.record;
    final imageUrl = d.resolvedImageUrl ?? _kFallbackImage;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: const Color(0xF20A0F1D),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 0.5,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => Image.network(_kFallbackImage),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  child: _Chip(text: 'RD-${d.id}'),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Row(
                    children: [
                      _IconBtn(icon: LucideIcons.zoomIn, onTap: () => _zoom(1.25)),
                      const SizedBox(width: 8),
                      _IconBtn(icon: LucideIcons.zoomOut, onTap: () => _zoom(0.8)),
                      const SizedBox(width: 8),
                      _IconBtn(icon: LucideIcons.rotateCcw, onTap: _reset),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon: LucideIcons.x,
                        onTap: () => Navigator.of(context).pop(),
                        background: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFA0F172A),
              border: Border(left: BorderSide(color: Color(0x1AFFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'DEFECT METADATA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF60A5FA),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                _MetaField('Type', formatDistressType(d.distressType)),
                _MetaField(
                  'Severity',
                  d.severity.toUpperCase(),
                  valueColor: d.severity == 'critical' ? const Color(0xFFEF4444) : Colors.white,
                ),
                _MetaField('Confidence', '${(d.confidenceScore * 100).round()}%'),
                _MetaField(
                  'Coordinates',
                  '${d.latitude.toStringAsFixed(5)}° N, ${d.longitude.toStringAsFixed(5)}° E',
                ),
                _MetaField('Impact Deduction', healthImpactScore(d.severity), valueColor: const Color(0xFFEF4444)),
                _MetaField('Estimate Repair', estimatedCost(d.severity), valueColor: const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.background});
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: background ?? Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _MetaField extends StatelessWidget {
  const _MetaField(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? Colors.white)),
        ],
      ),
    );
  }
}
