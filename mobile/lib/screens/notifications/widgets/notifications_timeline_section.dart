import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';

class _TimelineStep {
  const _TimelineStep(this.title, this.desc, this.time, this.icon, this.color);
  final String title;
  final String desc;
  final String time;
  final IconData icon;
  final Color color;
}

const _kSteps = [
  _TimelineStep(
    'Pothole Distress Flagged',
    'AI engine detected high-severity distress index #101 on NH-48.',
    '10m ago',
    LucideIcons.shieldAlert,
    Color(0xFFEF4444),
  ),
  _TimelineStep(
    'Inference Run Finished',
    'surveillance_cam_mumbai.mp4 parsed; catalogued coordinates into GIS dashboard.',
    '2h ago',
    LucideIcons.layers,
    Color(0xFF3B82F6),
  ),
  _TimelineStep(
    'PDF Summary Generated',
    'System automatically compiled quarterly estimates report file for review.',
    'Yesterday',
    LucideIcons.fileText,
    Color(0xFF8B5CF6),
  ),
  _TimelineStep(
    'Camera CAM-04 Recovery Scheduled',
    'Hardware monitoring pinged technician; dispatch in sector 4 requested.',
    'Yesterday',
    LucideIcons.camera,
    Color(0xFFF97316),
  ),
  _TimelineStep(
    'Patching Repair Completed',
    'Crew Alpha closed maintenance order #4582 on Eastern Express Highway.',
    '5 days ago',
    LucideIcons.checkCircle2,
    Color(0xFF10B981),
  ),
];

/// Direct port of Notifications.tsx's "Incident Mitigation Timeline"
/// section: 5 hardcoded demo steps (this whole screen is a mock/demo
/// screen in the source -- see notification_item.dart's doc comment).
class NotificationsTimelineSection extends StatelessWidget {
  const NotificationsTimelineSection({super.key});

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
              const Icon(LucideIcons.activity, size: 18, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              const Expanded(child: Text('Incident Mitigation Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
              const Text('Active operations sequence', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            ],
          ),
          const SizedBox(height: 16),
          for (final step in _kSteps) _node(step),
        ],
      ),
    );
  }

  Widget _node(_TimelineStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: step.color, shape: BoxShape.circle),
            child: Icon(step.icon, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(step.desc, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(step.time, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
