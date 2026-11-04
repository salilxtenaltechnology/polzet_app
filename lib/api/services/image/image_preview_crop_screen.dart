// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';

import '../../../core/constants/app_radius.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../widgets/button/back_button.dart';
import 'image_picker_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

class ImagePreviewCropScreen extends StatefulWidget {
  final List<File> initialImages;
  final int initialIndex;
  final int maxImages;

  const ImagePreviewCropScreen({
    super.key,
    required this.initialImages,
    this.initialIndex = 0,
    this.maxImages = 4,
  });

  @override
  State<ImagePreviewCropScreen> createState() => _ImagePreviewCropScreenState();
}

class _ImagePreviewCropScreenState extends State<ImagePreviewCropScreen> {
  late List<File> _images;
  int _currentIndex = 0;
  int _updateTick = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _images = List<File>.from(widget.initialImages);
    _currentIndex =
        (widget.initialIndex >= 0 && widget.initialIndex < _images.length)
        ? widget.initialIndex
        : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cropCurrentImage() async {
    if (_currentIndex < 0 || _currentIndex >= _images.length) return;

    final targetFile = _images[_currentIndex];
    final croppedFile = await ImagePickerService.cropImage(targetFile);

    if (croppedFile != null && mounted) {
      setState(() {
        _images[_currentIndex] = croppedFile;
        _updateTick++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 45.w,
        leading: Padding(
          padding: EdgeInsets.only(left: 8.w),
          child: PrimaryBackButton(onTap: () => Navigator.pop(context)),
        ),
        title: Text(
         AppLocalizations.of(context)!.preview,
          style: AppTextStyles.pageTitleTextStyle(context).copyWith(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        titleSpacing: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.crop, size: 22, color: txt.body),
            onPressed: _cropCurrentImage,
          ),
          SizedBox(width: 5.w),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Carousel Preview Area
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Main Rounded Preview Card
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Theme.of(context).colorScheme.background,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _images.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Image.file(
                                _images[index],
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                key: ValueKey(
                                  '${_images[index].path}_${index}_$_updateTick',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Left Chevron Button
                    if (_currentIndex > 0)
                      Positioned(
                        left: 14.w,
                        child: GestureDetector(
                          onTap: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 42.w,
                            height: 42.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A1E24),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Right Chevron Button
                    if (_currentIndex < _images.length - 1)
                      Positioned(
                        right: 14.w,
                        child: GestureDetector(
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 42.w,
                            height: 42.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A1E24),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Circular Dots Indicator
                    if (_images.length > 1)
                      Positioned(
                        bottom: 16.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_images.length, (idx) {
                            final bool isActive = idx == _currentIndex;
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.15)
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Next Button
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 42.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _images),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.next,
                    style: AppTextStyles.bodyText.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
