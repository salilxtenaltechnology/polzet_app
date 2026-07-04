import 'package:flutter/material.dart';

/// Compatibility layer for FeatherIcons mapping them to standard, high-performance,
/// and compiler-safe Material Icons. This completely avoids package rot and R8/ProGuard obfuscation crashes.
class FeatherIcons {
  static const IconData search = Icons.search;
  static const IconData link = Icons.link;
  static const IconData send = Icons.send;
  static const IconData camera = Icons.camera_alt_outlined;
  static const IconData image = Icons.image_outlined;
  static const IconData bell = Icons.notifications_none;
  static const IconData menu = Icons.menu;
  static const IconData moreVertical = Icons.more_vert;
  static const IconData lock = Icons.lock_outline;
  static const IconData settings = Icons.settings_outlined;
  static const IconData edit2 = Icons.edit_outlined;
  static const IconData hash = Icons.tag;
  static const IconData mapPin = Icons.location_on_outlined;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData volume2 = Icons.volume_up_outlined;
  static const IconData shield = Icons.shield_outlined;
  static const IconData eye = Icons.visibility_outlined;
  static const IconData eyeOff = Icons.visibility_off_outlined;
  static const IconData userPlus = Icons.person_add_outlined;
  static const IconData smile = Icons.sentiment_satisfied_alt;
  static const IconData share = Icons.share_outlined;
}

/// Compatibility layer for FontAwesomeIcons mapping them to standard, high-performance,
/// and compiler-safe Material Icons.
class FontAwesomeIcons {
  static const IconData whatsapp = Icons.chat_bubble_outline;
  static const IconData instagram = Icons.camera_alt_outlined;
}

/// Compatibility layer for PageTransitionType.
enum PageTransitionType {
  fade,
}

/// Compatibility layer for PageTransition that mimics the behavior using Flutter's native PageRouteBuilder.
class PageTransition<T> extends PageRouteBuilder<T> {
  final Widget child;
  final PageTransitionType type;
  final Duration duration;

  PageTransition({
    required this.child,
    required this.type,
    this.duration = const Duration(milliseconds: 200),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: duration,
        );
}
