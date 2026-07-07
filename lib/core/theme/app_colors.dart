import 'package:flutter/material.dart';

/// Original palette — fresh-grocery greens + warm accent for offers/badges.
/// Not copied from any reference site; semantic tokens only, never raw
/// hex codes scattered across widgets.
class AppColors {
  AppColors._();

  // Brand seed
  static const Color seed = Color(0xFF2E7D32); // deep fresh green

  // Light scheme semantic tokens
  static const Color lightPrimary = Color(0xFF2E7D32);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFDFDF7);
  static const Color lightOnSurface = Color(0xFF1B1C18);
  static const Color lightSurfaceVariant = Color(0xFFF0F1E9);
  static const Color lightSuccess = Color(0xFF2E7D32);
  static const Color lightWarning = Color(0xFFF9A825);
  static const Color lightError = Color(0xFFD32F2F);
  static const Color lightAccent = Color(0xFFEF6C00); // offers/badges

  // Dark scheme semantic tokens
  static const Color darkPrimary = Color(0xFF81C784);
  static const Color darkOnPrimary = Color(0xFF00390D);
  static const Color darkSurface = Color(0xFF121410);
  static const Color darkOnSurface = Color(0xFFE2E3DC);
  static const Color darkSurfaceVariant = Color(0xFF262922);
  static const Color darkSuccess = Color(0xFF81C784);
  static const Color darkWarning = Color(0xFFFFCC80);
  static const Color darkError = Color(0xFFEF9A9A);
  static const Color darkAccent = Color(0xFFFFAB74);

  // Brand nav bar — matches the website's dark header/footer bands.
  // Used for the app bar regardless of light/dark theme mode, so the
  // brand identity stays consistent the way it does across the site.
  static const Color navBar = Color(0xFF181818);
  static const Color onNavBar = Color(0xFFFFFFFF);
}
