// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../gen/assets.gen.dart';
import 'flow_scaffold.dart';
import 'image_poll_screen.dart';
import 'things_poll_screen.dart';

class ThirdStepScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const ThirdStepScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<ThirdStepScreen> createState() => _ThirdStepScreenState();
}

class _ThirdStepScreenState extends State<ThirdStepScreen> {
  int? _selected;

  void _onCreatePoll() {
    if (_selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _selected == 0 ? const ThingsPollScreen() : const ImagePollScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      currentStep: 3,
      totalSteps: 3,
      onBack: widget.onBack,
      title: 'Create your first poll',
      subtitle: 'Choose how you want to ask your question',
      primaryLabel: 'Create Poll',
      onPrimary: _selected != null ? _onCreatePoll : null,
      onSkip: widget.onSkip,
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PollTypeCard(
            assetImage: Assets.images.thingsIcon,
            label: 'Things',
            isSelected: _selected == 0,
            onTap: () => setState(() => _selected = 0),
          ),
          const SizedBox(width: 16),
          _PollTypeCard(
            assetImage: Assets.images.imageIcon,
            label: 'Image',
            isSelected: _selected == 1,
            onTap: () => setState(() => _selected = 1),
          ),
        ],
      ),
    );
  }
}

class _PollTypeCard extends StatelessWidget {
  final AssetGenImage assetImage;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PollTypeCard({
    required this.assetImage,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color.fromARGB(255, 41, 41, 41)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)
                : (isDarkMode
                      ? Theme.of(context).colorScheme.outline
                      : const Color(0xFFEFEFEF)),
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 1)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: assetImage.image(
                  width: 22,
                  height: 22,
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.85)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected
                    ? (isDarkMode ? txt.body : const Color(0xFF2C2C2C))
                    : const Color(0xFF777C87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
