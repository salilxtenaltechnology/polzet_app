import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

mixin UtilityMixin {
  void clearStackAndAddScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  void navigationPush(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: const Duration(microseconds: 200),
        child: screen,
      ),
    );
  }

  void navigationPushReplacement(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: const Duration(microseconds: 200),
        child: screen,
      ),
    );
  }
}
