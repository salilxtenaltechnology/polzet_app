// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:polzet_app/core/constants/app_radius.dart';

import '../../core/themes/app_text_styles.dart';

class SecondryTextfield extends StatelessWidget {
  const SecondryTextfield({
    super.key,
    required this.controller,
    required this.hintText,
    this.suffixIcon,
    this.onChanged,
    this.maxLines = 1,
    this.minLines,
  });

  final TextEditingController controller;
  final String hintText;
  final IconButton? suffixIcon;
  final Function(String)? onChanged;
  final int? maxLines;
  final int? minLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.multiline,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      style: AppTextStyles.subText.copyWith(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onBackground,
        fontWeight: FontWeight.w400,
      ),
      cursorColor: Theme.of(context).colorScheme.onPrimary,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        hintText: hintText,
        hintStyle: AppTextStyles.subText.copyWith(
          fontSize: 14.5,
          color: const Color(0XFF898989),
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: suffixIcon,
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
