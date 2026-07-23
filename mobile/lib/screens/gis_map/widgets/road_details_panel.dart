import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/gis_api.dart';
import '../../../theme/app_colors.dart';
import '../severity_colors.dart';

/// Direct port of RoadDetailsPanel.tsx: shows the selected marker's detail
/// card, or an empty/loading state when nothing is selected yet.
class RoadDetailsPanel extends StatelessWidget {
  const RoadDetailsPanel({
    super.key,
    required this.selectedDistress,
    required this.isLoading,
  });

  final RoadDistress? selectedDistress;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _PanelShell(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final d = selectedDistress;
    if (d == null) {
      return const _PanelShell(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.compass, size: 32, color: AppColors.secondaryText),
              SizedBox(height: 10),
              Text(
                'Selected Road Distress',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Select a distress marker on the map to view details',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final color = severityColor(d.severity);
    final recommendation = d.distressType == 'pothole'
        ? 'Pothole asphalt sealing & compaction'
        : 'Crack expansion joint injection filling';

    return _PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.milestone, size: 18, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Selected Distress Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  d.severity.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=150',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => const Icon(
                    LucideIcons.image,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MetaRow('Road ID', d.roadId),
                    _MetaRow(
                      'GPS Coordinates',
                      '${d.latitude.toStringAsFixed(4)}° N, ${d.longitude.toStringAsFixed(4)}° E',
                    ),
                    _MetaRow('Confidence', '${d.confidence}%', valueColor: AppColors.accentBlue),
                    _MetaRow('Detection Time', d.detectionDate),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Recommendation',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                    ),
                    Text(
                      '${formatDistressType(d.distressType)} Repair',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: AppColors.accentBlue, width: 2)),
                  ),
                  child: Text(
                    recommendation,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Est. Repair Cost',
                      style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                    ),
                    Text(
                      d.estimatedRepairCost,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report generated successfully.')),
                    );
                  },
                  icon: const Icon(LucideIcons.fileText, size: 13),
                  label: const Text('Generate Report', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryText,
                    side: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${d.latitude},${d.longitude}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(LucideIcons.externalLink, size: 13),
                  label: const Text('Open in Google Maps', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryText,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
