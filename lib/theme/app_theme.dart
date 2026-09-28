import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFFFBF9);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF332A2D);
  static const muted = Color(0xFF7B7074);
  static const rose = Color(0xFFB95763);
  static const roseSoft = Color(0xFFF8E9EB);
  static const line = Color(0xFFEAD7DA);
  static const blush = Color(0xFFFFF2F0);
}

ThemeData appTheme(bool dark) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.rose,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: dark ? const Color(0xFF201B1D) : AppColors.bg,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: dark ? Colors.white : AppColors.ink,
      displayColor: dark ? Colors.white : AppColors.ink,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF2A2326) : AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF201B1D) : AppColors.bg,
      indicatorColor: AppColors.roseSoft,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2326) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.line),
      ),
    ),
  );
}
