// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../languages/l10n/generated/app_localizations.dart';

class AddAnonymousPoll extends StatelessWidget {
  const AddAnonymousPoll({
    super.key,
    required this.onPressedThings,
    required this.onPressedImage,
  });

  final VoidCallback? onPressedThings;
  final VoidCallback? onPressedImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(
            context,
            AppLocalizations.of(context)!.things,
            onPressedThings,
          ),
          _primaryDivider(context),
          _label(context, AppLocalizations.of(context)!.image, onPressedImage),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text, VoidCallback? onTap) {
    final txt = AppTextColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.subText.copyWith(
              color: txt.title,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
