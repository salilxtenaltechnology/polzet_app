// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/screens/home/new%20poll/type/new_anonymous_poll.dart';
import 'package:polzet_app/screens/home/new%20poll/type/new_battel_poll.dart';
import 'package:polzet_app/screens/home/new%20poll/type/new_this_or_that.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../mixin/utility_mixins.dart';
import 'type/new_hot_take_poll.dart';
import 'type/new_image_poll.dart';
import 'type/new_text_poll.dart';

class AddNewPoll extends StatefulWidget {
  const AddNewPoll({super.key});

  @override
  State<AddNewPoll> createState() => _AddNewPollState();
}

class _AddNewPollState extends State<AddNewPoll> with UtilityMixin {
  // Define poll options
  List<Map<String, dynamic>> _getPollOptions(BuildContext context) {
    return [
      {
        'title': 'Text Poll',
        'subtitle': 'Ask simple questions with text choices',
        'image': Assets.images.icTextPoll,
        'screen': const NewTextPoll(),
        'iconBackgroundColor': const Color(0XFFC026D3).withOpacity(0.1),
      },
      {
        'title': 'Image Poll',
        'subtitle': 'Compare photos and visual choices',
        'image': Assets.images.icImagePoll,
        'screen': const NewImagePoll(),
        'iconBackgroundColor': const Color(0XFFDE42AA).withOpacity(0.1),
      },
      {
        'title': 'Battle Poll',
        'subtitle': 'Compare rivals and crown a winner',
        'image': Assets.images.icBattel,
        'screen': const NewBattelPoll(),
        'iconBackgroundColor': const Color(0XFFDC2626).withOpacity(0.1),
      },
      {
        'title': 'This or That',
        'subtitle': 'Pick between two quick choices',
        'image': Assets.images.icThisThat,
        'screen': const NewThisOrThat(),
        'iconBackgroundColor': const Color(0XFF16A34A).withOpacity(0.12),
      },
      {
        'title': 'Hot Takes Poll',
        'subtitle': 'Share opinions and start debates',
        'image': Assets.images.icHot,
        'screen': const NewHotTakePoll(),
        'iconBackgroundColor': const Color(0XFFEA580C).withOpacity(0.12),
      },
      {
        'title': 'Anonymous Poll',
        'subtitle': 'Get honest opinions privately',
        'image': Assets.images.icAnonymous,
        'screen': const NewAnonymousPoll(),
        'iconBackgroundColor': const Color(0XFF7C3AED).withOpacity(0.12),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _getPollOptions(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(
        title: 'Create your first poll',
        showBackButton: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 10.h),
                    Text(
                      'Choose how you want to ask your question',
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 14,
                        color: txt.body,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16.h,
                  crossAxisSpacing: 16.w,
                  childAspectRatio: 0.99,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final option = options[index];
                  return _buildPollOptionCard(
                    context: context,
                    title: option['title']!,
                    subtitle: option['subtitle']!,
                    iconBackgroundColor: option['iconBackgroundColor'],
                    image: option['image']!,
                    isDark: isDark,
                    txtColors: txt,
                    onTap: () {
                      final screen = option['screen'];
                      if (screen != null) {
                        navigationPush(context, screen as Widget);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${option['title']} screen coming soon!',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  );
                }, childCount: options.length),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 30.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildPollOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color iconBackgroundColor,
    required AssetGenImage image,
    required bool isDark,
    required AppTextColors txtColors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: !isDark
            ? [const BoxShadow(color: Color(0x06000000), blurRadius: 2)]
            : null,
      ),
      child: Material(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isDark
                    ? Theme.of(context).colorScheme.outline.withOpacity(0.2)
                    : const Color(0xFFF2F2F2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 5),
                  // Render custom icon
                  Container(
                    height: 65,
                    width: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconBackgroundColor,
                    ),
                    child: Center(
                      child: image.image(
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: txtColors.title,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 12.2,
                      color: txtColors.body,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
