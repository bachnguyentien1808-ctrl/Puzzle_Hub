import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const defaultSeed = Color(0xFF4F46E5);

  static ThemeData get light => build(defaultSeed, Brightness.light);
  static ThemeData get dark => build(defaultSeed, Brightness.dark);

  static ThemeData build(Color seed, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // Tieu de trang tren nen anh: chu trang dam co bong, doc ro moi buoi.
        // Icon thanh tren nam trong nut trang (xem iconButtonTheme): xanh dam.
        foregroundColor: Color(0xFF1B2F57),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 4)],
        ),
        iconTheme: IconThemeData(color: Color(0xFF1B2F57)),
        actionsIconTheme: IconThemeData(color: Color(0xFF1B2F57)),
      ),
      cardTheme: const CardThemeData(elevation: 0),
      // Nut bieu tuong: vien thuoc trang, icon xanh dam, noi tren moi nen.
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? const Color(0x66FFFFFF)
                : const Color(0xE6FFFFFF),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? const Color(0x661B2F57)
                : const Color(0xFF1B2F57),
          ),
        ),
      ),
    );
  }
}
