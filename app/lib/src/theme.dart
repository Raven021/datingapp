import "package:flutter/material.dart";

const ink = Color(0xFF241611);
const rose = Color(0xFFC5364A);
const cream = Color(0xFFF6F0E8);
const paper = Color(0xFFFFFCF8);
const line = Color(0xFFE6D9CE);
const moss = Color(0xFF2C6B4A);
const muted = Color(0xFF8A7368);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: rose, primary: rose, surface: cream, onSurface: ink);
  const text = TextStyle(fontFamily: "Vazirmatn", color: ink);
  return ThemeData(
    useMaterial3: true,
    fontFamily: "Vazirmatn",
    colorScheme: scheme,
    scaffoldBackgroundColor: cream,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontFamily: "Vazirmatn", fontWeight: FontWeight.w600, fontSize: 34, color: ink, height: 1.25),
      titleLarge: TextStyle(fontFamily: "Vazirmatn", fontWeight: FontWeight.w600, fontSize: 22, color: ink),
      titleMedium: TextStyle(fontFamily: "Vazirmatn", fontWeight: FontWeight.w600, fontSize: 18, color: ink),
      bodyLarge: TextStyle(fontFamily: "Vazirmatn", fontSize: 16, color: ink, height: 1.5),
      bodyMedium: TextStyle(fontFamily: "Vazirmatn", fontSize: 14, color: ink, height: 1.5),
      labelLarge: TextStyle(fontFamily: "Vazirmatn", fontWeight: FontWeight.w600, fontSize: 16),
    ).apply(fontFamily: "Vazirmatn", bodyColor: ink, displayColor: ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: "Vazirmatn", fontWeight: FontWeight.w600, fontSize: 18, color: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: text.copyWith(color: muted),
      labelStyle: text.copyWith(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: ink, width: 1.4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: rose,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontFamily: "Vazirmatn", fontWeight: FontWeight.w600, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: rose.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: "Vazirmatn", fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, contentTextStyle: TextStyle(fontFamily: "Vazirmatn")),
    dialogTheme: DialogThemeData(
      backgroundColor: paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
