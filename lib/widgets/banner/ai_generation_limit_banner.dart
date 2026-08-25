import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../gen/assets.gen.dart';

class AiGenerationLimitBanner extends StatelessWidget {
  final int remainingGenerations;

  const AiGenerationLimitBanner({
    super.key,
    required this.remainingGenerations,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor;
    final Color contentColor;
    final bool isLimitReached = remainingGenerations <= 0;

    if (isLimitReached) {
      // 0 (ended): Red state
      bgColor = isDark ? const Color(0xFF3B1C21) : const Color(0xFFFDE8E8);
      contentColor = const Color(0xFFDC2626);
    } else if (remainingGenerations <= 3) {
      // 3, 2, 1: Yellow/Orange state
      bgColor = isDark ? const Color(0xFF3D2C1A) : const Color(0xFFFFF4E5);
      contentColor = const Color(0xFFE58D03);
    } else {
      // 5, 4: Green state
      bgColor = isDark ? const Color(0xFF173524) : const Color(0xFFE7F6EC);
      contentColor = const Color(0xFF0F9960);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment:
            isLimitReached ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Assets.images.icAssistant.image(
            width: 18.w,
            height: 18.h,
            color: contentColor,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: isLimitReached
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No AI generations left today',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: contentColor,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'Your credits will reset tomorrow',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  )
                : Text(
                    '$remainingGenerations AI ${remainingGenerations == 1 ? 'generation' : 'generations'} left today',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: contentColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
