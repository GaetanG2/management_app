import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF2F3E9E); // indigo-ish
  static const Color primaryContainer = Color(0xFFDBE3FF);
  static const Color accent = Color(0xFF00A896);
  static const double cardRadius = 12.0;
  static const double defaultPadding = 20.0;

  static ThemeData get themeData {
    final colorScheme = ColorScheme.fromSeed(seedColor: primary);

    final base = ThemeData.from(colorScheme: colorScheme, useMaterial3: true);

    return base.copyWith(
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.grey.shade50,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      cardColor: Colors.white,
      // Make elevated buttons light with black labels so text is always readable
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: primary.withAlpha(178)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      // Global text theme: ensure black text everywhere by default
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
        bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: Colors.black),
        bodyMedium: TextStyle(fontSize: 14, height: 1.35, color: Colors.black),
        bodySmall: TextStyle(fontSize: 13, color: Colors.black87),
      ).apply(bodyColor: Colors.black, displayColor: Colors.black),
      dividerTheme: const DividerThemeData(space: 0, thickness: 1),
      iconTheme: const IconThemeData(color: Colors.black54),
    );
  }
}
