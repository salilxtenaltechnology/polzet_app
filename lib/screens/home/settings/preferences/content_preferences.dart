// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import 'country/country_list.dart';
import 'interest/interest_list.dart';

class ContentPreferences extends StatefulWidget {
  const ContentPreferences({super.key});

  @override
  State<ContentPreferences> createState() => _ContentPreferencesState();
}

class _ContentPreferencesState extends State<ContentPreferences>
    with UtilityMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:  CommonAppBar(
        title: AppLocalizations.of(context)!.contentpreferences,
        showBackButton: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: _buildCard(
          children: [
            _buildNavTile(
              icon: Assets.images.icCountry.path,
              title: AppLocalizations.of(context)!.country,
              subtitle: AppLocalizations.of(context)!.choosethecountryforyourcontentandpolls,
              onTap: () {
                navigationPush(context, const CountryList());
              },
            ),
            const SizedBox(height: 8),
            _buildDivider(),
            const SizedBox(height:8),
            _buildNavTile(
              icon: Assets.images.icInterest.path,
              title: AppLocalizations.of(context)!.interests,
              subtitle: AppLocalizations.of(context)!.choosethetopicsyouwanttoseemoreof,
              onTap: () {
                navigationPush(context, const InterestList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildIconBox(String image) {
    return Container(
      height: 47,
      width: 47,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        image,
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      thickness: 0.5,
      height: 5,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildNavTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final txt = AppTextColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _buildIconBox(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: txt.title,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: txt.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15.5,
              color: Color(0XFF595959),
            ),
          ],
        ),
      ),
    );
  }
}
