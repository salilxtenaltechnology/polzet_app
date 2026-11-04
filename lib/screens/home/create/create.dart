// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/screens/home/message/group/create_group.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/feather_icons_compat.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../new poll/add_new_poll.dart';
import 'post/create_post.dart';

class Create extends StatefulWidget {
  const Create({super.key});

  @override
  State<Create> createState() => _CreateState();
}

class _CreateState extends State<Create> {
  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:  CommonAppBar(title: AppLocalizations.of(context)!.create, showBackButton: true),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.h, vertical: 5),
              child: Text(
               AppLocalizations.of(context)!.whatdoyouwanttocreate,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 14,
                  color: txt.body,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            _buildCard(
              child: _buildNavTile(
                icon: Assets.images.icPoll.path,
                title: AppLocalizations.of(context)!.createpoll,
                subtitle: AppLocalizations.of(context)!.askaquestiongetopinions,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.topToBottom,
                      duration: const Duration(microseconds: 200),
                      child: const AddNewPoll(),
                    ),
                  );
                },
              ),
            ),
            _buildCard(
              child: _buildNavTile(
                icon: Assets.images.icImagePoll.path,
                title: AppLocalizations.of(context)!.createpost,
                subtitle: AppLocalizations.of(context)!.sharephotosandthoughts,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.topToBottom,
                      duration: const Duration(microseconds: 200),
                      child: const CreatePost(),
                    ),
                  );
                },
              ),
            ),
            _buildCard(
              child: _buildNavTile(
                icon: Assets.images.icGroup.path,
                title: AppLocalizations.of(context)!.creategroup,
                subtitle: AppLocalizations.of(context)!.privateconversationsshareddiscussions,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.topToBottom,
                      duration: const Duration(microseconds: 200),
                      child: const CreateGroup(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 5),
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
      child: child,
    );
  }

  Widget _buildIconBox(String image) {
    return Container(
      height: 47,
      width: 47,
      padding: const EdgeInsets.all(13),
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
