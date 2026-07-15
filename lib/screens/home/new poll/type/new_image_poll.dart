// ignore_for_file: deprecated_member_use, prefer_is_empty, use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:provider/provider.dart';
import '../../../../provider/user_provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

class NewImagePoll extends StatefulWidget {
  const NewImagePoll({super.key});

  @override
  State<NewImagePoll> createState() => _NewImagePollState();
}

class _NewImagePollState extends State<NewImagePoll> {
  final ApiService service = ApiService();
  final questionController = TextEditingController();
  final descriptionController = TextEditingController();

  String questionErrorText = '';
  String imageErrorText = '';
  bool isLoading = false;
  bool isUploading = false;
  double uploadProgress = 0.0;

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;
  bool _isMultiChoice = false;

  // Hint animation state
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  final List<String> _hintTexts = [
    'Please enter a question',
    'Please enter a topic',
  ];

  List<File?> _images = [null, null];
  static const int maxImages = 4;

  @override
  void initState() {
    super.initState();
    questionController.addListener(_clearQuestionError);
    _startHintAnimation();
  }

  void _startHintAnimation() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hintTexts.length;
        });
      }
    });
  }

  void _clearQuestionError() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      setState(() {
        questionErrorText = '';
      });
    }
  }

  Future<void> generateQuestion() async {
    final query = questionController.text.trim();

    if (query.isEmpty) {
      setState(() {
        questionErrorText = 'Please enter a topic';
      });
      return;
    }

    setState(() {
      _isGeneratingQuestion = true;
    });

    try {
      final response = await service.generateQuestion(input: query);
      debugPrint('generateQuestion response: $response');
      final questionText = response['question']?.toString();
      if (questionText != null && questionText.trim().isNotEmpty) {
        setState(() {
          questionController.text = questionText;
          // Move cursor to the end
          questionController.selection = TextSelection.fromPosition(
            TextPosition(offset: questionController.text.length),
          );
          _hasGeneratedQuestion = true;
        });
        _clearQuestionError();
        showToast(message: 'Question generated!');
      } else {
        showToast(
          message:
              response['message']?.toString() ?? 'Failed to generate question',
        );
      }
    } catch (e) {
      debugPrint('generateQuestion error: $e');
      showToast(message: e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingQuestion = false;
        });
      }
    }
  }

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
      _images[index] = null;
    });
  }

  void removeImageSlot(int index) {
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
        questionErrorText = AppLocalizations.of(context)!.pleaseenteraquestion;
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
        question: questionController.text.trim(),
        description: descriptionController.text.trim(),
        pollOptions: selectedImages,
        maxOptions: maxImages,
        votingType: _isMultiChoice ? "ranking" : "single_choice",
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
        descriptionController.clear();
        setState(() {
          _images = [null, null];
          uploadProgress = 0.0;
          _isMultiChoice = false;
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
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.question,
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              GestureDetector(
                onTap: _isGeneratingQuestion ? null : generateQuestion,
                child: Row(
                  children: [
                    _isGeneratingQuestion
                        ? SizedBox(
                            width: 12.w,
                            height: 12.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Assets.images.icAssistant.image(
                            width: 14.w,
                            height: 14.h,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                    const SizedBox(width: 5),
                    Text(
                      _isGeneratingQuestion
                          ? 'Generating...'
                          : _hasGeneratedQuestion
                          ? 'Regenerate Question'
                          : 'Generate Question',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: questionController,
            hintText: _hintTexts[_currentHintIndex],
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
          Text(
            'Description & Hashtags (Optional)',
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: descriptionController,
            hintText: 'Type description or hashtags',
            maxLines: 5,
          minLines: 1,
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.polloptions,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
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
                            if (_images[i] != null)
                              Positioned(
                                top: 8.h,
                                right: 8.w,
                                child: GestureDetector(
                                  onTap: () => removeImage(i),
                                  child: Container(
                                    width: 18.w,
                                    height: 18.h,
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
                              )
                            else if (_images.length > 2)
                              Positioned(
                                top: 8.h,
                                right: 8.w,
                                child: GestureDetector(
                                  onTap: () => removeImageSlot(i),
                                  child: Container(
                                    width: 18.w,
                                    height: 18.h,
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
                  if (row.length == 1) const Expanded(child: SizedBox()),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.8),
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

          Text('Voting Mode', style: CustomTextStyles.lblPrimaryText(context)),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMultiChoice = false;
                    });
                  },
                  child: Container(
                    height: 85,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color.fromARGB(255, 28, 28, 28)
                          : const Color(0XFFFAF7F8).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: !_isMultiChoice
                            ? Theme.of(context).colorScheme.primary
                            : (isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0XFF9B3046).withOpacity(0.1)),
                        width: !_isMultiChoice ? 1.3 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Single Choice',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Voters pick one option',
                          style: AppTextStyles.subText.copyWith(
                            fontSize: 12,
                            color: txt.body,
                            fontWeight: FontWeight.w400,
                        ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMultiChoice = true;
                    });
                  },
                  child: Container(
                    height: 85,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color.fromARGB(255, 28, 28, 28)
                          : const Color(0XFFFAF7F8).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: _isMultiChoice
                            ? Theme.of(context).colorScheme.primary
                            : (isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : const Color(0XFF9B3046).withOpacity(0.1)),
                        width: _isMultiChoice ? 1.3 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Multiple Choice',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Voters rank all options',
                          style: AppTextStyles.subText.copyWith(
                            fontSize: 12,
                            color: txt.body,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 20),
        height: 70.h,
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
            ? Padding(
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
    _hintTimer?.cancel();
    questionController.removeListener(_clearQuestionError);
    questionController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
