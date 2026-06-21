// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../gen/assets.gen.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../../screens/home/new poll/new_image_poll.dart';
import '../../screens/home/new poll/new_things_poll.dart';

class NewPollBottomsheet extends StatelessWidget with UtilityMixin {
  const NewPollBottomsheet({super.key});

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return SafeArea(
       top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12).w,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.modal),
            topRight: Radius.circular(AppRadius.modal),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 2.h,
              width: 100.w,
              decoration: BoxDecoration(
                color: const Color(0x7C868686),
                borderRadius: BorderRadius.circular(5.r),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              AppLocalizations.of(context)!.addnewpoll,
              style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
            ),
            Divider(
              color: Theme.of(context).colorScheme.outlineVariant,
              height: 25.h,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        navigationPush(context, const NewThingsPoll());
                      },
                      child: Container(
                        height: 55.h,
                        width: 55.w,
                        padding: const EdgeInsets.all(12).w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryColor,
                        ),
                        child: Assets.images.thingsIcon.image(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.answer,
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: txt.heading,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 40.w),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        navigationPush(context, const NewImagePoll());
                      },
                      child: Container(
                        height: 55.h,
                        width: 55.w,
                        padding: const EdgeInsets.all(12).w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryColor,
                        ),
                        child: Assets.images.imageIcon.image(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.image,
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: txt.heading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
