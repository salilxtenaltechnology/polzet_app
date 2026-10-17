import 'package:flutter/foundation.dart';

/// Strategy/mode for image and media picking across build configurations.
enum GalleryPickerMode {
  /// Development/Debug custom gallery using wechat_assets_picker with full
  /// device media access, folder dropdowns, 3-column grid, and rich styling.
  customGallery,

  /// Google Play Release mode using system photo picker (image_picker) without
  /// broad media permissions (no READ_MEDIA_IMAGES / READ_MEDIA_VIDEO).
  systemPhotoPicker,
}

class GalleryConfig {
  /// Allows override for unit/integration testing or debugging release mode in dev.
  static bool? _forceMode;

  /// Set to true to force system picker, false to force custom gallery, or null for default.
  /// Overrides only take effect in debug/profile builds; release builds always enforce systemPhotoPicker.
  static void setForceSystemPickerForTesting(bool? forceSystemPicker) {
    if (kReleaseMode) return;
    _forceMode = forceSystemPicker;
  }

  /// Whether custom gallery is currently active.
  /// In release mode (production Google Play builds), custom gallery is ALWAYS disabled (returns false),
  /// regardless of any testing override. Overrides are strictly confined to debug/profile builds.
  static bool get isCustomGalleryActive {
    if (kReleaseMode) {
      return false;
    }
    if (_forceMode != null) {
      return !_forceMode!;
    }
    return true;
  }

  /// Active picker mode. Always GalleryPickerMode.systemPhotoPicker in release builds.
  static GalleryPickerMode get currentMode {
    if (kReleaseMode) {
      return GalleryPickerMode.systemPhotoPicker;
    }
    return isCustomGalleryActive ? GalleryPickerMode.customGallery : GalleryPickerMode.systemPhotoPicker;
  }
}
