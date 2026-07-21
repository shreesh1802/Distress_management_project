import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_navbar.dart';

/// Direct port of Road-Distress-Management-System/frontend/src/layouts/
/// DashboardLayout.tsx and DashboardLayout.css: sidebar + top navbar shell
/// wrapping the routed page content (React's `<Outlet />`).
class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashboardSidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DashboardTopNavbar(),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.primaryBg,
                    child: child ?? const _DashboardContentPlaceholder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardContentPlaceholder extends StatelessWidget {
  const _DashboardContentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Dashboard content — next phase of the Flutter port',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
