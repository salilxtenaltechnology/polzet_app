// ignore_for_file: must_be_immutable, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../languages/l10n/generated/app_localizations.dart';

class PinSecurityDiolog extends StatelessWidget {
  PinSecurityDiolog({
    super.key,
    required this.title,
    required this.diologMessage,
    required this.onPressed,
  });

  String title;
  String diologMessage;
  final VoidCallback? onPressed;

  // Static method to show the dialog with animation
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String diologMessage,
    required VoidCallback? onPressed,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dialog',
      barrierColor: const Color(0xA2000000),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: PinSecurityDiolog(
                  title: title,
                  diologMessage: diologMessage,
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  diologMessage,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.body,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 0.7,
            thickness: 0.7,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          IntrinsicHeight(
            child: Row(
              children: [
                // Cancel button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5.sp,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),

                // Vertical divider
                VerticalDivider(
                  width: 0.7,
                  thickness: 0.7,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),

                // Confirm button
                Expanded(
                  child: GestureDetector(
                    onTap: onPressed,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.confirm,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
