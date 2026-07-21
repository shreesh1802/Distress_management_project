import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.primaryBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentBlue,
        primary: AppColors.accentBlue,
        secondary: AppColors.warning,
        error: AppColors.danger,
        surface: Colors.white,
      ),
      textTheme: const TextTheme().apply(
        fontFamily: 'Inter',
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
    );
  }
}
