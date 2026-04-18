// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppThemes {
  static final lightMode = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.light(
      // Main background
      background: AppColors.lightBackgroundColor,

      // Primary brand
      primary: AppColors.primaryColor,
      onPrimary: Colors.white,

      // Card / Container backgrounds
      primaryContainer: AppColors.lightPrimaryCardColor,
      secondaryContainer: Color(0xFFF5F6F7),
      tertiaryContainer: Color(0xFFEEF0F2),

      // Surface
      surface: AppColors.lightPrimaryCardColor,
      onSurface: AppColors.lightBodyTextColor,

      // Text
      onBackground: AppColors.lightHeadingColor,

      // Borders / Dividers
      outline: AppColors.lightStrokeColor,
      outlineVariant: AppColors.lightDividerColor,

      // Error
      error: AppColors.lightErrorColor,
      onError: Colors.white,
    ),
  );

  static final darkMode = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      // Main background
      background: AppColors.darkBackgroundColor,

      // Primary brand
      primary: AppColors.primaryColor,
      onPrimary: Colors.white,

      // Card / Container backgrounds
      primaryContainer: AppColors.darkPrimaryCardColor,
      secondaryContainer: Color(0xFF242831),
      tertiaryContainer: Color(0xFF2D3139),

      // Surface
      surface: Color(0xFF161B22),
      onSurface: AppColors.darkBodyTextColor,

      // Text
      onBackground: AppColors.darkHeadingColor,

      // Borders / Dividers
      outline: AppColors.darkStrokeColor,
      outlineVariant: AppColors.darkDividerColor,

      // Error
      error: AppColors.darkErrorColor,
      onError: Color(0xFF1F2937),
    ),
  );
}
