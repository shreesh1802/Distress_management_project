import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Mirrors the typography presets in index.css (.bold-page-title,
/// .medium-section-title, .light-secondary-text, .large-kpi-number, ...).
class AppTextStyles {
  AppTextStyles._();

  static const _sans = 'Inter';
  static const _mono = 'JetBrains Mono';

  static const boldPageTitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w700,
    fontSize: 36,
    letterSpacing: -0.9,
    height: 1.2,
    color: AppColors.primaryTextLight,
  );

  static const mediumSectionTitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    letterSpacing: -0.2,
    color: AppColors.primaryText,
  );

  static const lightSecondaryText = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
    color: AppColors.secondaryText,
  );

  static const largeKpiNumber = TextStyle(
    fontFamily: _mono,
    fontWeight: FontWeight.w700,
    fontSize: 36,
    letterSpacing: -1.1,
    color: AppColors.primaryText,
  );

  static const smallCaption = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 0.55,
    color: AppColors.secondaryText,
  );

  // --- Login screen specific ---
  static const loginBrandTag = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w600,
    fontSize: 12,
    letterSpacing: 1.5,
    color: AppColors.warning,
  );

  static const loginMainTitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w800,
    fontSize: 42,
    letterSpacing: -0.84,
    height: 1.2,
    color: Colors.white,
  );

  static const loginSubtitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 2,
    color: AppColors.warning,
  );

  static const loginDescription = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.6,
    color: Color(0xFFE2E8F0),
  );

  static const loginFeatureTitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: Colors.white,
  );

  static const loginFeatureDesc = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: Color(0xFFA0AEC0),
  );

  static const loginCardTitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    letterSpacing: -0.48,
    color: Colors.white,
  );

  static const loginCardSubtitle = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: Color(0xFFCBD5E1),
  );

  static const loginLabel = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    letterSpacing: 0.5,
    color: Color(0xFFE2E8F0),
  );

  static const loginInputText = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: Colors.white,
  );

  static const loginButtonLabel = TextStyle(
    fontFamily: _sans,
    fontWeight: FontWeight.w700,
    fontSize: 14,
    letterSpacing: 0.5,
    color: Colors.white,
  );
}
