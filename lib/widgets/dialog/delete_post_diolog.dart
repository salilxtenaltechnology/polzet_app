// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';

import '../../core/constants/app_radius.dart';
import '../../languages/l10n/generated/app_localizations.dart';

class DeletePostDiolog extends StatelessWidget {
  const DeletePostDiolog({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200.w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label(context, AppLocalizations.of(context)!.delete, onPressed),
          _primaryDivider(context),
          _label(context, AppLocalizations.of(context)!.cancel, () {
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text, VoidCallback? onTap) {
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
              color: Theme.of(context).colorScheme.onBackground,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryDivider(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0XFFDCDCDC));
  }
}
