// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';

class TermsAndConditions extends StatefulWidget {
  const TermsAndConditions({super.key});

  @override
  State<StatefulWidget> createState() {
    return TermsState();
  }
}

class TermsState extends State<TermsAndConditions> {
  final String email = 'contact@polzet.com';

  // Define the text styles for the title
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
     final TextStyle labelStyle = 
      AppTextStyles.cardTitle.copyWith(
        color: txt.body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.termsandconditions,
        showBackButton: true,
      ),

      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        children: [
          Text(AppLocalizations.of(context)!.lastupdated, style: titleStyle(context)),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.termsconditionsdescriptions,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.acceptanceofterms,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.bycreatinganaccountorusing,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.eligibility, style: titleStyle(context)),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.tousethePlatform,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.beatleast13yearsofage,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.notbeaconvictedsexoffender,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.provideaccurateandcomplete,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.useraccounts, style: titleStyle(context)),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.accountresponsibility,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youareresponsiblefor,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.termination, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereservetherightto,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.usercontent, style: titleStyle(context)),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.definition, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usercontentincludes,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.ownership, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youretainownershipof,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.responsibility, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tyouaresolelyresponsible,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youownorhavethenecessary,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourusercontentdoesnot,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourusercontentcomplies,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.contentremoval, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaybutarenotobligated,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.acceptableusepolicy,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.youagreenotto, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.postoruploadusercontent,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.engageinhatespeech,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.uploadcontentthatcontains,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usetheplatformfor,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.impersonateothersor,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.attempttoaccesscollect,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.violateanyapplicable,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.intellectualproperty,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.polzetcontent, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.allcontenttrademarks,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.dmcacompliance, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetcomplieswith,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.usercontentinfringement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouuploadcontent,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.privacy, style: titleStyle(context)),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youruseoftheplatform,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.thirdpartylinks,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.theplatformmaycontainlinks,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.limitationofliability,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.asisbasis, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.theplatformisprovidedas,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.noliabilityfor, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetisnotresponsible,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.noconsequentialdamages,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tothefullestextent,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.indemnification,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youagreetoindemnify,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.terminationlabel,
            style: titleStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.byyou, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youmayterminateyour,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.bypolzet, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaysuspendor,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.survival, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.provisionsofthese,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.miscellaneous, style: titleStyle(context)),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.entireagreement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.thesetermstogether,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.nowaiver, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ourfailureto,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.severability, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifanyprovisionofthese,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.assignment, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youmaynotassign,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.forcemajeure, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetwillnotbeliable,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.contactus, style: titleStyle(context)),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ifyouhavequestionsabout,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Row(
            children: [
              Text(
                '${AppLocalizations.of(context)!.email} : ',
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
          Text(
            AppLocalizations.of(context)!.byusingpolzetyouacknowledge,
            style: subTextStyle(context),
          ),
        ],
      ),
    );
  }
}
