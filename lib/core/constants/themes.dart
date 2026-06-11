import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppThemes {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.white,
      background: AppColors.grey100,
      error: AppColors.error,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.grey900,
      onBackground: AppColors.grey900,
      onError: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.grey100,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.grey900,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.grey900),
      titleTextStyle: TextStyle(
        color: AppColors.grey900,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AppColors.grey900),
        displayMedium: TextStyle(color: AppColors.grey900),
        displaySmall: TextStyle(color: AppColors.grey900),
        headlineLarge: TextStyle(color: AppColors.grey900),
        headlineMedium: TextStyle(color: AppColors.grey900),
        headlineSmall: TextStyle(color: AppColors.grey900),
        titleLarge: TextStyle(color: AppColors.grey900, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.grey800),
        titleSmall: TextStyle(color: AppColors.grey700),
        bodyLarge: TextStyle(color: AppColors.grey800),
        bodyMedium: TextStyle(color: AppColors.grey700),
        bodySmall: TextStyle(color: AppColors.grey600),
        labelLarge: TextStyle(color: AppColors.grey800),
        labelMedium: TextStyle(color: AppColors.grey700),
        labelSmall: TextStyle(color: AppColors.grey600),
      ),
    ),
    buttonTheme: ButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      buttonColor: AppColors.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      labelStyle: const TextStyle(color: AppColors.grey600),
      hintStyle: const TextStyle(color: AppColors.grey400),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.grey200,
      thickness: 1,
      space: 1,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.grey500,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: AppColors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: AppColors.grey800,
      contentTextStyle: const TextStyle(color: AppColors.white),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      surface: AppColors.grey800,
      background: AppColors.grey900,
      error: AppColors.error,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.white,
      onBackground: AppColors.white,
      onError: AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.grey900,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.grey800,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.white),
      titleTextStyle: TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: AppColors.white),
        displayMedium: TextStyle(color: AppColors.white),
        displaySmall: TextStyle(color: AppColors.white),
        headlineLarge: TextStyle(color: AppColors.white),
        headlineMedium: TextStyle(color: AppColors.white),
        headlineSmall: TextStyle(color: AppColors.white),
        titleLarge: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.grey200),
        titleSmall: TextStyle(color: AppColors.grey300),
        bodyLarge: TextStyle(color: AppColors.grey200),
        bodyMedium: TextStyle(color: AppColors.grey300),
        bodySmall: TextStyle(color: AppColors.grey400),
        labelLarge: TextStyle(color: AppColors.grey200),
        labelMedium: TextStyle(color: AppColors.grey300),
        labelSmall: TextStyle(color: AppColors.grey400),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.grey800,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      labelStyle: const TextStyle(color: AppColors.grey300),
      hintStyle: const TextStyle(color: AppColors.grey500),
    ),
    cardTheme: CardThemeData(
      color: AppColors.grey800,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
    ),
  );
}