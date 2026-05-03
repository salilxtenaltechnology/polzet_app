// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTextStyles {
  // H-1 — Display / Page Title
  static TextStyle pageTitleTextStyle(BuildContext context) => TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600, // Bold
    fontSize: 18.sp,
    height: 30 / 22, // line height 30px
    letterSpacing: 0,
    color: Theme.of(context).colorScheme.onBackground,
  );

  // H-2 — Section Heading
  static const sectionHeading = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600, // SemiBold
    fontSize: 18,
    height: 26 / 18, // line height 26px
    letterSpacing: 0,
  );

  // H-3 — Sub-section Heading
  static const subSectionHeading = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600, // SemiBold
    fontSize: 16,
    height: 24 / 16, // line height 24px
    letterSpacing: 0,
  );

  // H-4 — Card Title
  static const cardTitle = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500, // Medium
    fontSize: 15,
    height: 22 / 15, // line height 22px
    letterSpacing: 0,
  );

  // H-5 — Body
  static const bodyText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400, // Regular
    fontSize: 14,
    height: 20 / 14, // line height 20px
    letterSpacing: 0,
  );

  // H-6 — Subtext
  static const subText = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400, // Regular
    fontSize: 12,
    height: 16 / 12, // line height 16px
    letterSpacing: 0,
  );
}
