// ignore_for_file: deprecated_member_use, prefer_is_empty, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/button/primary_button.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/dotted_border/dotted_border.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/text_field/secondry_textfield.dart';

class PollImages extends StatefulWidget {
  const PollImages({super.key});

  @override
  State<PollImages> createState() => _PollImagesState();
}

class _PollImagesState extends State<PollImages> {
  final ApiService service = ApiService();
  final descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String descriptionErrorText = '';
  String imageErrorText = '';
  bool isLoading = false;
  bool isUploading = false;
  double uploadProgress = 0.0;

  // List to store images dynamically
  List<File?> _images = [null, null]; // Start with two null images
  static const int maxImages = 4;

  Future<void> _pickImage(int index) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _images[index] = File(pickedFile.path);
          // Clear image error when user selects an image
          if (imageErrorText.isNotEmpty) {
            imageErrorText = '';
          }
        });
      }
    } catch (e) {
      showToast(message: 'Error picking image: ${e.toString()}');
    }
  }

  void removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_images.isEmpty) {
        _images.add(null);
      }
    });
  }

  void addImageSlot() {
    if (_images.length < maxImages) {
      setState(() {
        _images.add(null);
      });
    }
  }

  String _getOptionText(BuildContext context, int index) {
    switch (index) {
      case 0:
        return AppLocalizations.of(context)!.option1;
      case 1:
        return AppLocalizations.of(context)!.option2;
      case 2:
        return AppLocalizations.of(context)!.option3;
      case 3:
        return AppLocalizations.of(context)!.option4;
      default:
        return 'Option ${index + 1}';
    }
  }

  void postImage() async {
    final accessToken = await SharedPrefService.getAccessToken();

    // Validate inputs
    if (descriptionController.text.trim().isEmpty) {
      setState(() {
        descriptionErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteraquestion;
      });
      return;
    }

    // Filter out null images
    List<File> selectedImages = _images
        .where((image) => image != null)
        .cast<File>()
        .toList();

    if (selectedImages.length < 2) {
      setState(() {
        imageErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleastoneimage;
      });
      return;
    }

    if (selectedImages.length > maxImages) {
      setState(() {
        imageErrorText = 'Maximum $maxImages images allowed';
      });
      return;
    }

    setState(() {
      isLoading = true;
      uploadProgress = 0.0;
      descriptionErrorText = '';
      imageErrorText = '';
    });

    try {
      // Upload the poll
      Map<String, dynamic>? result = await ApiService.uploadImagePoll(
        description: descriptionController.text.trim(),
        question:
            'Image Preference Poll', // You can add a question field if needed
        pollOptions: selectedImages,
        maxOptions: maxImages,
        authToken: accessToken,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              uploadProgress = progress;
            });
          }
          if (kDebugMode) {
            print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      if (result != null && mounted) {
        showToast(message: 'Poll created successfully!');
        descriptionController.clear();
        setState(() {
          _images = [null, null];
          uploadProgress = 0.0;
        });
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating poll: $e');
      }

      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        // Show user-friendly error messages
        if (errorMessage.contains('too large') ||
            errorMessage.contains('10MB')) {
          showToast(
            message: 'Image too large. Maximum size allowed is 10MB per image',
          );
        } else if (errorMessage.contains('internet') ||
            errorMessage.contains('network')) {
          showToast(message: 'Network error. Please check your connection');
        } else if (errorMessage.contains('timeout')) {
          showToast(message: 'Upload timeout. Please try again');
        } else {
          showToast(
            message: errorMessage.isEmpty
                ? 'Error uploading poll'
                : errorMessage,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.addnewpollimage,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        children: [
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.description,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: descriptionController,
            hintText: AppLocalizations.of(context)!.enteryouranswerhere,
            onChanged: (value) {
              // Clear error when user starts typing
              if (descriptionErrorText.isNotEmpty && value.trim().isNotEmpty) {
                setState(() {
                  descriptionErrorText = '';
                });
              }
            },
          ),
          if (descriptionErrorText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: Text(
                descriptionErrorText,
                style: CustomTextStyles.msgErrorText,
              ),
            ),
          SizedBox(height: 20.h),
          // Dynamic image grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 15.h,
              childAspectRatio: 0.85,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  _buildImageOption(context, index),
                  // Remove button - only show if there's more than 2 image slots
                  if (_images.length > 2)
                    Positioned(
                      top: 5.h,
                      right: 5.w,
                      child: GestureDetector(
                        onTap: () => removeImage(index),
                        child: Container(
                          width: 20.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12.sp,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          SizedBox(height: 15.h),
          // Add image button
          if (_images.length < maxImages)
            Center(
              child: TextButton.icon(
                onPressed: addImageSlot,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                ),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20.sp,
                ),
                label: Text(
                  AppLocalizations.of(context)!.addimage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (imageErrorText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5.h, bottom: 10.h),
              child: Center(
                child: Text(
                  imageErrorText,
                  style: CustomTextStyles.msgErrorText,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          SizedBox(height: 20.h),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 50.h,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.addpoll,
          onPressed: postImage,
          isLoading: isLoading,
        ),
      ),
    );
  }

  Widget _buildImageOption(BuildContext context, int index) {
    final bool hasImage = _images[index] != null;
    // Add border only to the first image (index 0)

    return GestureDetector(
      onTap: () => _pickImage(index),
      child: Container(
        decoration: BoxDecoration(
          color: hasImage
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Stack(
                  children: [
                    // Image
                    Positioned.fill(
                      child: Image.file(_images[index]!, fit: BoxFit.cover),
                    ),
                    // Option label overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8.h,
                          horizontal: 10.w,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          _getOptionText(context, index),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : CustomPaint(
                painter: DottedBorderPainter(
                  color: Theme.of(context).colorScheme.primary,
                  strokeWidth: 2,
                  gap: 5,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 40.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.6),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        _getOptionText(context, index),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }
}
