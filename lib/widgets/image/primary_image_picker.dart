// ignore_for_file: deprecated_member_use, must_be_immutable
import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/app_colors.dart';
import '../custom_text_styles.dart';

class PrimaryImagePicker extends StatelessWidget {
  PrimaryImagePicker({
    super.key,
    required this.answer,
    required this.onTap,
    required this.image,
  });

  final String answer;
  VoidCallback onTap;
  File? image;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(answer, style: CustomTextStyles.lblSecondryText(context)),
        SizedBox(height: 5.h),
        DottedBorder(
          options: CustomPathDottedBorderOptions(
            strokeWidth: 1.8,
            dashPattern: [6, 4],
            customPath: (size) => Path()
              ..moveTo(0, size.height)
              ..relativeLineTo(size.width, 0),
            color: AppColors.primaryColor.withOpacity(0.6),
            borderPadding: EdgeInsets.zero,
            padding: EdgeInsets.zero,
          ),
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              height: 115.h,
              width: 150.w,
              child: Container(
                margin: EdgeInsets.all(3).w,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(7.r),
                  image: image != null
                      ? DecorationImage(
                          image: FileImage(image!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Center(
                  child: Icon(
                    Icons.file_upload_outlined,
                    color: image == null
                        ? Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.8)
                        : Colors.transparent,
                    size: 25.spMax,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
