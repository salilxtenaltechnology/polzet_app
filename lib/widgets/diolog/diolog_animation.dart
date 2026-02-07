import 'package:flutter/material.dart';

// open diolog animation
void diologanimation(BuildContext context, Widget widget) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dialog',
    barrierColor: const Color(0xA2000000),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: Center(
            child: Material(color: Colors.transparent, child: widget),
          ),
        ),
      );
    },
  );
}
