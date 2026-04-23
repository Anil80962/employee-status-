import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1A3A5C);
  static const primary2 = Color(0xFF2C5364);
  static const green = Color(0xFF27AE60);
  static const red = Color(0xFFE74C3C);
  static const purple = Color(0xFF8E44AD);
  static const orange = Color(0xFFE67E22);
  static const blue = Color(0xFF2980B9);
  static const bg = Color(0xFFF4F6F9);
  static const text = Color(0xFF1A1A2E);
  static const sub = Color(0xFF888888);

  static Color forStatus(String s) {
    switch (s) {
      case 'On Site':
        return red;
      case 'In Office':
        return green;
      case 'Work From Home':
        return blue;
      case 'On Leave':
        return purple;
      case 'Holiday':
        return purple;
      case 'Weekend':
        return const Color(0xFF7F8C8D);
      default:
        return sub;
    }
  }
}

ThemeData buildTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.primary2,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
    ),
  );
}
