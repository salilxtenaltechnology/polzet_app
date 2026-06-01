// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';

class FlowScaffold extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;
  final String title;
  final String subtitle;
  final Widget body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onSkip;

  const FlowScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
     final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: onBack,
                        child:  Icon(
                          Icons.arrow_back,
                          size: 22,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                  Text(
                    'Step $currentStep of $totalSteps',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: txt.title.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onBackground,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.5,
                        color: txt.body,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    body,
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: const Color(
                          0XFF9B3046,
                        ).withOpacity(0.15),
                        disabledForegroundColor: const Color(
                          0xFF898989,
                        ).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                      ),
                      child: Text(
                        primaryLabel,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          // color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onSkip,
                    child: Text(
                      'Skip for now',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
