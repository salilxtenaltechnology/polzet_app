// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../gen/assets.gen.dart';

class ProfileAvatarPicker extends StatelessWidget {
  final Uint8List? cachedImage;
  final File? selectedImage;
  final bool isUploading;
  final VoidCallback onTap;
  final bool isCoverPhoto;

  const ProfileAvatarPicker({
    super.key,
    required this.cachedImage,
    required this.selectedImage,
    required this.isUploading,
    required this.onTap,
    this.isCoverPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: isCoverPhoto ? 180.h : 100.h,
          width: isCoverPhoto ? double.infinity : 100.w,
          decoration: BoxDecoration(
            shape: isCoverPhoto ? BoxShape.rectangle : BoxShape.circle,
            border: isCoverPhoto
                ? null
                : Border.all(color: AppColors.primaryColor),
            image: _getImage(),
          ),
        ),
        if (isUploading) _buildLoadingOverlay(),
        _buildCameraButton(context),
      ],
    );
  }

  DecorationImage? _getImage() {
    if (selectedImage != null) {
      return DecorationImage(
        image: FileImage(selectedImage!),
        fit: BoxFit.cover,
      );
    }
    if (cachedImage != null) {
      return DecorationImage(
        image: MemoryImage(cachedImage!),
        fit: BoxFit.cover,
      );
    }
    return DecorationImage(
      image: AssetImage(
        isCoverPhoto
            ? Assets.images.defaultCover.path
            : Assets.images.icUser.path,
      ),
      fit: BoxFit.cover,
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraButton(BuildContext context) {
    return Positioned(
      right: isCoverPhoto ? 7.w : 8.w,
      bottom: isCoverPhoto ? 7.h : 12.h,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: isCoverPhoto ? 25.h : 22.h,
          width: isCoverPhoto ? 25.w : 22.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCoverPhoto ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
          ),
          child: Icon(
            FeatherIcons.camera,
            color: isCoverPhoto ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onPrimary,
            size: 13.spMax,
          ),
        ),
      ),
    );
  }
}
