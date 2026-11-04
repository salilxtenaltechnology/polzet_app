import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../models/poll/inspired_poll_data.dart';
import '../../../../widgets/image/app_cached_network_image.dart';

class InspiredPollCard extends StatelessWidget {
  final InspiredPollData inspiredData;
  final VoidCallback? onDismiss;

  const InspiredPollCard({
    super.key,
    required this.inspiredData,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage =
        inspiredData.imageUrl != null &&
        inspiredData.imageUrl!.trim().isNotEmpty;

    final backgroundColor = isDark
        ? const Color(0xFF1E1517)
        : const Color(0x0D9B3046);
    final borderColor = isDark
        ? const Color(0xFF382328)
        : const Color(0xFFF3E4E7);
  

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Sparkle icon + "Inspired by {username} poll"
          Row(
            children: [
              AppIcons.icInspire(
                size: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.5,
                      color: txt.title,
                      fontWeight: FontWeight.w400,
                    ),
                    children: [
                      const TextSpan(text: 'Inspired by '),
                      TextSpan(
                        text: inspiredData.username,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ' poll'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(left: 6.w),
                    child: Icon(
                      Icons.close,
                      size: 16.sp,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10.h),

          // Body: with or without thumbnail image
          if (hasImage)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppCachedNetworkImage(
                    imageUrl: inspiredData.imageUrl!,
                    width: 55.w,
                    height: 58.w,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (inspiredData.question.isNotEmpty)
                        Text(
                          inspiredData.question,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: txt.title,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (inspiredData.description != null &&
                          inspiredData.description!.trim().isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          inspiredData.description!,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: txt.title,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inspiredData.question.isNotEmpty)
                  Text(
                    inspiredData.question,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: txt.title,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (inspiredData.description != null &&
                    inspiredData.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    inspiredData.description!,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w400,
                      color: txt.title,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
