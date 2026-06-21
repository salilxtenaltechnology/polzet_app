// ignore_for_file: deprecated_member_use, prefer_is_empty, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:provider/provider.dart';
import '../../../provider/user_provider.dart';

import '../../../api/services/validator/api_service.dart';
import '../../../api/services/image/image_picker_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../gen/assets.gen.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../widgets/appbar/common_appbar.dart';
import '../../../widgets/button/primary_button.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/dotted_border/dotted_border.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/dialog/custom_diolog.dart';
import '../../../widgets/text_field/secondry_textfield.dart';
import '../../../core/themes/app_text_styles.dart';

class NewImagePoll extends StatefulWidget {
  const NewImagePoll({super.key});

  @override
  State<NewImagePoll> createState() => _NewImagePollState();
}

class _NewImagePollState extends State<NewImagePoll> {
  final ApiService service = ApiService();
  final questionController = TextEditingController();


  String questionErrorText = '';
  String imageErrorText = '';
  bool isLoading = false;
  bool isUploading = false;
  double uploadProgress = 0.0;

  List<File?> _images = [null, null];
  static const int maxImages = 4;

  Future<void> _pickImage(int index) async {
    try {
      final File? pickedFile = await ImagePickerService.pickImage(
        context: context,
        allowCamera: true,
      );

      if (pickedFile != null) {
        final shouldCrop = await cropImageDiolog(context);
        if (!mounted) return;

        File finalFile = pickedFile;
        if (shouldCrop == true) {
          final croppedFile = await ImagePickerService.cropImage(pickedFile);
          if (croppedFile != null) finalFile = croppedFile;
        }

        setState(() {
          _images[index] = finalFile;
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
    final accessToken = await SharedPrefService.getToken();

    // Validate inputs
    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(
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
      questionErrorText = '';
      imageErrorText = '';
    });

    try {
      // Upload the poll
      Map<String, dynamic>? result = await ApiService.uploadImagePoll(
        description: '',
        question: questionController.text.trim(),
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
        showToast(message: 'New image poll created!');
        questionController.clear();
        setState(() {
          _images = [null, null];
          uploadProgress = 0.0;
        });
        // Clear cached posts so the profile screen updates immediately
        Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
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
    final rows = <List<int>>[];
    for (var i = 0; i < _images.length; i += 2) {
      rows.add([i, if (i + 1 < _images.length) i + 1]);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.addnewpollimage,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        children: [
          SizedBox(height: 10.h),
          Text(
            AppLocalizations.of(context)!.question,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: questionController,
            hintText: AppLocalizations.of(context)!.enteryourquestion,
            onChanged: (value) {
              if (questionErrorText.isNotEmpty && value.trim().isNotEmpty) {
                setState(() {
                  questionErrorText = '';
                });
              }
            },
          ),
          if (questionErrorText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5.h),
              child: Text(
                questionErrorText,
                style: CustomTextStyles.msgErrorText(context),
              ),
            ),
          SizedBox(height: 20.h),
          
          // Image grid (2 per row)
          ...rows.map((row) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                children: [
                  ...row.map((i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i % 2 == 0 ? 6.w : 0,
                          left: i % 2 == 1 ? 6.w : 0,
                        ),
                        child: Stack(
                          children: [
                            _buildImageOption(context, i),
                            if (_images.length > 2)
                              Positioned(
                                top: 5.h,
                                right: 5.w,
                                child: GestureDetector(
                                  onTap: () => removeImage(i),
                                  child: Container(
                                    width: 20.w,
                                    height: 20.h,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
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
                        ),
                      ),
                    );
                  }),
                  if (row.length == 1)
                    const Expanded(child: SizedBox()),
                ],
              ),
            );
          }),

          SizedBox(height: 15.h),
          if (_images.length < maxImages)
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: addImageSlot,
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  AppLocalizations.of(context)!.addimage,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
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
                  style: CustomTextStyles.msgErrorText(context),
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
        color: Theme.of(context).colorScheme.background,
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
    return GestureDetector(
      onTap: () => _pickImage(index),
      child: AspectRatio(
        aspectRatio: 1.3,

        child: hasImage
            ? CustomPaint(
              painter: DottedBorderPainter(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.4),
                strokeWidth: 1.5,
                gap: 5,
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(_images[index]!, fit: BoxFit.cover),
                        ),
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
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ),
            )
            : CustomPaint(
                painter: DottedBorderPainter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.5),
                  strokeWidth: 1.5,
                  gap: 5,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Assets.images.addImage.image(
                        height: 25.sp,
                        width: 25.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.2),
                      ),

                      SizedBox(height: 8.h),
                      Text(
                        _getOptionText(context, index),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 10.3.sp,
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
    questionController.dispose();
    super.dispose();
  }
}
