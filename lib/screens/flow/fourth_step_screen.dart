// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../gen/assets.gen.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../../mixin/utility_mixins.dart';
import '../home/home_imports.dart';
import '../home/new poll/type/new_anonymous_poll.dart';
import '../home/new poll/type/new_battel_poll.dart';
import '../home/new poll/type/new_hot_take_poll.dart';
import '../home/new poll/type/new_image_poll.dart';
import '../home/new poll/type/new_text_poll.dart';
import '../home/new poll/type/new_this_or_that.dart';
import 'flow_scaffold.dart';

class FourthStepScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const FourthStepScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<FourthStepScreen> createState() => _FourthStepScreenState();
}

class _FourthStepScreenState extends State<FourthStepScreen> with UtilityMixin {
  int? _selected;

  List<Map<String, dynamic>> _getPollOptions(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return [
      {
        'title': loc.textpoll,
        'subtitle': loc.asksimplequestionswithtextchoices,
        'image': Assets.images.icTextPoll,
        'screen': const NewTextPoll(),
        'iconBackgroundColor': const Color(0XFFC026D3).withOpacity(0.1),
      },
      {
        'title': loc.imagepoll,
        'subtitle': loc.comparephotosandvisualchoices,
        'image': Assets.images.icImagePoll,
        'screen': const NewImagePoll(),
        'iconBackgroundColor': const Color(0XFFDE42AA).withOpacity(0.1),
      },
      {
        'title': loc.battlepoll,
        'subtitle': loc.comparerivalsandcrownawinner,
        'image': Assets.images.icBattel,
        'screen': const NewBattelPoll(),
        'iconBackgroundColor': const Color(0XFFDC2626).withOpacity(0.1),
      },
      {
        'title': loc.thisorthat,
        'subtitle': loc.pickbetweentwoquickchoices,
        'image': Assets.images.icThisThat,
        'screen': const NewThisOrThat(),
        'iconBackgroundColor': const Color(0XFF16A34A).withOpacity(0.12),
      },
      {
        'title': loc.hottakespoll,
        'subtitle': loc.shareopinionsandstartdebates,
        'image': Assets.images.icHot,
        'screen': const NewHotTakePoll(),
        'iconBackgroundColor': const Color(0XFFEA580C).withOpacity(0.12),
      },
      {
        'title': loc.anonymouspoll,
        'subtitle': loc.gethonestopinionsprivately,
        'image': Assets.images.icAnonymous,
        'screen': const NewAnonymousPoll(),
        'iconBackgroundColor': const Color(0XFF7C3AED).withOpacity(0.12),
      },
    ];
  }

  Future<void> _openPollScreen(Widget screen) async {
    final result = await navigationPush(context, screen);
    if (result == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 0)),
        (route) => false,
      );
    }
  }

  void _onCreatePoll() {
    if (_selected == null) return;
    final options = _getPollOptions(context);
    final screen = options[_selected!]['screen'] as Widget?;
    if (screen != null) {
      _openPollScreen(screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = _getPollOptions(context);

    return FlowScaffold(
      currentStep: 4,
      totalSteps: 4,
      onBack: widget.onBack,
      title: AppLocalizations.of(context)!.createyourfirstpoll,
      subtitle: AppLocalizations.of(context)!.choosehowyouwanttoaskyourquestion,
      primaryLabel: 'Create Poll',
      onPrimary: _selected != null ? _onCreatePoll : null,
      onSkip: widget.onSkip,
      body: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: options.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 0.99,
        ),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = _selected == index;
          final AssetGenImage image = option['image'];
          final Color iconBg = option['iconBackgroundColor'];

          return GestureDetector(
            onTap: () {
              setState(() => _selected = index);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark
                          ? Theme.of(context).colorScheme.outline.withOpacity(0.2)
                          : const Color(0xFFF2F2F2)),
                  width: isSelected ? 1.2 : 1,
                ),
                boxShadow: !isDark
                    ? [
                        const BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 5),
                    Container(
                      height: 65,
                      width: 65,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconBg,
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
                      option['title'] as String,
                      style: AppTextStyles.cardTitle.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: txt.title,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option['subtitle'] as String,
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 12.2,
                        color: txt.body,
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
          );
        },
      ),
    );
  }
}
