// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppThemes {
  static final lightMode = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.poppins().fontFamily,
    colorScheme: ColorScheme.light(
      background: Colors.white, // Screen background color
      primary: AppColors.primaryColor,
      onPrimary: AppColors.primaryColor, // Text on primary background
      onBackground: Colors.black, // General text color
      primaryContainer: Colors.white,
      secondaryContainer: Colors.white,
      tertiaryContainer: Color(0xFFf4f4f7),  

    ),
  );

  static final darkMode = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.poppins().fontFamily,
    colorScheme: ColorScheme.dark(
      background: const Color(0xFF0A0A0A),
      primary: Colors.white,
      onPrimary: Colors.white,
      onBackground: Colors.white,
      primaryContainer: Color(0xFF535353),
      secondaryContainer: Color(0xFF161616),
      tertiaryContainer: Color(0xFF161616),
    ),
  );
}
