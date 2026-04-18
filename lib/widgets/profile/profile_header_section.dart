// lib/features/profile/widgets/profile_header_section.dart

// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:feather_icons/feather_icons.dart';

import '../../core/constants/app_colors.dart';
import '../../gen/assets.gen.dart';

class ProfileHeaderSection extends StatelessWidget {
  final Uint8List? cachedProfileImage;
  final Uint8List? cachedCoverImage;
  final File? profileImage;
  final File? coverImage;
  final bool isUploadingProfile;
  final bool isUploadingCover;
  final VoidCallback onPickProfile;
  final VoidCallback onPickCover;

  const ProfileHeaderSection({
    super.key,
    required this.cachedProfileImage,
    required this.cachedCoverImage,
    required this.profileImage,
    required this.coverImage,
    this.isUploadingProfile = false,
    this.isUploadingCover = false,
    required this.onPickProfile,
    required this.onPickCover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210.h,
      child: Stack(
        children: [
          // Cover Photo Section
          _buildCoverPhoto(context),

          // Profile Photo Section
          _buildProfilePhoto(context),
        ],
      ),
    );
  }

  Widget _buildCoverPhoto(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 180.h,
        width: double.infinity,
        decoration: BoxDecoration(image: _getCoverImageDecoration()),
        child: Stack(
          children: [
            // Loading overlay for cover photo
            if (isUploadingCover)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),

            // Camera button for cover photo
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: onPickCover,
                child: Container(
                  height: 25.h,
                  width: 25.w,
                  margin: EdgeInsets.only(bottom: 7.h, right: 7.w),
                  decoration:  BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Icon(
                    FeatherIcons.camera,
                    color: AppColors.primaryColor,
                    size: 13.spMax,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: SizedBox(
          height: 130,
          width: 130,
          child: Stack(
            children: [
              // Profile photo container
              Container(
                height: 100.h,
                width: 100.w,
                margin: EdgeInsets.only(bottom: 4.h),
                padding: const EdgeInsets.all(2).w,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryColor),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: _getProfileImageDecoration(),
                  ),
                ),
              ),

              // Camera button for profile photo
              Positioned(
                right: 8.w,
                bottom: 12.h,
                child: GestureDetector(
                  onTap: onPickProfile,
                  child: Container(
                    height: 22.h,
                    width: 22.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryColor,
                    ),
                    child: Icon(
                      FeatherIcons.camera,
                      color: Colors.white,
                      size: 13.spMax,
                    ),
                  ),
                ),
              ),

              // Loading overlay for profile photo
              if (isUploadingProfile)
                Container(
                  height: 100.h,
                  width: 100.w,
                  margin: EdgeInsets.only(bottom: 4.h),
                  padding: const EdgeInsets.all(2).w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child:  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  DecorationImage _getCoverImageDecoration() {
    if (coverImage != null) {
      return DecorationImage(image: FileImage(coverImage!), fit: BoxFit.fill);
    }

    if (cachedCoverImage != null) {
      return DecorationImage(
        image: MemoryImage(cachedCoverImage!),
        fit: BoxFit.fill,
      );
    }

    return  DecorationImage(
      image: AssetImage(Assets.images.defaultCover.path),
      fit: BoxFit.fill,
    );
  }

  DecorationImage _getProfileImageDecoration() {
    if (profileImage != null) {
      return DecorationImage(
        image: FileImage(profileImage!),
        fit: BoxFit.cover,
      );
    }

    if (cachedProfileImage != null) {
      return DecorationImage(
        image: MemoryImage(cachedProfileImage!),
        fit: BoxFit.cover,
      );
    }

    return  DecorationImage(
      image: AssetImage(Assets.images.icUser.path),
      fit: BoxFit.cover,
    );
  }
}
