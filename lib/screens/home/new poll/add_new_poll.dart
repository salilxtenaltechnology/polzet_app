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
import '../../../languages/l10n/generated/app_localizations.dart';
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

class _AddNewPollState extends State<AddNewPoll>
    with SingleTickerProviderStateMixin, UtilityMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Define poll options
  List<Map<String, dynamic>> _getPollOptions(BuildContext context) {
    return [
      {
        'title': AppLocalizations.of(context)!.textpoll,
        'subtitle': AppLocalizations.of(
          context,
        )!.asksimplequestionswithtextchoices,
        'image': Assets.images.icTextPoll,
        'screen': const NewTextPoll(),
        'iconBackgroundColor': const Color(0XFFC026D3).withOpacity(0.1),
      },
      {
        'title': AppLocalizations.of(context)!.imagepoll,
        'subtitle': AppLocalizations.of(context)!.comparephotosandvisualchoices,
        'image': Assets.images.icImagePoll,
        'screen': const NewImagePoll(),
        'iconBackgroundColor': const Color(0XFFDE42AA).withOpacity(0.1),
      },
      {
        'title': AppLocalizations.of(context)!.battlepoll,
        'subtitle': AppLocalizations.of(context)!.comparerivalsandcrownawinner,
        'image': Assets.images.icBattel,
        'screen': const NewBattelPoll(),
        'iconBackgroundColor': const Color(0XFFDC2626).withOpacity(0.1),
      },
      {
        'title': AppLocalizations.of(context)!.thisorthat,
        'subtitle': AppLocalizations.of(context)!.pickbetweentwoquickchoices,
        'image': Assets.images.icThisThat,
        'screen': const NewThisOrThat(),
        'iconBackgroundColor': const Color(0XFF16A34A).withOpacity(0.12),
      },
      {
        'title': AppLocalizations.of(context)!.hottakespoll,
        'subtitle': AppLocalizations.of(context)!.shareopinionsandstartdebates,
        'image': Assets.images.icHot,
        'screen': const NewHotTakePoll(),
        'iconBackgroundColor': const Color(0XFFEA580C).withOpacity(0.12),
      },
      {
        'title': AppLocalizations.of(context)!.anonymouspoll,
        'subtitle': AppLocalizations.of(context)!.gethonestopinionsprivately,
        'image': Assets.images.icAnonymous,
        'screen': const NewAnonymousPoll(),
        'iconBackgroundColor': const Color(0XFF7C3AED).withOpacity(0.12),
      },
      // {
      //   'title': 'AI Assistant Poll',
      //   'subtitle': 'Type a topic, let AI create your poll',
      //   'image': Assets.images.icAssistant,
      //   'screen': const NewAiAssistantPoll(),
      //   'iconBackgroundColor': Theme.of(
      //     context,
      //   ).colorScheme.primary.withOpacity(0.12),
      // },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _getPollOptions(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.createyourfirstpoll,
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
                      AppLocalizations.of(
                        context,
                      )!.choosehowyouwanttoaskyourquestion,
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
                  return _PollOptionCard(
                    index: index,
                    entranceController: _animationController,
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
}

class _PollOptionCard extends StatefulWidget {
  final int index;
  final AnimationController entranceController;
  final String title;
  final String subtitle;
  final Color iconBackgroundColor;
  final AssetGenImage image;
  final bool isDark;
  final AppTextColors txtColors;
  final VoidCallback onTap;

  const _PollOptionCard({
    required this.index,
    required this.entranceController,
    required this.title,
    required this.subtitle,
    required this.iconBackgroundColor,
    required this.image,
    required this.isDark,
    required this.txtColors,
    required this.onTap,
  });

  @override
  State<_PollOptionCard> createState() => _PollOptionCardState();
}

class _PollOptionCardState extends State<_PollOptionCard>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // Staggered entrance timing
    final double start = (widget.index * 0.08).clamp(0.0, 0.4);
    final double end = (start + 0.5).clamp(0.0, 1.0);
    _entranceAnimation = CurvedAnimation(
      parent: widget.entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entranceAnimation,
      builder: (context, child) {
        final double slideOffset = (1.0 - _entranceAnimation.value) * 35.0;
        final double entranceScale = 0.94 + (_entranceAnimation.value * 0.06);
        return Opacity(
          opacity: _entranceAnimation.value,
          child: Transform.translate(
            offset: Offset(0, slideOffset),
            child: Transform.scale(scale: entranceScale, child: child),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: !widget.isDark
                ? [
                    const BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTapDown: (_) => _pressController.forward(),
              onTapUp: (_) => _pressController.reverse(),
              onTapCancel: () => _pressController.reverse(),
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: widget.isDark
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
                          color: widget.iconBackgroundColor,
                        ),
                        child: Center(
                          child: widget.image.image(
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        widget.title,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: widget.txtColors.title,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 12.2,
                          color: widget.txtColors.body,
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
        ),
      ),
    );
  }
}
