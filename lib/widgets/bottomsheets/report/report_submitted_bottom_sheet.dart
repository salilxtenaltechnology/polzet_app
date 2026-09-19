// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';

Future<void> showReportSubmittedBottomSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const ReportSubmittedBottomSheet(),
  );
}

class ReportSubmittedBottomSheet extends StatelessWidget {
  const ReportSubmittedBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF161821)
            : Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      padding: EdgeInsets.only(
        top: 12.h,
        bottom: MediaQuery.of(context).padding.bottom + 40.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle Bar ───────────────────────────────────────────────
          Center(
            child: Container(
              width: 50.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.25)
                    : const Color(0xFFBDBDBD),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 28.h),

          // ── Success Checkmark Icon Badge ──────────────────────────────────
          Container(
            width: 60.w,
            height: 60.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF9E2A3B),
            ),
            child: const Center(
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          SizedBox(height: 18.h),

          // ── Title ─────────────────────────────────────────────────────────
          Text(
            'Report submitted',
            textAlign: TextAlign.center,
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          SizedBox(height: 8.h),

          // ── Description Subtitle ──────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Text(
              "Thanks for reporting. Your report has been received and will be reviewed according to Polzet's guidelines",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: txt.muted,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
