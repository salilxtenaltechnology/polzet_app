// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
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
  static TextStyle titleStyle = TextStyle(
    color: AppColors.primaryColor,
    fontSize: 11.7.sp,
    fontWeight: FontWeight.w600,
  );

  static TextStyle lblSecondryText(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onBackground,
    fontSize: 11.5.sp,
    fontWeight: FontWeight.w400,
  );

  // Define the text styles for the labletext
  static TextStyle labelStyle = TextStyle(
    color: const Color(0XFF545454),
    fontSize: 11.2.sp,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.termsandconditions,
        showBackButton: true,
      ),

      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        children: [
          Text(AppLocalizations.of(context)!.lastupdated, style: titleStyle),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.termsconditionsdescriptions,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.acceptanceofterms,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.bycreatinganaccountorusing,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.eligibility, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.tousethePlatform,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.beatleast13yearsofage,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.notbeaconvictedsexoffender,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.provideaccurateandcomplete,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.useraccounts, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.accountresponsibility,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youareresponsiblefor,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.termination, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereservetherightto,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.usercontent, style: titleStyle),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.definition, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usercontentincludes,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.ownership, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youretainownershipof,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.responsibility, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tyouaresolelyresponsible,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youownorhavethenecessary,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourusercontentdoesnot,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourusercontentcomplies,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.contentremoval, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaybutarenotobligated,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.acceptableusepolicy,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.youagreenotto, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.postoruploadusercontent,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.engageinhatespeech,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.uploadcontentthatcontains,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usetheplatformfor,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.impersonateothersor,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.attempttoaccesscollect,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.violateanyapplicable,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.intellectualproperty,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.polzetcontent, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.allcontenttrademarks,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.dmcacompliance, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetcomplieswith,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.usercontentinfringement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouuploadcontent,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.privacy, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youruseoftheplatform,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.thirdpartylinks,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.theplatformmaycontainlinks,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.limitationofliability,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.asisbasis, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.theplatformisprovidedas,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.noliabilityfor, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetisnotresponsible,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.noconsequentialdamages,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tothefullestextent,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.indemnification,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youagreetoindemnify,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.terminationlabel,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.byyou, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youmayterminateyour,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.bypolzet, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaysuspendor,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.survival, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.provisionsofthese,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.miscellaneous, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.entireagreement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.thesetermstogether,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.nowaiver, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ourfailureto,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.severability, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifanyprovisionofthese,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.assignment, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youmaynotassign,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.forcemajeure, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetwillnotbeliable,
            style: lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.contactus, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ifyouhavequestionsabout,
            style: lblSecondryText(context),
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
            style: lblSecondryText(context),
          ),
        ],
      ),
    );
  }
}
