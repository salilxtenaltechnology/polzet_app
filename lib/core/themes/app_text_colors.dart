// core/themes/app_text_colors.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppTextColors extends ThemeExtension<AppTextColors> {
  final Color heading;
  final Color title;
  final Color body;
  final Color muted;

  const AppTextColors({
    required this.heading,
    required this.title,
    required this.body,
    required this.muted,
  });

  @override
  AppTextColors copyWith({
    Color? heading,
    Color? title,
    Color? body,
    Color? muted,
  }) {
    return AppTextColors(
      heading: heading ?? this.heading,
      title:   title   ?? this.title,
      body:    body    ?? this.body,
      muted:   muted   ?? this.muted,
    );
  }

  @override
  AppTextColors lerp(AppTextColors? other, double t) {
    if (other == null) return this;
    return AppTextColors(
      heading: Color.lerp(heading, other.heading, t)!,
      title:   Color.lerp(title,   other.title,   t)!,
      body:    Color.lerp(body,    other.body,    t)!,
      muted:   Color.lerp(muted,   other.muted,   t)!,
    );
  }

  // ── Presets ──────────────────────────────────────────────────────────────

  static const light = AppTextColors(
    heading: Color(0xFF111111),
    title:   Color(0xFF2C2C2C),
    body:    Color(0xFF595959),
    muted:   Color(0xFF8E8E8E),
  );

  static final dark = AppTextColors(
    heading: const Color(0xFFF4F4F5),
    title:   const Color(0xFFD4D4D4),
    body:    const Color(0xFFBFBFBF),
    muted:   const Color(0xFFC4C4C4).withOpacity(0.7),
  );

  // ── Accessor ─────────────────────────────────────────────────────────────

  static AppTextColors of(BuildContext context) =>
      Theme.of(context).extension<AppTextColors>()!;
}