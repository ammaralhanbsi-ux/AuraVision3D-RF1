import 'package:flutter/material.dart';

class AuraTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF030609),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xCC0B1018),
        primary: Color(0xFF7CFF00),
        secondary: Color(0xFF00E5FF),
        error: Color(0xFFFF365E),
      ),
      fontFamily: 'sans',
      useMaterial3: true,
    );
  }
}
