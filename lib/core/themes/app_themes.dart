// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_text_colors.dart';

class AppThemes {
  static final lightMode = ThemeData(
    extensions: const [AppTextColors.light],
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.light(
      // Main background
      background: AppColors.lightBackgroundColor,

      // Primary brand
      primary: AppColors.primaryColor,
      onPrimary: AppColors.primaryColor,

      // Card / Container backgrounds
      primaryContainer: AppColors.lightPrimaryCardColor,
      secondaryContainer: AppColors.lightSecondaryCardColor,
      tertiaryContainer: Colors.white, 

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
    extensions: [AppTextColors.dark],
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      // Main background
      background: Color(0xFF0C1014),

      // Primary brand
      primary: AppColors.primaryColor,
      onPrimary: Color(0xFFF4F4F5),

      // Card / Container backgrounds
      primaryContainer: AppColors.darkPrimaryCardColor,
      secondaryContainer: AppColors.darkSecondaryCardColor,
      tertiaryContainer: Color(0xFF212328),

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
