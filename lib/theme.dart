
import 'package:flutter/material.dart';

class GameTheme {
  static const bg = Color(0xFF0D151B);
  static const panel = Color(0xFF19262D);
  static const panel2 = Color(0xFF22343B);
  static const gold = Color(0xFFE6B95E);
  static const green = Color(0xFF65C18C);
  static const red = Color(0xFFE57373);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      secondary: green,
      surface: panel,
      error: red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: panel,
      indicatorColor: panel2,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
