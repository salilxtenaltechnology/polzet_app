import 'package:flutter/material.dart';

import '../home/home_imports.dart';
import 'first_step_screen.dart';
import 'second_step_screen.dart';
import 'third_step_screen.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key});
  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  int _step = 0;

  void _next() {
    if (_step < 2) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _skip() => _next();

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: switch (_step) {
        0 => FirstStepScreen(
          key: const ValueKey(0),
          onContinue: _next,
          onSkip: _skip,
          onBack: _back,
        ),
        1 => SecondStepScreen(
          key: const ValueKey(1),
          onContinue: _next,
          onSkip: _skip,
          onBack: _back,
        ),
        _ => ThirdStepScreen(
          key: const ValueKey(2),
          onContinue: () {},
          onSkip: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const HomeScreen(initialIndex: 0),
              ),
              (route) => false,
            );
          },
          onBack: _back,
        ),
      },
    );
  }
}
