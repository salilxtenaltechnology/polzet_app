// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/custom_text_styles.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
// bool _showBusinessInsights = false; // track state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            CustomCard(
                widget: Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.pink),
                SizedBox(width: 7.w),
                Text(AppLocalizations.of(context)!.totalviews),
                Spacer(),
                Text('12,430',
                    style: TextStyle(
                        fontSize: 11.sp, fontWeight: FontWeight.bold)),
              ],
            )),
            SizedBox(height: 10.h),
            CustomCard(
                widget: Row(
              children: [
                Icon(Icons.people, color: Colors.orange),
                SizedBox(width: 7.w),
                Text(AppLocalizations.of(context)!.vibe),
                Spacer(),
                Text('3,210',
                    style: TextStyle(
                        fontSize: 11.sp, fontWeight: FontWeight.bold)),
              ],
            )),
            SizedBox(height: 7.h),
            CustomCard(
                widget: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green),
                SizedBox(width: 7.w),
                Text(AppLocalizations.of(context)!.engagementrate),
                Spacer(),
                Text('8.2%',
                    style: TextStyle(
                        fontSize: 11.sp, fontWeight: FontWeight.bold)),
              ],
            )),
            SizedBox(height: 10.h),
            Divider(
              thickness: 1,
              height: 30,
              color:
                  Theme.of(context).colorScheme.onBackground.withOpacity(0.1),
            ),
            SizedBox(height: 10.h),
            CustomCard(
              widget: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 80.h,
                    width: 80.w,
                    child: Lottie.asset(
                      Assets.assetsImagesInsights,
                      repeat: true,
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.insightsareavailable,
                    textAlign: TextAlign.center,
                    style: CustomTextStyles.lblContentText(context),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    AppLocalizations.of(context)!.trackpollvotesreactions,
                    textAlign: TextAlign.center,
                    style: CustomTextStyles.lblSecondryText(context),
                  ),

                  // 👉 Gradient Button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        //  _showBusinessInsights = true;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      margin: EdgeInsets.only(top: 12.h, bottom: 5.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFFF59E0B)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.switchtobusinessaccount,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
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
      ),
    );
  }
}
