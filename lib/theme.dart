import 'package:flutter/material.dart';

class AppColors {
  static const rose = Color(0xFFB95763);
  static const roseSoft = Color(0xFFF4E0E3);
  static const lightBg = Color(0xFFF7F7F5);
  static const lightText = Color(0xFF252326);
  static const lightMuted = Color(0xFF777278);
  static const darkBg = Color(0xFF171619);
  static const darkSurface = Color(0xFF211F22);
  static const darkText = Color(0xFFF5EEF0);
  static const darkMuted = Color(0xFFAAA2A8);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.rose,
      brightness: brightness,
      surface: dark ? AppColors.darkSurface : Colors.white,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: dark ? AppColors.darkText : AppColors.lightText,
      displayColor: dark ? AppColors.darkText : AppColors.lightText,
    ),
  );
}
