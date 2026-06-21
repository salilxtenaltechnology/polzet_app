// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';

class AppUpdateDialog extends StatelessWidget {
  final VoidCallback onUpdatePressed;
  final String version;
  final List<String> releaseNotes;

  const AppUpdateDialog({
    super.key,
    required this.onUpdatePressed,
    this.version = '1.1.0',
    this.releaseNotes = const [
      'Drag & drop options before submitting polls',
      'Instant & easy poll results at a glance',
      'Real-time poll result notifications',
    ],
  });

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return Container(
      width: 320.w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mobile_screen_share,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'New Update Available',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Release note',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 14.2,
                        fontWeight: FontWeight.w600,
                        color: txt.title,
                      ),
                    ),
                    Text(
                      'Ver $version',
                      style: AppTextStyles.cardTitle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: txt.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (releaseNotes.isNotEmpty) ...[
                  ...releaseNotes.map((note) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          '‣ $note',
                          style: AppTextStyles.cardTitle.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 12),
                Text(
                  'A new version is available with new features and improvements. Please update.',
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 0.7,
            thickness: 0.7,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),

          // Action buttons row
          IntrinsicHeight(
            child: Row(
              children: [
                // Later button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Later',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 0.7,
                  thickness: 0.7,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),

                // Update button
                Expanded(
                  child: GestureDetector(
                    onTap: onUpdatePressed,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(20),
                          bottomLeft: Radius.zero,
                        ),
                      ),
                      child: Text(
                        'Update',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
