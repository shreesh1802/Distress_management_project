import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/components/
/// common/Sidebar.tsx and Sidebar.css.
class DashboardSidebar extends StatefulWidget {
  const DashboardSidebar({super.key});

  @override
  State<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _SidebarMenuItem {
  const _SidebarMenuItem(this.path, this.label, this.icon, [this.badge]);
  final String path;
  final String label;
  final IconData icon;
  final int? badge;
}

class _DashboardSidebarState extends State<DashboardSidebar> {
  bool _isCollapsed = false;

  static const _menuItems = [
    _SidebarMenuItem('/overview', 'Overview', LucideIcons.layoutDashboard),
    _SidebarMenuItem(AppRoutes.dashboard, 'Dashboard', LucideIcons.layoutDashboard),
    _SidebarMenuItem(AppRoutes.liveMonitoring, 'Live Detection', LucideIcons.radar),
    _SidebarMenuItem('/upload-video', 'Upload Video', LucideIcons.upload),
    _SidebarMenuItem('/live-processing', 'Live Processing', LucideIcons.activity),
    _SidebarMenuItem('/gis-map', 'GIS Map', LucideIcons.map),
    _SidebarMenuItem('/road-distresses', 'Road Distresses', LucideIcons.shieldAlert),
    _SidebarMenuItem('/maintenance', 'Maintenance', LucideIcons.wrench),
    _SidebarMenuItem('/reports', 'Reports', LucideIcons.fileText),
    _SidebarMenuItem('/analytics', 'Analytics', LucideIcons.barChart3),
    _SidebarMenuItem('/history', 'History', LucideIcons.history),
    _SidebarMenuItem('/notifications', 'Notifications', LucideIcons.bell, 2),
    _SidebarMenuItem('/settings', 'Settings', LucideIcons.settings),
  ];

  void _onNavTap(String path) {
    final currentRoutes = {
      AppRoutes.login,
      AppRoutes.survey,
      AppRoutes.dashboard,
      AppRoutes.overview,
      AppRoutes.liveMonitoring,
    };
    if (currentRoutes.contains(path)) {
      context.go(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$path is not wired up yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: _isCollapsed ? 74 : 270,
      padding: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 12 : 16,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sidebarGradientTop,
            AppColors.sidebarGradientMid,
            AppColors.sidebarGradientBottom,
          ],
        ),
        border: Border(
          right: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Icon(LucideIcons.route, size: 20, color: Color(0xFF7C8573)),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'THAPAR - AKCM',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.sidebarText,
                            letterSpacing: -0.66,
                          ),
                        ),
                        const Text(
                          'AI POWERED VENTURE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C8573),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _ToggleButton(
                  isCollapsed: _isCollapsed,
                  onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in _menuItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _NavLink(
                      item: item,
                      isActive: currentPath == item.path,
                      isCollapsed: _isCollapsed,
                      onTap: () => _onNavTap(item.path),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Text(
                    'DA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Daksh Agarwal',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFECE9DD),
                          ),
                        ),
                        const Text(
                          'Admin Control',
                          style: TextStyle(fontSize: 10, color: Color(0xFFC9C7BA)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: const Text('Logging out of system...'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.logOut, size: 14),
                    color: const Color(0xFFDDD9CB),
                    tooltip: 'Logout session',
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.isCollapsed, required this.onTap});

  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      hoverColor: AppColors.sidebarHover,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.sidebarSelected,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(
          isCollapsed ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
          size: 12,
          color: AppColors.sidebarTextSecondary,
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.item,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
  });

  final _SidebarMenuItem item;
  final bool isActive;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCollapsed ? item.label : '',
      child: Material(
        color: isActive ? AppColors.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(9999),
        child: InkWell(
          onTap: onTap,
          hoverColor: AppColors.sidebarHover,
          borderRadius: BorderRadius.circular(9999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: isActive ? const Color(0xFFF6F4EA) : const Color(0xFFDDD9CB),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        '${item.badge}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFECE9DD),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
