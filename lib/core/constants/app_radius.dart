import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  // --- RAW TOKEN VALUES ---

  /// 4px → Small elements (inputs)
  static const double small = 4.0;

  /// 8px → Buttons (and some inputs)
  static const double button = 8.0;

  /// 12px → Cards (default)
  static const double card = 12.0;

  /// 16px → Modals / large cards / bottom sheets
  static const double modal = 16.0;

  // --- PRE-BUILT BORDERRADIUS GETTERS ---

  /// 4px radius for small elements and strict inputs
  static final BorderRadius smallRadius = BorderRadius.circular(small);

  /// 8px radius for standard Buttons and flexible inputs
  static final BorderRadius buttonRadius = BorderRadius.circular(button);

  /// 12px radius for standard Cards
  static final BorderRadius cardRadius = BorderRadius.circular(card);

  /// 16px radius for Modals and Bottom Sheets
  static final BorderRadius modalRadius = BorderRadius.circular(modal);
}
