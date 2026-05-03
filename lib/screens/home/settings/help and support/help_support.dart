// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/custom_text_styles.dart';

class HelpSupport extends StatefulWidget {
  const HelpSupport({super.key});

  @override
  State<StatefulWidget> createState() {
    return HelpSupportState();
  }
}

class HelpSupportState extends State<HelpSupport> with UtilityMixin {
  final String email = 'contact@polzet.com';
  static TextStyle titleStyle = TextStyle(
    color: AppColors.primaryColor,
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w600,
  );

  static TextStyle labelStyle = TextStyle(
    color: const Color(0XFF545454),
    fontSize: 11.2.sp,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final TextStyle subtitleStyle = TextStyle(
      color: const Color(0XFF2B607B),
      fontSize: 11.2.sp,
      fontWeight: FontWeight.w600,
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
       appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.supportandabout,
        showBackButton: true,
      ),
     
      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
        children: [
          Text(AppLocalizations.of(context)!.lastupdated, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.helpandsupportdescriptions,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.howtocontactus,
            style: titleStyle,
          ), // policy_1
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weoffermultipleways,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.generalsupport,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.forquestionsaboutyouraccount,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.privacyanddatarequests,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(
              context,
            )!.forquestionsaboutyourpersonalinformation,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.reportingviolationsorabuse,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.toreportcontentthatviolates,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.copyrightinfringement,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tosubmitadmca,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.feedbackandsuggestions,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.welovehearingyourideas,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Text(
                '✧ ${AppLocalizations.of(context)!.email} : ',
                style: labelStyle,
              ),
              Text(
                'contact@polzet.com',
                style: TextStyle(
                  color: const Color(0xFF2194FF),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.responsetime, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereviewreportswithin,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.helpcenter, style: titleStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ouronlinehelpcenterprovides,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountsetupandmanagement,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.uploadingimagesandtext,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.privacyandsecuritysettings,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.reportingissuesorabusivecontent,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.troubleshootingtechnicalproblems,
            style: CustomTextStyles.lblPrimaryText(context),
          ),

          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.whattoexpectwhenyoucontactus,
            style: titleStyle,
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.acknowledgment, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.foremailinquiriesyouwill,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.resolutionprocess,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.oursupportteamwillreviewyourinquiry,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.escalation, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouarenotsatisfied,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.confidentiality,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wehandleyourinquiries,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.communityguidelines,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ensureyourcontent,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.verifythatyouhave,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.checkyourprivacysettings,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),

          Text(
            AppLocalizations.of(context)!.reportingtechnicalissues,
            style: titleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouencounterbugs,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.adescriptionoftheissue,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourdevicetypeandoperatingsystem,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.screenshotsorscreenrecordings,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ourtechnicalteamwillinvestigate,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.accessibilitysupport,
            style: titleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wearecommittedtomaking,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.feedbackmakesusbetter,
            style: titleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.yourinputhelpsusimprovethe,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.stayconnected, style: titleStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.forthelatestupdates,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.followusx,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.contactsummary, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.generalsupport,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.privacydatarequests,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.abusereports,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.copyrightissues,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.feedback,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.accessibility,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.helpcenter,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Text(
                '✧ ${AppLocalizations.of(context)!.email} : ',
                style: labelStyle,
              ),
              Text(
                'contact@polzet.com',
                style: TextStyle(
                  color: const Color(0xFF2194FF),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.responsetime, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereviewreportswithin,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
