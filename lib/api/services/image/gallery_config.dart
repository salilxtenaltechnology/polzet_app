
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
  /// Allows override for unit/integration testing or debugging.
  static bool? _forceMode;

  /// Set to true to force system picker, false to force custom gallery, or null for default.
  static void setForceSystemPickerForTesting(bool? forceSystemPicker) {
    _forceMode = forceSystemPicker;
  }

  /// Whether custom gallery is currently active across all build configurations (Debug, Release, Production).
  static bool get isCustomGalleryActive {
    if (_forceMode != null) {
      return !_forceMode!;
    }
    return true;
  }

  /// Active picker mode. Returns [GalleryPickerMode.customGallery] when custom gallery is active.
  static GalleryPickerMode get currentMode {
    return isCustomGalleryActive ? GalleryPickerMode.customGallery : GalleryPickerMode.systemPhotoPicker;
  }
}
