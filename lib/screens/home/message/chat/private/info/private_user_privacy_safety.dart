// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../core/constants/app_radius.dart';
import '../../../../../../core/themes/app_text_colors.dart';
import '../../../../../../core/themes/app_text_styles.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import 'private_user_report.dart';


class PrivateUserPrivacySafety extends StatefulWidget {
  final dynamic chatId;


  const PrivateUserPrivacySafety({
    super.key,
    this.chatId,
  });

  @override
  State<PrivateUserPrivacySafety> createState() =>
      _PrivateUserPrivacySafetyState();
}

class _PrivateUserPrivacySafetyState extends State<PrivateUserPrivacySafety>
    with UtilityMixin {
  
  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Privacy & Safety'),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Support',
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 8.h),
            _buildCard(
              children: [
                _buildNavTile(
                  icon: Assets.images.icReport.path,
                  title: 'Report',
                  subtitle: 'Report spam, harmful content, or other concerns',
                  onTap: () {
                    navigationPush(context, const PrivateUserReport());
                  },
                ),
                const SizedBox(height: 5),
                _buildDivider(),
                const SizedBox(height: 8),
                _buildNavTile(
                  icon: Assets.images.icBlockAccount.path,
                  title: 'Block User',
                  subtitle: 'Stop receiving messages and seeing this user\'s content',
                  showArrow: false,
                  onTap: () {},
                ),
              ],
            ),
            SizedBox(height: 15.h),
            Text(
              'Privacy Information',
              style: AppTextStyles.bodyText.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              'Your privacy and safety matter. Report this person if something feels inappropriate or violates our guidelines, or block them if you no longer want to interact with them.',
              style: AppTextStyles.bodyText.copyWith(
                color: txt.body,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1,
        ),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildIconBox(String image) {
    return Container(
      height: 44,
      width: 44,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        image,
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
      ),
    );
  }

  Widget _buildNavTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    final txt = AppTextColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: txt.title,
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
          if (showArrow)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Color(0XFF595959),
            ),
        ],
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
}
