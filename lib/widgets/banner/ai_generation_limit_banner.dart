import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
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
      // 8, 7, 6, 5, 4: Green state
      bgColor = isDark ? const Color(0xFF173524) : const Color(0xFFE7F6EC);
      contentColor = const Color(0xFF0F9960);
    }

    return Container(
      width: 90,
      padding: const EdgeInsets.fromLTRB(12, 5, 10, 5),
      margin: EdgeInsets.only(right: 10.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isLimitReached
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Assets.images.icAiGenerate.image(
            width: 15,
            height: 15,
            color: contentColor,
          ),
          SizedBox(width: 5.w),
          Expanded(
            child:  Text(
                    '$remainingGenerations ${AppLocalizations.of(context)!.left}',
                    style: TextStyle(
                      fontSize: 13,
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
