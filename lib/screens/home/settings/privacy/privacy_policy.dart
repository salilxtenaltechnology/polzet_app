// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<StatefulWidget> createState() {
    return PrivacyState();
  }
}

class PrivacyState extends State<PrivacyPolicy> {
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
    // Define the text styles for the subtitle
    final TextStyle subtitleStyle = TextStyle(
      color: Color(0XFF2B607B),
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: PrimaryBackButton(),
        title: Text(
          AppLocalizations.of(context)!.privacypolicy,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
        children: [
          Text(AppLocalizations.of(context)!.lastupdated, style: titleStyle),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.privacypolicydescriptions,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.informationwecollect,
            style: titleStyle,
          ), // policy_1
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectiinformation,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.informationyouprovide,
            style: subtitleStyle,
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountinformation,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.whenyoucreateanaccount,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.usecontent, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectimages,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.communications, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectyourcontactdetails,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.surveysandfeedback,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaycollectinformationyourovide,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.informationcollectedautomatically,
            style: subtitleStyle,
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.usagedata, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(
              context,
            )!.wecollectinformationaboutyourinteractions,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.deviceandtechnicalinformation,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectdetailsaboutyourdevice,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.locationdata, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.withyourconsentwemay,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.cookiesandtrackingtechnologies,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weusecookieswebbeacons,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.informationfromthirdparties,
            style: subtitleStyle,
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.socialmediaintegrations,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouconnectyourpolzetaccount,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.analyticsandadvertisingpartners,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayreceiveaggregatedoranonymized,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.howweuseyourinformation,
            style: titleStyle,
          ), // policy_2
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weuseyourinformationto,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.provideandimprovetheplatform,
            style: labelStyle,
          ), //
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.operatemaintainandenhanc,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountmanagement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.createandmanageyouraccount,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountmanagement,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.respondtoyourinquiriessend,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.analyticsandresearch,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.analysesusagetrends,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.advertising, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.delivertargetedadvertisements,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.safetyandsecurity,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.detectandpreventfraud,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.legalcompliance,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.complywithapplicablelaws,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.howweshareyourinformation,
            style: titleStyle,
          ), // policy_3
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayshareyourinformationasfollows,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withotherusers,
            style: subtitleStyle,
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.publiccontent, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usercontentyoupostpublicly,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.profileinformation,
            style: labelStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.yourusernameprofilepicture,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withserviceproviders,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weshareinformationwiththirdparty,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withbusinesspartners,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayshareanonymizedoraggregated,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.forlegalreasons,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaydiscloseyourinformationtocomply,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.intheeventofamerger,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withyourconsent,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayshareyourinformationfor,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.yourchoicesandrights,
            style: titleStyle,
          ), // policy_4
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountandprivacysettings,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youcanmanageyourprivacysettings,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youmayupdateordelete,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.marketingcommunications,
            style: subtitleStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youcanoptoutofreceiving,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.cookies, style: subtitleStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youcandisablecookiesthrough,
            style: CustomTextStyles.lblSecondryText(context),
          ),

          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.datarights, style: subtitleStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.dependingonyourjurisdiction,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.access, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestacopyof,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.correction, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestcorrectionsto,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.deletion, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestdeletionof,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.restriction, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestrestrictionson,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.portability, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestacopyofyour,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.objection, style: labelStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.objecttocertainprocessing,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.toexercisetheserights,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.dataretention,
            style: titleStyle,
          ), // policy_5
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weretainyourpersonalinformationfor,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountinformationisretained,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.usercontentmayremain,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.usagedatamayberetained,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.whenwenolongerneed,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.datascurity,
            style: titleStyle,
          ), // policy_6
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weimplementreasonabletechnical,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.internationalsdatatransfers,
            style: titleStyle,
          ), // policy_7
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetoperatesglobally,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.childrensprivacy,
            style: titleStyle,
          ), // policy_8
          SizedBox(height: 5.h),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 14.1.sp,
                fontWeight: FontWeight.w400,
              ),
              children: [
                TextSpan(
                  text: AppLocalizations.of(context)!.theplatformisnotintended,
                ),
                TextSpan(
                  text: ' contact@polzet.com.',
                  style: TextStyle(
                    color: Color(0xFF2194FF),
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.thirdpartylinksandservices,
            style: titleStyle,
          ), // policy_9
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.theplatformmaycontainlinks,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.changestothisprivacypolicy,
            style: titleStyle,
          ), // policy_10
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.wemayupdatethisprivacypolicy,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.contactus,
            style: titleStyle,
          ), // policy_11
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ifyouhavequestions,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 5.h),
          Row(
            children: [
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
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.thankyoufortrusting,
            style: CustomTextStyles.lblSecondryText(context),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}
