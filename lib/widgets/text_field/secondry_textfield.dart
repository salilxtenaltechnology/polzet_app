// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:polzet_app/core/constants/app_radius.dart';

import '../../../core/constants/app_colors.dart';
import '../custom_text_styles.dart';

class SecondryTextfield extends StatelessWidget {
  const SecondryTextfield({
    super.key,
    required this.controller,
    required this.hintText,
    this.suffixIcon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final IconButton? suffixIcon;
  final Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.multiline,
      maxLines: 1,
      onChanged: onChanged,
      style: CustomTextStyles.lblPrimaryText(context),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        hintText: hintText,
        hintStyle: CustomTextStyles.lblSecondryHintText(context),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.primaryColor.withOpacity(0.7),
          ),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
    );
  }
}
