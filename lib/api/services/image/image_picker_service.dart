// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/screens/home/new poll/type/image_preview_crop_screen.dart';
import 'gallery_config.dart';
import 'polzet_asset_picker_builder_delegate.dart';

/// Custom text delegate for wechat_assets_picker to match Polzet UI terminology.
class PolzetAssetPickerTextDelegate extends EnglishAssetPickerTextDelegate {
  const PolzetAssetPickerTextDelegate();

  @override
  String get confirm => 'Next';
}

/// Custom text delegate for wechat_camera_picker to display English text and "Take photo".
class PolzetCameraPickerTextDelegate extends EnglishCameraPickerTextDelegate {
  const PolzetCameraPickerTextDelegate();

  @override
  String get shootingTips => 'Take photo';

  @override
  String get shootingWithRecordingTips =>
      'Take photo. Long press to record video.';
}

class ImagePickerService {
  static final ImagePicker _systemPicker = ImagePicker();

  /// Picks multiple images using either the custom gallery (Debug) or
  /// system photo picker (Release).
  static Future<List<File>?> pickMultiImages({
    required BuildContext context,
    int maxImages = 2,
    bool allowCamera = true,
  }) async {
    final source = await showImageSourceDialog(
      context,
      allowCamera: allowCamera,
    );
    if (source == null) return null;

    if (source == 'camera') {
      final File? cameraFile = await _pickFromCamera(context);
      if (cameraFile != null) return [cameraFile];
      return null;
    } else {
      if (GalleryConfig.isCustomGalleryActive) {
        return await _pickMultiFromCustomGallery(context, maxImages: maxImages);
      } else {
        return await _pickMultiFromSystemPicker(context, maxImages: maxImages);
      }
    }
  }

  /// Picks a single image using either custom gallery/camera (Debug) or
  /// system picker (Release).
  static Future<File?> pickImage({
    required BuildContext context,
    bool allowCamera = true,
    bool pickOriginal = false,
  }) async {
    final source = await showImageSourceDialog(
      context,
      allowCamera: allowCamera,
    );
    if (source == null) return null;

    if (source == 'camera') {
      return await _pickFromCamera(context, pickOriginal: pickOriginal);
    } else {
      if (GalleryConfig.isCustomGalleryActive) {
        return await _pickSingleFromCustomGallery(
          context,
          pickOriginal: pickOriginal,
        );
      } else {
        return await _pickSingleFromSystemPicker(context);
      }
    }
  }

  /// Custom gallery implementation (Debug mode) using wechat_assets_picker
  static Future<List<File>?> _pickMultiFromCustomGallery(
    BuildContext context, {
    required int maxImages,
  }) async {
    final List<AssetEntity>? assets =
        await PolzetAssetPickerBuilderDelegate.pickAssets(
      context,
      maxAssets: maxImages,
    );

    if (assets != null && assets.isNotEmpty) {
      final List<File> files = [];
      for (final asset in assets) {
        final file = await asset.file;
        if (file != null) files.add(file);
      }
      if (files.isEmpty) return null;

      final List<File>? previewResult = await Navigator.push<List<File>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewCropScreen(
            initialImages: files,
            maxImages: maxImages,
          ),
        ),
      );
      return previewResult;
    }
    return null;
  }

  /// Single image pick from custom gallery (Debug mode)
  static Future<File?> _pickSingleFromCustomGallery(
    BuildContext context, {
    bool pickOriginal = false,
  }) async {
    final List<AssetEntity>? assets =
        await PolzetAssetPickerBuilderDelegate.pickAssets(
      context,
      maxAssets: 1,
    );

    if (assets != null && assets.isNotEmpty) {
      final File? file =
          await (pickOriginal ? assets.first.originFile : assets.first.file);
      if (file == null) return null;

      final List<File>? previewResult = await Navigator.push<List<File>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewCropScreen(
            initialImages: [file],
            maxImages: 1,
          ),
        ),
      );
      return (previewResult != null && previewResult.isNotEmpty)
          ? previewResult.first
          : null;
    }
    return null;
  }

  /// Camera picker: uses wechat_camera_picker in debug, image_picker in release
  static Future<File?> _pickFromCamera(
    BuildContext context, {
    bool pickOriginal = false,
  }) async {
    if (GalleryConfig.isCustomGalleryActive) {
      final AssetEntity? asset = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: const CameraPickerConfig(
          enableRecording: false,
          textDelegate: PolzetCameraPickerTextDelegate(),
        ),
      );
      if (asset != null) {
        return await (pickOriginal ? asset.originFile : asset.file);
      }
      return null;
    } else {
      final XFile? photo = await _systemPicker.pickImage(
        source: ImageSource.camera,
      );
      if (photo != null) {
        return File(photo.path);
      }
      return null;
    }
  }

  /// System photo picker implementation (Release mode for Google Play compliance)
  static Future<List<File>?> _pickMultiFromSystemPicker(
    BuildContext context, {
    required int maxImages,
  }) async {
    final List<XFile> pickedFiles = await _systemPicker.pickMultiImage(
      limit: maxImages,
    );
    if (pickedFiles.isNotEmpty) {
      final List<File> files = pickedFiles
          .take(maxImages)
          .map((xFile) => File(xFile.path))
          .toList();
      if (files.isEmpty) return null;

      final List<File>? previewResult = await Navigator.push<List<File>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewCropScreen(
            initialImages: files,
            maxImages: maxImages,
          ),
        ),
      );
      return previewResult;
    }
    return null;
  }

  /// Single image pick from system photo picker (Release mode)
  static Future<File?> _pickSingleFromSystemPicker(
    BuildContext context,
  ) async {
    final XFile? pickedFile = await _systemPicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final File file = File(pickedFile.path);

      final List<File>? previewResult = await Navigator.push<List<File>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewCropScreen(
            initialImages: [file],
            maxImages: 1,
          ),
        ),
      );
      return (previewResult != null && previewResult.isNotEmpty)
          ? previewResult.first
          : null;
    }
    return null;
  }

  /// Shows the image source selection modal (Camera / Gallery)
  static Future<String?> showImageSourceDialog(
    BuildContext context, {
    bool allowCamera = true,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (allowCamera) ...[
                    _buildSourceItem(
                      context: context,
                      icon: FeatherIcons.camera,
                      label: AppLocalizations.of(context)!.camera,
                      onTap: () => Navigator.pop(context, 'camera'),
                    ),
                    SizedBox(width: 40.w),
                  ],
                  _buildSourceItem(
                    context: context,
                    icon: FeatherIcons.image,
                    label: AppLocalizations.of(context)!.gallery,
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Image cropper preserving existing aspect ratios and styling
  static Future<File?> cropImage(
    File imageFile, {
    CropAspectRatioPreset? initAspectRatio,
  }) async {
    if (!await imageFile.exists()) return null;

    final String pathLower = imageFile.path.toLowerCase();
    final ImageCompressFormat format = pathLower.endsWith('.png')
        ? ImageCompressFormat.png
        : ImageCompressFormat.jpg;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressFormat: format,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppColors.primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: initAspectRatio ?? CropAspectRatioPreset.square,
          lockAspectRatio: false,
          activeControlsWidgetColor: AppColors.primaryColor,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio5x4,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio5x4,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }
}

Widget _buildSourceItem({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          width: 58,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryColor,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        label,
        style: AppTextStyles.subText.copyWith(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
    ],
  );
}
