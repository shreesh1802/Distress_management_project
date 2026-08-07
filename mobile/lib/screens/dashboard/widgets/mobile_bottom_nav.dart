import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../router/app_router.dart';

class MobileBottomNavItem {
  const MobileBottomNavItem({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({super.key});

  static const _items = [
    MobileBottomNavItem(
      path: AppRoutes.overview,
      label: 'Overview',
      icon: LucideIcons.layoutDashboard,
    ),
    MobileBottomNavItem(
      path: AppRoutes.gisMap,
      label: 'GIS Map',
      icon: LucideIcons.map,
    ),
    MobileBottomNavItem(
      path: AppRoutes.uploadVideo,
      label: 'Upload',
      icon: LucideIcons.upload,
    ),
    MobileBottomNavItem(
      path: AppRoutes.videoReview,
      label: 'Review',
      icon: LucideIcons.video,
    ),
    MobileBottomNavItem(
      path: AppRoutes.reports,
      label: 'Reports',
      icon: LucideIcons.fileText,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF1E231B).withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final item in _items) ...[
                _BottomNavItemButton(
                  item: item,
                  isSelected: currentPath == item.path,
                  onTap: () {
                    if (currentPath != item.path) {
                      context.go(item.path);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItemButton extends StatelessWidget {
  const _BottomNavItemButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final MobileBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFD4E7C5) : const Color(0xFF949E8C);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
