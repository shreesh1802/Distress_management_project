import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_colors.dart';
import '../notification_item.dart';

const _kDateGroups = ['Today', 'Yesterday', 'Last 7 Days', 'Earlier'];

/// Direct port of Notifications.tsx's "Incident Alert Feed": notifications
/// grouped into collapsible Today/Yesterday/Last 7 Days/Earlier sections,
/// each a list of cards with a priority-colored left border, category
/// icon, meta tags, and a per-card action bar (View Details/Assign/Mark
/// Read/Delete).
class NotificationFeed extends StatelessWidget {
  const NotificationFeed({
    super.key,
    required this.notifications,
    required this.collapsedGroups,
    required this.onToggleGroup,
    required this.onView,
    required this.onAssign,
    required this.onToggleRead,
    required this.onDelete,
  });

  final List<NotificationItem> notifications;
  final Set<String> collapsedGroups;
  final ValueChanged<String> onToggleGroup;
  final ValueChanged<NotificationItem> onView;
  final ValueChanged<NotificationItem> onAssign;
  final ValueChanged<NotificationItem> onToggleRead;
  final ValueChanged<NotificationItem> onDelete;

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
              const Icon(LucideIcons.bell, size: 18, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              const Expanded(child: Text('Incident Alert Feed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.bell, size: 40, color: AppColors.secondaryText.withValues(alpha: 0.3)),
                    const SizedBox(height: 10),
                    const Text('No operational incidents match your filters.', style: TextStyle(color: AppColors.secondaryText)),
                  ],
                ),
              ),
            )
          else
            for (final group in _kDateGroups) _section(group),
        ],
      ),
    );
  }

  Widget _section(String group) {
    final items = notifications.where((n) => n.dateGroup == group).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final isCollapsed = collapsedGroups.contains(group);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onToggleGroup(group),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(isCollapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp, size: 18, color: AppColors.secondaryText),
                  const SizedBox(width: 8),
                  Text(group, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${items.length} events', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                  const SizedBox(width: 8),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
          ),
          if (!isCollapsed) for (final item in items) _card(item),
        ],
      ),
    );
  }

  Widget _card(NotificationItem item) {
    final color = priorityColor(item.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: item.unread ? AppColors.accentBlueLight : AppColors.cardBg,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Stack(
            children: [
              Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 4, color: color)),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(categoryIcon(item.category), size: 18, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(item.id, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'monospace')),
                                    if (item.unread) ...[
                                      const SizedBox(width: 6),
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(item.message, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (item.roadId != null) _metaTag('🛣️ ${item.roadId}'),
                                    if (item.location != null) _metaTag('📍 ${item.location}'),
                                    if (item.pipeline != null) _metaTag('🤖 ${item.pipeline}'),
                                    _metaTag('⏱️ ${item.time}'),
                                    if (item.assignedTo != null) _metaTag('👷 ${item.assignedTo}', crew: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  border: Border.all(color: color.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(item.priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                              ),
                              if (item.thumbnailUrl != null) ...[
                                const SizedBox(height: 8),
                                _ThumbnailMock(),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(color: AppColors.primaryBg, border: Border(top: BorderSide(color: AppColors.cardBorder))),
                      child: Row(
                        children: [
                          _actionBtn(LucideIcons.eye, 'View Details', () => onView(item)),
                          _actionBtn(LucideIcons.userPlus, 'Assign', () => onAssign(item)),
                          _actionBtn(LucideIcons.check, item.unread ? 'Mark Read' : 'Mark Unread', () => onToggleRead(item)),
                          _actionBtn(LucideIcons.trash2, 'Delete', () => onDelete(item), color: AppColors.danger),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaTag(String text, {bool crew = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: crew ? AppColors.successLight : AppColors.primaryBg,
        border: Border.all(color: crew ? const Color(0x334CAF50) : AppColors.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: crew ? AppColors.success : AppColors.secondaryText, fontWeight: crew ? FontWeight.w600 : FontWeight.normal)),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color ?? AppColors.primaryText),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AppColors.primaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A5568), Color(0xFF1A202C)]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 0, right: 0, top: 19, child: Container(height: 1, color: const Color(0x59EF4444))),
          const Icon(LucideIcons.shieldAlert, size: 12, color: Color(0xFFEF4444)),
        ],
      ),
    );
  }
}
