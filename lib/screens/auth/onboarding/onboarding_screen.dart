// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../core/themes/app_text_styles.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../../models/onboarding/onboarding_model.dart';
import '../social/social_login_screen.dart';
import 'onboarding_view.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _btnController;
  late final Animation<double> _btnScale;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Discover what\npeople really think',
      subtitle:
          'Explore polls, see real opinions, and stay\nupdated with what\'s trending around you.',
      illustration: Image.asset(
        Assets.images.firstOnBoard.path,
        fit: BoxFit.contain,
      ),
    ),
    OnboardingPage(
      title: 'Create\npolls in seconds',
      subtitle:
          'Ask anything and get instant opinions\nfrom real people. No complexity, just\nquick answers.',
      illustration: Image.asset(
        Assets.images.secondOnBoard.path,
        fit: BoxFit.contain,
      ),
    ),
    OnboardingPage(
      title: 'See what\'s\ntrending right now',
      subtitle:
          'Explore popular polls, share your voice,\nand join conversations happening right now.',
      illustration: Image.asset(
        Assets.images.thirdOnBoard.path,
        fit: BoxFit.contain,
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _btnScale = _btnController;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _btnController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _btnController.reverse().then((_) => _btnController.forward());
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _onGetStarted();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _onGetStarted() async {
    await SharedPrefService.setOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SocialLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isFirstPage = _currentPage == 0;
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Back button (left) + Skip button (right) ────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button — visible on pages 2 and 3
                  AnimatedOpacity(
                    opacity: isFirstPage ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: IconButton(
                      onPressed: isFirstPage ? null : _prevPage,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: const Color(0xFFA0253A),
                    ),
                  ),

                  // Skip button — visible on pages 1 and 2
                  AnimatedOpacity(
                    opacity: isLastPage ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: TextButton(
                      onPressed: isLastPage
                          ? null
                          : () => _pageController.animateToPage(
                              _pages.length - 1,
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeInOutCubic,
                            ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isLastPage
                              ? Colors.transparent
                              : Colors.transparent,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Page View (swipe disabled) ────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                // Disable swipe gesture — buttons only
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    OnboardingPageView(page: _pages[index]),
              ),
            ),

            // ── Bottom controls ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  // CTA Button
                  ScaleTransition(
                    scale: _btnScale,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA0253A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            isLastPage ? 'Get Started' : 'Next',
                            key: ValueKey(_currentPage),
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => DotIndicator(
                        isActive: i == _currentPage,
                        color: const Color(0xFFA0253A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DotIndicator extends StatelessWidget {
  final bool isActive;
  final Color color;

  const DotIndicator({super.key, required this.isActive, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}
