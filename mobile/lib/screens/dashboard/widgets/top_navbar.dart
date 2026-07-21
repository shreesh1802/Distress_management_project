import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../data/auth_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/components/
/// common/TopNavbar.tsx and TopNavbar.css.
class DashboardTopNavbar extends ConsumerStatefulWidget {
  const DashboardTopNavbar({super.key});

  @override
  ConsumerState<DashboardTopNavbar> createState() => _DashboardTopNavbarState();
}

class _DashboardTopNavbarState extends ConsumerState<DashboardTopNavbar> {
  final _searchCtrl = TextEditingController();
  bool _isDark = false;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _currentDate {
    final now = DateTime.now();
    return '${_months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _handleSearch() {
    final query = _searchCtrl.text.trim();
    if (query.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for: "$query"')),
      );
    }
  }

  void _handleToggleTheme() {
    setState(() => _isDark = !_isDark);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Theme toggle clicked (Mock). Dashboard is optimized for '
          'commercial light mode.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _handleSearch(),
                  style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search roads, videos, locations...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(LucideIcons.search, size: 16, color: AppColors.secondaryText),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 16),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Center(
                        widthFactor: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBg,
                            border: Border.all(color: AppColors.cardBorder),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '⌘ K',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.cardBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9999),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9999),
                      borderSide: BorderSide(color: AppColors.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9999),
                      borderSide: const BorderSide(color: AppColors.accentBlue),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const _NavWidget(
                icon: LucideIcons.mapPin,
                iconColor: AppColors.accentBlue,
                label: 'Mumbai Division',
                bold: true,
              ),
              const SizedBox(width: 12),
              _NavWidget(icon: LucideIcons.calendar, label: _currentDate),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: LucideIcons.bell,
                badge: true,
                tooltip: 'Notifications Center',
                onTap: () {
                  const path = '/notifications';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('$path is not wired up yet.')),
                  );
                },
              ),
              const SizedBox(width: 12),
              _CircleIconButton(
                icon: _isDark ? LucideIcons.sun : LucideIcons.moon,
                tooltip: 'Toggle Dark Mode',
                onTap: _handleToggleTheme,
              ),
              const SizedBox(width: 12),
              _ProfileMenu(ref: ref),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavWidget extends StatelessWidget {
  const _NavWidget({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.secondaryText,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryText,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.cardBg,
        shape: CircleBorder(side: BorderSide(color: AppColors.cardBorder)),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.secondaryText),
                if (badge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      color: Colors.white,
      onSelected: (value) {
        switch (value) {
          case 'profile':
          case 'settings':
            context.go('/settings');
          case 'logout':
            ref.read(authProvider.notifier).logout();
            context.go(AppRoutes.login);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Daksh Agarwal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                'Admin Engineer',
                style: TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          height: 36,
          child: Row(
            children: [
              Icon(LucideIcons.user, size: 14, color: AppColors.secondaryText),
              SizedBox(width: 8),
              Text('My Profile', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          height: 36,
          child: Row(
            children: [
              Icon(LucideIcons.settings, size: 14, color: AppColors.secondaryText),
              SizedBox(width: 8),
              Text('Settings', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          height: 36,
          child: Row(
            children: [
              Icon(LucideIcons.logOut, size: 14, color: AppColors.danger),
              SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentBlueLight,
                border: Border.all(color: const Color(0x334F8EF7)),
              ),
              child: const Text(
                'DA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentBlue,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(
                LucideIcons.chevronDown,
                size: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
