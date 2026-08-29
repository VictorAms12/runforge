import 'package:flutter/material.dart';

class AppTheme {
  static const neonLime = Color(0xFFCCFF00);
  static const electricCoral = Color(0xFFFF5A36);
  static const graphite = Color(0xFF121212);
  static const surface = Color(0xFF1B1B1D);
  static const surfaceHigh = Color(0xFF252528);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: neonLime,
      brightness: Brightness.dark,
      surface: graphite,
    ).copyWith(
      primary: neonLime,
      secondary: electricCoral,
      surface: graphite,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: graphite,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF161618),
        indicatorColor: neonLime.withValues(alpha: .14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6B8E00),
      brightness: Brightness.light,
    );
    return ThemeData(useMaterial3: true, colorScheme: scheme);
  }
}
