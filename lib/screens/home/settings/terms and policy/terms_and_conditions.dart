// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';

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
    fontSize: 12.5.sp,
    fontWeight: FontWeight.w600,
  );

  // Define the text styles for the labletext
  static TextStyle labelStyle = TextStyle(
    color: Color(0XFF545454),
    fontSize: 11.4.sp,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: PrimaryBackButton(),
        title: Text(
          AppLocalizations.of(context)!.termsandconditions,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        children: [
          Text(AppLocalizations.of(context)!.lastupdated, style: titleStyle),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.termsconditionsdescriptions,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.acceptanceofterms,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.bycreatinganaccountorusing,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.notbeaconvictedsexoffender,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.provideaccurateandcomplete,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.termination, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wereservetherightto,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.usercontent, style: titleStyle),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.definition, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usercontentincludes,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.ownership, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youretainownershipof,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.responsibility, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tyouaresolelyresponsible,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youownorhavethenecessary,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourusercontentdoesnot,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.yourusercontentcomplies,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.contentremoval, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaybutarenotobligated,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.engageinhatespeech,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.uploadcontentthatcontains,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usetheplatformfor,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.impersonateothersor,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.attempttoaccesscollect,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.violateanyapplicable,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.dmcacompliance, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetcomplieswith,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.usercontentinfringement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouuploadcontent,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.privacy, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youruseoftheplatform,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.thirdpartylinks,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.theplatformmaycontainlinks,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.noliabilityfor, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetisnotresponsible,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.noconsequentialdamages,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.tothefullestextent,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.indemnification,
            style: titleStyle,
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youagreetoindemnify,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.bypolzet, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaysuspendor,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.survival, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.provisionsofthese,
            style: CustomTextStyles.lblSecondryText(context),
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
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(AppLocalizations.of(context)!.nowaiver, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ourfailureto,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.severability, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifanyprovisionofthese,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.assignment, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youmaynotassign,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.forcemajeure, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetwillnotbeliable,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.contactus, style: titleStyle),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ifyouhavequestionsabout,
            style: CustomTextStyles.lblSecondryText(context),
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
                  color: Color(0xFF2194FF),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.byusingpolzetyouacknowledge,
            style: CustomTextStyles.lblSecondryText(context),
          ),
        ],
      ),
    );
  }
}
