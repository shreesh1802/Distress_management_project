import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../router/app_router.dart';

class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

  static const _menuItems = [
    _DrawerItem(AppRoutes.overview, 'Overview', LucideIcons.layoutDashboard),
    _DrawerItem(AppRoutes.dashboard, 'Dashboard', LucideIcons.layoutGrid),
    _DrawerItem(AppRoutes.liveMonitoring, 'Live Camera Stream', LucideIcons.radar),
    _DrawerItem(AppRoutes.uploadVideo, 'Upload / Record Video', LucideIcons.upload),
    _DrawerItem(AppRoutes.videoReview, 'Video Review & AI Feed', LucideIcons.video),
    _DrawerItem(AppRoutes.liveProcessing, 'Live Processing Status', LucideIcons.activity),
    _DrawerItem(AppRoutes.gisMap, 'GIS Map & Locations', LucideIcons.map),
    _DrawerItem(AppRoutes.roadDistresses, 'Road Distresses', LucideIcons.shieldAlert),
    _DrawerItem(AppRoutes.maintenance, 'Maintenance Tasks', LucideIcons.wrench),
    _DrawerItem(AppRoutes.reports, 'PDF & Excel Reports', LucideIcons.fileText),
    _DrawerItem(AppRoutes.analytics, 'Analytics & Telemetry', LucideIcons.barChart3),
    _DrawerItem(AppRoutes.history, 'Historic Inspections', LucideIcons.history),
    _DrawerItem(AppRoutes.notifications, 'Notifications Center', LucideIcons.bell),
    _DrawerItem('/settings', 'System Settings', LucideIcons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: const Color(0xFF191D17),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(
                      LucideIcons.route,
                      color: Color(0xFFD4E7C5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THAPAR - AKCM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'ROAD MONITORING SYSTEM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF949E8C),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = currentPath == item.path;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 2,
                    ),
                    leading: Icon(
                      item.icon,
                      size: 20,
                      color: isSelected ? const Color(0xFFD4E7C5) : const Color(0xFF949E8C),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFFDCD6C8),
                      ),
                    ),
                    tileColor: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      if (currentPath != item.path) {
                        context.go(item.path);
                      }
                    },
                  );
                },
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    child: const Text(
                      'DA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daksh Agarwal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Field Inspector',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF949E8C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.logOut, size: 16, color: Colors.white70),
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}
