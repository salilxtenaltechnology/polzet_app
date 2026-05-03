import 'package:flutter/material.dart';

import '../../../../models/onboarding/onboarding_model.dart';

class IllustrationPlaceholder extends StatelessWidget {
  final OnboardingPage page;

  const IllustrationPlaceholder({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: page.illustration,
    );
  }
}