// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../../screens/home/poll/poll_images.dart';
import '../../screens/home/poll/poll_question.dart';
import '../custom_text_styles.dart';

class NewPollBottomsheet extends StatelessWidget with UtilityMixin {
  const NewPollBottomsheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12).w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(50.r),
          topRight: Radius.circular(50.r),
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
            style: CustomTextStyles.popTitleText(context),
          ),
          Divider(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
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
                      navigationPush(context, const PollQuestion());
                    },
                    child: Container(
                      height: 55.h,
                      width: 55.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryColor,
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 23.spMax,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    AppLocalizations.of(context)!.answer,
                    style: CustomTextStyles.lblSecondryText(context),
                  ),
                ],
              ),
              SizedBox(width: 40.w),
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                       Navigator.pop(context);
                      navigationPush(context, const PollImages());
                    },
                    child: Container(
                      height: 55.h,
                      width: 55.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryColor,
                      ),
                      child: Icon(
                        FeatherIcons.image,
                        size: 22.spMax,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    AppLocalizations.of(context)!.image,
                    style: CustomTextStyles.lblSecondryText(context),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
