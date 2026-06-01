import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryColor = Color(0xFF9B3046);

  /*--- LIGHT MODE ---*/
  static const Color lightBackgroundColor = Color(0xFFFDFDFD);     // Main screen background
  static const Color lightPrimaryCardColor = Color(0xFFFFFFFF);   // Post card
  static const Color lightSecondaryCardColor = Color(0xFFFFFFFF);
  static const Color lightHeadingColor = Color(0xFF111111);
  static const Color lightBodyTextColor = Color(0xFF595959);
  static const Color lightSubTextColor = Color(0xFF8E8E8E);
  static const Color lightDividerColor = Color(0xFFDCDCDC);
  static const Color lightStrokeColor = Color(0xFFEFEFEF);
  static const Color lightErrorColor = Color(0xFFDC2626);

  /*--- DARK MODE ---*/
  static const Color darkBackgroundColor = Color(0xFF05070E);
  static const Color darkPrimaryCardColor = Color(0xFF12141D);
  static const Color darkSecondaryCardColor = Color(0xFF2D2D2D);

  static const Color darkHeadingColor = Color(0xFFF4F4F5);
  static const Color darkBodyTextColor = Color(0xFFBFBFBF);
  static const Color darkSubTextColor = Color(0xFFF2F2F2);
  static const Color darkDividerColor = Color(0x40909090);
  static const Color darkStrokeColor = Color(
    0x40636363,
  ); // Outline border color - textfield, cards, buttons, etc.
  static const Color darkErrorColor = Color(0xFFC94B4B);
}
