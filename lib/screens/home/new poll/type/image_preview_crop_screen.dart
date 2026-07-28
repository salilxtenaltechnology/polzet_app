// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../widgets/appbar/common_appbar.dart';

class ImagePreviewCropScreen extends StatefulWidget {
  final List<File> initialImages;

  const ImagePreviewCropScreen({super.key, required this.initialImages});

  @override
  State<ImagePreviewCropScreen> createState() => _ImagePreviewCropScreenState();
}

class _ImagePreviewCropScreenState extends State<ImagePreviewCropScreen> {
  late List<File> _images;
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _images = List<File>.from(widget.initialImages);
    _pageController = PageController(initialPage: 0);
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: 'Crop Image',
        actions: [
          GestureDetector(
            onTap: _cropCurrentImage,
            child: Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: Icon(
                Icons.crop,
                size: 20.sp,
                color: txt.body,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Carousel Preview
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Container(
                        width: double.infinity,
                        color: Colors.transparent,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _images.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return _RoundedImageItem(
                              key: ValueKey(_images[index].path),
                              file: _images[index],
                            );
                          },
                        ),
                      ),
                    ),

                    // Left Chevron Button
                    if (_currentIndex > 0)
                      Positioned(
                        left: 12.w,
                        child: GestureDetector(
                          onTap: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 22.sp,
                            ),
                          ),
                        ),
                      ),

                    // Right Chevron Button
                    if (_currentIndex < _images.length - 1)
                      Positioned(
                        right: 12.w,
                        child: GestureDetector(
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 22.sp,
                            ),
                          ),
                        ),
                      ),

                    // Dots indicator
                    if (_images.length > 1)
                      Positioned(
                        bottom: 16.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_images.length, (idx) {
                            final bool isActive = idx == _currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.symmetric(horizontal: 3.w),
                              height: 7.h,
                              width: isActive ? 16.w : 7.w,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 40.h,
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
                    'Next',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Colors.white,
                      fontSize: 14.sp,
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

class _RoundedImageItem extends StatefulWidget {
  final File file;

  const _RoundedImageItem({super.key, required this.file});

  @override
  State<_RoundedImageItem> createState() => _RoundedImageItemState();
}

class _RoundedImageItemState extends State<_RoundedImageItem> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _loadImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _RoundedImageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _loadImageAspectRatio();
    }
  }

  void _loadImageAspectRatio() {
    final imageStream = FileImage(widget.file).resolve(ImageConfiguration.empty);
    imageStream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _aspectRatio = info.image.width / info.image.height;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_aspectRatio == null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Image.file(
            widget.file,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _aspectRatio!,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Image.file(
            widget.file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}
