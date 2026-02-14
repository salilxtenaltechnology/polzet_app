// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppThemes {
  static final lightMode = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.poppins().fontFamily,
    colorScheme: const ColorScheme.light(
      // Main background color (screen background)
      background: Color(0xFFF8F9FA),
      
      // Primary brand color (buttons, highlights)
      primary: AppColors.primaryColor,
      onPrimary: Colors.white, // Text on primary colored elements
      
      // Card/Container backgrounds
      primaryContainer: Color(0xFFFFFFFF), // White cards
      secondaryContainer: Color(0xFFF5F6F7), // Slightly gray for poll options
      tertiaryContainer: Color(0xFFEEF0F2), // Even lighter gray
      
      // Surface colors (elevated elements, dialogs)
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF6B7280), // Secondary text (gray)
      
      // Text colors
      onBackground: Color(0xFF1F2937), // Main text (dark gray, not pure black)
      
      // Border and divider colors
      outline: Color(0xFFE5E7EB),
      outlineVariant: Color(0xFFF3F4F6),
      
      // Error colors
      error: Color(0xFFEF4444),
      onError: Colors.white,
    ),
  );

  static final darkMode = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.poppins().fontFamily,
    colorScheme: const ColorScheme.dark(
      // Main background color (screen background)
      background: Color(0xFF0D1117), // GitHub dark style
      
      // Primary brand color
      primary: AppColors.primaryColor,
      onPrimary: Colors.white,
      
      // Card/Container backgrounds
      primaryContainer: Color(0xFF1C1F26), // Dark card background
      secondaryContainer: Color(0xFF242831), // Poll options background
      tertiaryContainer: Color(0xFF2D3139), // Alternative container
      
      // Surface colors (elevated elements, dialogs)
      surface: Color(0xFF161B22),
      onSurface: Color(0xFF9CA3AF), // Secondary text (light gray)
      
      // Text colors
      onBackground: Color(0xFFF3F4F6), // Main text (light)
      
      // Border and divider colors
      outline: Color(0xFF30363D),
      outlineVariant: Color(0xFF21262D),
      
      // Error colors
      error: Color(0xFFF87171),
      onError: Color(0xFF1F2937),
    ),
  );
}