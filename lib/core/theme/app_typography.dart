import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Manrope';

  static TextTheme textTheme(Color onSurface) => TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, fontSize: 36, fontWeight: FontWeight.w700, color: onSurface),
        displayMedium: TextStyle(fontFamily: fontFamily, fontSize: 30, fontWeight: FontWeight.w700, color: onSurface),
        headlineLarge: TextStyle(fontFamily: fontFamily, fontSize: 26, fontWeight: FontWeight.w700, color: onSurface),
        headlineMedium: TextStyle(fontFamily: fontFamily, fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
        titleLarge: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
        titleMedium: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
        bodyLarge: TextStyle(fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
        bodyMedium: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
        bodySmall: TextStyle(fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: onSurface),
        labelLarge: TextStyle(fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      );
}
