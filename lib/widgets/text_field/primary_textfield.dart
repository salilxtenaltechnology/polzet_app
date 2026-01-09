// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../custom_text_styles.dart';

class PrimaryTextfield extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool isRead;
  final int? maxLength;
  final autofillHints;
  final String labelText;
  final Widget? prefixIcon;
  final IconButton? suffixIcon;
  final ValueChanged<String>? onSubmitted;
  bool icon = true;
  PrimaryTextfield(
      {super.key,
      required this.controller,
      required this.labelText,
      this.keyboardType = TextInputType.text,
      this.isPassword = true,
      this.isRead = false,
      this.maxLength,
      this.autofillHints,
      this.prefixIcon,
      this.suffixIcon,
      this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 45.h,
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          readOnly: isRead,
          maxLength: maxLength,
          style: CustomTextStyles.lblPrimaryText(context),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.only(bottom: 8, right: 10),
            counterText: '',
            hintText: labelText,
            hintStyle: CustomTextStyles.lblPrimaryHintText(context),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            border: InputBorder.none,
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.1),
                ),
                borderRadius: BorderRadius.circular(50)),
            focusedBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primaryColor.withOpacity(0.7)),
                borderRadius: BorderRadius.circular(50)),
          ),
        ));
  }
}
