// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

class CustomTextStyles {
  CustomTextStyles._();

  static TextStyle appTitleText(BuildContext context) => GoogleFonts.yesevaOne(
    fontSize: 22.sp,
    color: Theme.of(context).colorScheme.onBackground,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.0,
  );

  static TextStyle appBarTitleText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 13.5.sp,
    fontWeight: FontWeight.w500,
  );

  static TextStyle msgAuthTitleText(BuildContext context) =>
      TextStyle(fontSize: 11.sp, color: const Color(0XFF999999));

  static TextStyle lblPrimaryHintText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.25),
    fontSize: 12.2.sp,
  );

  static TextStyle lblSecondryHintText(BuildContext context) => TextStyle(
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.25),
  );

  static TextStyle lblPrimaryText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 12.8.sp,
    fontWeight: FontWeight.w400,
  );

  static TextStyle lblSecondryText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w400,
  );

  static TextStyle lblContentText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w600,
  );

  static TextStyle lblProfileContentText(BuildContext context) => TextStyle(
    color: const Color(0XFF888888),
    fontSize: 12.sp,
    fontWeight: FontWeight.w600,
  );

  static TextStyle lblNoInternetText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 14.2.sp,
    fontWeight: FontWeight.w500,
  );

  static TextStyle msgNoInternetText(BuildContext context) => TextStyle(
    fontSize: 12.5.sp,
    color: const Color(0XFF999999),
    fontWeight: FontWeight.w500,
  );

  static TextStyle popTitleText(BuildContext context) => TextStyle(
    fontSize: 13.7.sp,
    color: Theme.of(context).colorScheme.onBackground,
    fontWeight: FontWeight.w600,
  );

  static TextStyle btnPrimaryText = TextStyle(
    fontSize: 12.5.sp,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  static TextStyle btnSecondryText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.primary,
    fontSize: 13.sp,
    fontWeight: FontWeight.w400,
  );

  static TextStyle btnSaveChangesText = TextStyle(
    fontSize: 12.sp,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  static TextStyle msgErrorText = TextStyle(
    color: AppColors.redColor,
    fontSize: 11.3.sp,
    fontWeight: FontWeight.w500,
  );

  static TextStyle msgSuccessText = TextStyle(
    color: Colors.green,
    fontSize: 11.3.sp,
    fontWeight: FontWeight.w500,
  );
}
