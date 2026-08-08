// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../languages/l10n/generated/app_localizations.dart';

class ImagePickerService {
  static Future<List<File>?> pickMultiImages({
    required BuildContext context,
    int maxImages = 2,
    bool allowCamera = true,
  }) async {
    final source = await _showImageSourceDialog(context, allowCamera);
    if (source == null) return null;

    if (source == 'camera') {
      final File? cameraFile = await _pickFromCamera(context);
      if (cameraFile != null) return [cameraFile];
      return null;
    } else {
      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: maxImages,
          requestType: RequestType.image,
          textDelegate: const EnglishAssetPickerTextDelegate(),
        ),
      );
      if (assets != null && assets.isNotEmpty) {
        final List<File> files = [];
        for (final asset in assets) {
          final file = await asset.file;
          if (file != null) files.add(file);
        }
        return files;
      }
      return null;
    }
  }

  static Future<File?> pickImage({
    required BuildContext context,
    bool allowCamera = true,
    bool pickOriginal = false,
  }) async {
    final source = await _showImageSourceDialog(context, allowCamera);
    if (source == null) return null;

    if (source == 'camera') {
      return await _pickFromCamera(context, pickOriginal: pickOriginal);
    } else {
      return await _pickFromGallery(context, pickOriginal: pickOriginal);
    }
  }

  static Future<String?> _showImageSourceDialog(
    BuildContext context,
    bool allowCamera,
  ) async {
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
                  _buildSourceItem(
                    context: context,
                    icon: FeatherIcons.camera,
                    label: AppLocalizations.of(context)!.camera,
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                  SizedBox(width: 40.w),
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

  static Future<File?> _pickFromCamera(
    BuildContext context, {
    bool pickOriginal = false,
  }) async {
    final AssetEntity? asset = await CameraPicker.pickFromCamera(
      context,
      pickerConfig: const CameraPickerConfig(
        enableRecording: false,
        textDelegate: EnglishCameraPickerTextDelegate(),
      ),
    );
    return await (pickOriginal ? asset?.originFile : asset?.file);
  }

  static Future<File?> _pickFromGallery(
    BuildContext context, {
    bool pickOriginal = false,
  }) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        textDelegate: EnglishAssetPickerTextDelegate(),
      ),
    );
    if (assets != null && assets.isNotEmpty) {
      return await (pickOriginal ? assets.first.originFile : assets.first.file);
    }
    return null;
  }

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
