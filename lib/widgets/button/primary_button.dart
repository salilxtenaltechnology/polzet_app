// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../custom_text_styles.dart';
import '../loader.dart';

class PrimaryButton extends StatelessWidget {
  PrimaryButton(
      {super.key,
      required this.title,
      required this.onPressed,
      required this.isLoading,
      this.height});

  final double? height;
  final String title;
  final VoidCallback? onPressed;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        width: double.infinity,
        margin:
            EdgeInsets.only(left: 15.w, right: 15.w, bottom: 10.h, top: 5.h),
        decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(50.r)),
        child: Center(
          child: isLoading
              ? Loader(color: Colors.white)
              : Text(title, style: CustomTextStyles.btnPrimaryText),
        ),
      ),
    );
  }
}
