import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import '../../../core/constants/app_colors.dart';

class ImagePickerService {
  static Future<File?> pickImage({
    required BuildContext context,
    bool allowCamera = true,
  }) async {
    final source = await _showImageSourceDialog(context, allowCamera);
    if (source == null) return null;

    if (source == 'camera') {
      return await _pickFromCamera(context);
    } else {
      return await _pickFromGallery(context);
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
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowCamera)
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryColor,
                  ),
                  title:const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primaryColor,
                ),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<File?> _pickFromCamera(BuildContext context) async {
    final AssetEntity? asset = await CameraPicker.pickFromCamera(
      context,
      pickerConfig:const CameraPickerConfig(enableRecording: false),
    );
    return await asset?.file;
  }

  static Future<File?> _pickFromGallery(BuildContext context) async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        textDelegate:  EnglishAssetPickerTextDelegate(),
      ),
    );
    if (assets != null && assets.isNotEmpty) {
      return await assets.first.file;
    }
    return null;
  }

  static Future<File?> cropImage(File imageFile) async {
    if (!await imageFile.exists()) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppColors.primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          activeControlsWidgetColor: AppColors.primaryColor,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }
    return null;
  }
}
