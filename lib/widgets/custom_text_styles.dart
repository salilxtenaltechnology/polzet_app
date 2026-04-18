// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextStyles {
  CustomTextStyles._();

  static TextStyle appTitleText(BuildContext context) => GoogleFonts.yesevaOne(
    fontSize: 22.sp,
    color: Theme.of(context).colorScheme.onBackground,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.0,
  );

  // Display Headings
  static TextStyle appBarTitleText(BuildContext context) => GoogleFonts.inter(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 22,
    fontWeight: FontWeight.w500,
  );

  static TextStyle msgAuthTitleText(BuildContext context) =>
      GoogleFonts.inter(fontSize: 11.sp, color: const Color(0XFF999999));

  static TextStyle lblPrimaryHintText(BuildContext context) =>
      GoogleFonts.inter(
        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.25),
        fontSize: 12.sp,
      );

  static TextStyle lblSecondryHintText(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.25),
      );
  // Body Texts
  static TextStyle lblPrimaryText(BuildContext context) => GoogleFonts.inter(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Sub Texts
  static TextStyle lblSecondryText(BuildContext context) => GoogleFonts.inter(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle lblContentText(BuildContext context) => GoogleFonts.inter(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w600,
  );

  static TextStyle lblProfileContentText(BuildContext context) =>
      GoogleFonts.inter(
        color: const Color(0XFF888888),
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
      );

  static TextStyle bottomsheetTitleTextStyle(BuildContext context) =>
      GoogleFonts.inter(
        fontSize: 12.5.sp,
        color: Theme.of(context).colorScheme.onBackground,
        fontWeight: FontWeight.w600,
      );

  static TextStyle btnPrimaryText = GoogleFonts.inter(
    fontSize: 11.sp,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  static TextStyle btnSecondryText(BuildContext context) => GoogleFonts.inter(
    color: Theme.of(context).colorScheme.primary,
    fontSize: 13.sp,
    fontWeight: FontWeight.w400,
  );

  static TextStyle msgErrorText(BuildContext context) => GoogleFonts.inter(
    color: Theme.of(context).colorScheme.error,
    fontSize: 10.sp,
    fontWeight: FontWeight.w500,
  );

  static TextStyle msgSuccessText = GoogleFonts.inter(
    color: Colors.green,
    fontSize: 11.2.sp,
    fontWeight: FontWeight.w500,
  );
}
