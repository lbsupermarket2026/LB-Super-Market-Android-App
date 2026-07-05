import 'package:flutter/material.dart';

class AppRadii {
  AppRadii._();

  static final BorderRadius card = BorderRadius.circular(16);
  static final BorderRadius button = BorderRadius.circular(12);
  static final BorderRadius chip = BorderRadius.circular(20);
  static final BorderRadius input = BorderRadius.circular(10);
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
