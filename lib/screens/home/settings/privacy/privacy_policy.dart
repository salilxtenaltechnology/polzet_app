// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<StatefulWidget> createState() {
    return PrivacyState();
  }
}

class PrivacyState extends State<PrivacyPolicy> {
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
      color: txt.title,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );

    final TextStyle sublabelTextStyle = AppTextStyles.cardTitle.copyWith(
      color: txt.body,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.privacypolicy,
        showBackButton: true,
      ),

      body: ListView(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 12.h),
        children: [
          Text(
            AppLocalizations.of(context)!.lastupdated,
            style: titleStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.privacypolicydescriptions,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.informationwecollect,
            style: titleStyle(context),
          ), // policy_1
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectiinformation,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.informationyouprovide,
            style: labelTextStyle,
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountinformation,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.whenyoucreateanaccount,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.usecontent,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectimages,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.communications,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectyourcontactdetails,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.surveysandfeedback,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaycollectinformationyourovide,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.informationcollectedautomatically,
            style: labelTextStyle,
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.usagedata,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(
              context,
            )!.wecollectinformationaboutyourinteractions,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.deviceandtechnicalinformation,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wecollectdetailsaboutyourdevice,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.locationdata,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.withyourconsentwemay,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.cookiesandtrackingtechnologies,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weusecookieswebbeacons,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.informationfromthirdparties,
            style: labelTextStyle,
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.socialmediaintegrations,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.ifyouconnectyourpolzetaccount,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.analyticsandadvertisingpartners,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayreceiveaggregatedoranonymized,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.howweuseyourinformation,
            style: titleStyle(context),
          ), // policy_2
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weuseyourinformationto,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.provideandimprovetheplatform,
            style: sublabelTextStyle,
          ), //
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.operatemaintainandenhanc,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountmanagement,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.createandmanageyouraccount,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountmanagement,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.respondtoyourinquiriessend,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.analyticsandresearch,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.analysesusagetrends,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.advertising,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.delivertargetedadvertisements,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.safetyandsecurity,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.detectandpreventfraud,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.legalcompliance,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.complywithapplicablelaws,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.howweshareyourinformation,
            style: titleStyle(context),
          ), // policy_3
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayshareyourinformationasfollows,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withotherusers,
            style: labelTextStyle,
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.publiccontent,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.usercontentyoupostpublicly,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.profileinformation,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.yourusernameprofilepicture,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withserviceproviders,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weshareinformationwiththirdparty,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withbusinesspartners,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayshareanonymizedoraggregated,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.forlegalreasons,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemaydiscloseyourinformationtocomply,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.intheeventofamerger,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.withyourconsent,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.wemayshareyourinformationfor,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.yourchoicesandrights,
            style: titleStyle(context),
          ), // policy_4
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountandprivacysettings,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youcanmanageyourprivacysettings,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.youmayupdateordelete,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.marketingcommunications,
            style: labelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youcanoptoutofreceiving,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.cookies, style: labelTextStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.youcandisablecookiesthrough,
            style: subTextStyle(context),
          ),

          SizedBox(height: 15.h),
          Text(AppLocalizations.of(context)!.datarights, style: labelTextStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.dependingonyourjurisdiction,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(AppLocalizations.of(context)!.access, style: sublabelTextStyle),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestacopyof,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.correction,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestcorrectionsto,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.deletion,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestdeletionof,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.restriction,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestrestrictionson,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.portability,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.requestacopyofyour,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.objection,
            style: sublabelTextStyle,
          ),
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.objecttocertainprocessing,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.toexercisetheserights,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.dataretention,
            style: titleStyle(context),
          ), // policy_5
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weretainyourpersonalinformationfor,
            style: subTextStyle(context),
          ),
          SizedBox(height: 15.h),
          Text(
            AppLocalizations.of(context)!.accountinformationisretained,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.usercontentmayremain,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.usagedatamayberetained,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.whenwenolongerneed,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.datascurity,
            style: titleStyle(context),
          ), // policy_6
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.weimplementreasonabletechnical,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.internationalsdatatransfers,
            style: titleStyle(context),
          ), // policy_7
          SizedBox(height: 5.h),
          Text(
            AppLocalizations.of(context)!.polzetoperatesglobally,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.childrensprivacy,
            style: titleStyle(context),
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
                    color: const Color(0xFF2194FF),
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
            style: titleStyle(context),
          ), // policy_9
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.theplatformmaycontainlinks,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.changestothisprivacypolicy,
            style: titleStyle(context),
          ), // policy_10
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.wemayupdatethisprivacypolicy,
            style: subTextStyle(context),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.contactus,
            style: titleStyle(context),
          ), // policy_11
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.ifyouhavequestions,
            style: subTextStyle(context),
          ),
          SizedBox(height: 5.h),
          Row(
            children: [
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
            AppLocalizations.of(context)!.thankyoufortrusting,
            style: subTextStyle(context),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}
