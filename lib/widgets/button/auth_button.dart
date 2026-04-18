// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../custom_text_styles.dart';
import '../loader.dart';

class AuthButton extends StatelessWidget {
  AuthButton({
    super.key,
    required this.title,
    required this.onPressed,
    required this.isLoading,
  });

  final String title;
  final VoidCallback? onPressed;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 35.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppRadius.buttonRadius,
          border: Border.all(color: AppColors.primaryColor, width: 0.7),
        ),
        child: Center(
          child: isLoading
              ? Loader(color: Theme.of(context).colorScheme.primary)
              : Text(title, style: CustomTextStyles.btnSecondryText(context)),
        ),
      ),
    );
  }
}
