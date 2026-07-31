import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import '../notification_item.dart';

/// Direct port of Notifications.tsx's "Detailed Notification Drawer /
/// Modal Overlay": a highlight message box, a mock camera-frame bounding-
/// box simulation (only for notifications with a `thumbnailUrl`), a
/// metadata grid, and footer actions (Dismiss/Mark Unread, Dispatch Crew,
/// Purge Record, Close).
class NotificationDetailModal extends StatelessWidget {
  const NotificationDetailModal({
    super.key,
    required this.notification,
    required this.onClose,
    required this.onToggleRead,
    required this.onAssign,
    required this.onDelete,
  });

  final NotificationItem notification;
  final VoidCallback onClose;
  final VoidCallback onToggleRead;
  final VoidCallback onAssign;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(notification.priority);
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: const Color(0x99000000),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                          child: Icon(categoryIcon(notification.category), size: 18, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(notification.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                              Text(
                                '${notification.id} • Category: ${notification.category}',
                                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        IconButton(onPressed: onClose, icon: const Icon(LucideIcons.x, size: 18)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBg,
                              border: Border(left: BorderSide(color: color, width: 4)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(notification.message, style: const TextStyle(fontSize: 14)),
                          ),
                          if (notification.thumbnailUrl != null) ...[
                            const SizedBox(height: 16),
                            _FrameSimulation(),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _metaBox('Priority Class', notification.priority, valueColor: color),
                              _metaBox('District / Jurisdiction', notification.district ?? 'Not Stated'),
                              _metaBox('Road Corridor ID', notification.roadId ?? 'N/A'),
                              _metaBox('Precision GPS Coordinates', notification.location ?? 'N/A'),
                              _metaBox('Inference Pipeline Source', notification.pipeline ?? 'N/A'),
                              _metaBox('Alert Trigger Timestamp', notification.time),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: onToggleRead,
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryText, side: BorderSide(color: AppColors.cardBorder)),
                          child: Text(notification.unread ? 'Dismiss & Mark Read' : 'Mark Unread', style: const TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          onPressed: onAssign,
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryText, side: BorderSide(color: AppColors.cardBorder)),
                          child: const Text('👷 Dispatch Crew', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(LucideIcons.trash2, size: 13, color: AppColors.danger),
                          label: const Text('Purge Record', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                        ),
                        ElevatedButton(
                          onPressed: onClose,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryText, foregroundColor: Colors.white),
                          child: const Text('Close', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaBox(String label, String value, {Color? valueColor}) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _FrameSimulation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2D3748), Color(0xFF1A202C)]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('CAM-04 FEED', style: TextStyle(fontSize: 10, color: Color(0xB3FFFFFF), fontFamily: 'monospace', letterSpacing: 0.6)),
                Text('1080P @ 30FPS', style: TextStyle(fontSize: 10, color: Color(0xB3FFFFFF), fontFamily: 'monospace', letterSpacing: 0.6)),
              ],
            ),
          ),
          Positioned(
            left: 90,
            top: 80,
            child: Container(width: 140, height: 70, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEF4444), width: 2))),
          ),
          const Positioned(
            left: 90,
            top: 62,
            child: ColoredBox(
              color: Color(0xFFEF4444),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text('POTHOLE 92.4%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'monospace')),
              ),
            ),
          ),
          Positioned(
            left: 145,
            top: 105,
            child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          ),
        ],
      ),
    );
  }
}
