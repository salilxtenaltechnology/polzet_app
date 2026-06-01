// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';

class HelpSupport extends StatefulWidget {
  const HelpSupport({super.key});

  @override
  State<StatefulWidget> createState() {
    return HelpSupportState();
  }
}

class HelpSupportState extends State<HelpSupport> with UtilityMixin {
  final String email = 'contact@polzet.com';

  static TextStyle titleStyle(BuildContext context) =>
      AppTextStyles.sectionHeading.copyWith(
        color: Theme.of(context).colorScheme.onPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle subTextStyle(BuildContext context) =>
      AppTextStyles.subText.copyWith(
        color: Theme.of(context).colorScheme.onBackground,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final TextStyle labelTextStyle = AppTextStyles.cardTitle.copyWith(
      color: txt.body,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    final TextStyle subtitleStyle = AppTextStyles.cardTitle.copyWith(
      color: txt.title,
      fontSize: 14,
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
          Text(
            AppLocalizations.of(context)!.lastupdated,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.helpandsupportdescriptions,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.howtocontactus,
            style: titleStyle(context),
          ), // policy_1
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weoffermultipleways,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.generalsupport,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.forquestionsaboutyouraccount,
            style: subTextStyle(context),
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
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.reportingviolationsorabuse,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.toreportcontentthatviolates,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.copyrightinfringement,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tosubmitadmca,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.feedbackandsuggestions,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.welovehearingyourideas,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Text(
                '✧ ${AppLocalizations.of(context)!.email} : ',
                style: labelTextStyle,
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
          Text(
            AppLocalizations.of(context)!.responsetime,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereviewreportswithin,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.helpcenter,
            style: titleStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ouronlinehelpcenterprovides,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountsetupandmanagement,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.uploadingimagesandtext,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.privacyandsecuritysettings,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.reportingissuesorabusivecontent,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.troubleshootingtechnicalproblems,
            style: subTextStyle(context),
          ),

          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.whattoexpectwhenyoucontactus,
            style: titleStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.acknowledgment,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.foremailinquiriesyouwill,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.resolutionprocess,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.oursupportteamwillreviewyourinquiry,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.escalation, style: labelTextStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouarenotsatisfied,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.confidentiality,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wehandleyourinquiries,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.communityguidelines,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ensureyourcontent,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.verifythatyouhave,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.checkyourprivacysettings,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),

          Text(
            AppLocalizations.of(context)!.reportingtechnicalissues,
            style: titleStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouencounterbugs,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.adescriptionoftheissue,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourdevicetypeandoperatingsystem,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.screenshotsorscreenrecordings,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ourtechnicalteamwillinvestigate,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.accessibilitysupport,
            style: titleStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wearecommittedtomaking,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.feedbackmakesusbetter,
            style: titleStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.yourinputhelpsusimprovethe,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.stayconnected,
            style: titleStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.forthelatestupdates,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.followusx,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.contactsummary,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.generalsupport,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.privacydatarequests,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.abusereports,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.copyrightissues,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.feedback,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.accessibility,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.helpcenter,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Text(
                '✧ ${AppLocalizations.of(context)!.email} : ',
                style: labelTextStyle,
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
          Text(
            AppLocalizations.of(context)!.responsetime,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereviewreportswithin,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
