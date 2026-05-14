// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../languages/l10n/generated/app_localizations.dart';
import '../../core/themes/app_text_styles.dart';

class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title & subtitle section
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.logout,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  AppLocalizations.of(context)!.areyousurewanttologout,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),

          // Horizontal divider
          const Divider(height: 1, thickness: 1, color: Color(0XFFDCDCDC)),

          // Buttons row
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
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0XFFDCDCDC),
                ),

                // Log out button
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
                        AppLocalizations.of(context)!.logout,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5.sp,
                          color: const Color(0XFFE5484D),
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
