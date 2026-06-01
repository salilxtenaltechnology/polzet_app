import 'package:flutter/material.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';

mixin UtilityMixin {
  void clearStackAndAddScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  Future<dynamic> navigationPush(BuildContext context, Widget screen) {
    return Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: const Duration(microseconds: 200),
        child: screen,
      ),
    );
  }

  Future<dynamic> navigationPushReplacement(BuildContext context, Widget screen) {
    return Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.fade,
        duration: const Duration(microseconds: 200),
        child: screen,
      ),
    );
  }
}
