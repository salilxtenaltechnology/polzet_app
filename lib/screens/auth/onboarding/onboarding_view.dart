// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';

import '../../../models/onboarding/onboarding_model.dart';
import 'placeholder/placeholder.dart';

class OnboardingPageView extends StatefulWidget {
  final OnboardingPage page;

  const OnboardingPageView({super.key, required this.page});

  @override
  State<OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends State<OnboardingPageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

    // Slight delay so animation plays after page transition
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ── Illustration area
          const Spacer(flex: 1),
          SizedBox(
            height: 250,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: IllustrationPlaceholder(page: widget.page),
                ),
              ),
            ),
          ),

          const Spacer(flex: 1),
          // ── Text content
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    widget.page.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionHeading.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: const Color(0xFF111111),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    widget.page.subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionHeading.copyWith(
                      color: const Color(0XFF595959),
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
