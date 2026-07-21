import 'package:flutter/material.dart';
import 'app_colors.dart';

/// One semantic lookup per screen instead of writing
/// `Theme.of(context).brightness == Brightness.dark ? X : Y` inline
/// everywhere. Every screen being converted to support dark mode reads
/// its colors from `context.appColors.*` instead of hardcoded hex.
class AppSemanticColors {
  final Color surface; // scaffold background
  final Color card; // card/container background
  final Color cardBorder;
  final Color ink; // primary text
  final Color muted; // secondary/caption text
  final Color green;
  final Color orange;
  final Color red;
  final Color divider;
  final Color chipBackground;

  const AppSemanticColors({
    required this.surface,
    required this.card,
    required this.cardBorder,
    required this.ink,
    required this.muted,
    required this.green,
    required this.orange,
    required this.red,
    required this.divider,
    required this.chipBackground,
  });

  static const light = AppSemanticColors(
    surface: AppColors.lightSurface,
    card: Colors.white,
    cardBorder: Color(0xFFEEECE2),
    ink: Color(0xFF232620),
    muted: Color(0xFF8A8D82),
    green: AppColors.lightPrimary,
    orange: AppColors.lightAccent,
    red: AppColors.lightError,
    divider: Color(0xFFE5E2D6),
    chipBackground: Color(0xFFF3F3F3),
  );

  static const dark = AppSemanticColors(
    surface: AppColors.darkSurface,
    card: AppColors.darkSurfaceVariant,
    cardBorder: Color(0xFF3A3D34),
    ink: AppColors.darkOnSurface,
    muted: Color(0xFFA3A69B),
    green: AppColors.darkPrimary,
    orange: AppColors.darkAccent,
    red: AppColors.darkError,
    divider: Color(0xFF3A3D34),
    chipBackground: Color(0xFF1D1F19),
  );
}

extension AppColorsContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).brightness == Brightness.dark ? AppSemanticColors.dark : AppSemanticColors.light;
}
