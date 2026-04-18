// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_radius.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../custom_text_styles.dart';

// open PIN security diolog animation
Future<bool> showDisablePINDiolog(
  BuildContext context,
  String title,
  String diologMessage,
) async {
  return await showGeneralDialog<bool>(
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
                  child: Container(
                    width: 300.w,
                    padding: EdgeInsets.fromLTRB(15.w, 12.h, 15.w, 12.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius:  AppRadius.cardRadius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          // AppLocalizations.of(context)!.disablepinsecurity,
                          style: CustomTextStyles.appBarTitleText(context),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          diologMessage,
                          // AppLocalizations.of(context)!.areyousurewanttodisablepinsecurity,
                          style: CustomTextStyles.lblPrimaryText(context),
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(false),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.cancel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onBackground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 15.w),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(true),
                              child: Text(
                                AppLocalizations.of(context)!.confirm
                                    .toUpperCase(), // Pending Language manage
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ) ??
      false;
}
