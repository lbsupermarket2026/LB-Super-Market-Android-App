import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radii_shadows.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightOnPrimary,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnSurface,
      error: AppColors.lightError,
      tertiary: AppColors.lightAccent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightSurface,
      textTheme: AppTypography.textTheme(AppColors.lightOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navBar,
        foregroundColor: AppColors.onNavBar,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.onNavBar),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.onNavBar,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.lightOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadii.input, borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkOnPrimary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkOnSurface,
      error: AppColors.darkError,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkSurface,
      textTheme: AppTypography.textTheme(AppColors.darkOnSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navBar,
        foregroundColor: AppColors.onNavBar,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.onNavBar),
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.onNavBar,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.button),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadii.input, borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
