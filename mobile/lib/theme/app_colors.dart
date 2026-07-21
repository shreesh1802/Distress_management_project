import 'package:flutter/material.dart';

/// Mirrors the CSS custom properties in
/// Road-Distress-Management-System/frontend/src/index.css (`:root`) and
/// LoginPage.css, so every screen ported from the React app draws from the
/// same values instead of re-guessing colors per-screen.
class AppColors {
  AppColors._();

  static const primaryBg = Color(0xFFF4F6F8);
  static const cardBg = Color(0xE0FFFFFF); // rgba(255,255,255,0.88)
  static const cardBorder = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)

  // Sidebar gradient stops: rgba(11,79,156,.78) -> rgba(21,101,192,.72) -> rgba(30,136,229,.65)
  static const sidebarGradientTop = Color(0xC70B4F9C);
  static const sidebarGradientMid = Color(0xB81565C0);
  static const sidebarGradientBottom = Color(0xA61E88E5);
  static const sidebarSelected = Color(0x40FFFFFF); // rgba(255,255,255,0.25)
  static const sidebarHover = Color(0x26FFFFFF); // rgba(255,255,255,0.15)
  static const sidebarText = Color(0xFFFFFFFF);
  static const sidebarTextSecondary = Color(0xFFE5E7EB);

  static const primaryText = Color(0xFF111827);
  static const secondaryText = Color(0xFF6B7280);
  static const headingNavy = Color(0xFF0F204A);

  static const accentBlue = Color(0xFF1565C0);
  static const accentBlueHover = Color(0xFF0B4F9C);
  static const accentBlueLight = Color(0x141565C0); // 8% opacity

  static const success = Color(0xFF10B981);
  static const successLight = Color(0x1410B981);

  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0x14F59E0B);

  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0x14EF4444);

  static const info = Color(0xFF1565C0);

  static const primaryTextLight = Color(0xFFFFFFFF);
  static const secondaryTextLight = Color(0xBFFFFFFF); // rgba(255,255,255,0.75)

  // Login page specific (dark hero overlay on highway_background.png)
  static const loginOverlayStart = Color(0xEB082850); // rgba(8,40,80,0.92)
  static const loginOverlayEnd = Color(0xD90F417D); // rgba(15,65,125,0.85)
  static const glassCardFill = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const glassCardBorder = Color(0x2EFFFFFF); // rgba(255,255,255,0.18)

  // DashboardLayout.css hero overlay on highway_background.png (lighter navy
  // than the login/survey overlay, sits behind the sidebar/navbar/content).
  static const dashboardOverlayStart = Color(0xC70F204A); // rgba(15,32,74,0.78)
  static const dashboardOverlayEnd = Color(0xB816275A); // rgba(22,39,90,0.72)
}
