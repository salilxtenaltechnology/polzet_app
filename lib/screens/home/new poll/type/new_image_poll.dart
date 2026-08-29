// ignore_for_file: deprecated_member_use, prefer_is_empty, use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/banner/ai_generation_limit_banner.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/button/generate_question_button.dart';
import '../../../../widgets/button/generate_description_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import 'image_preview_crop_screen.dart';

class NewImagePoll extends StatefulWidget {
  const NewImagePoll({super.key});

  @override
  State<NewImagePoll> createState() => _NewImagePollState();
}

class _NewImagePollState extends State<NewImagePoll> {
  final ApiService service = ApiService();
  final questionController = TextEditingController();
  final descriptionController = TextEditingController();
  final FocusNode questionFocusNode = FocusNode();

  String questionErrorText = '';
  String imageErrorText = '';
  bool isLoading = false;
  bool isUploading = false;
  double uploadProgress = 0.0;

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;
  bool _isGeneratingDescription = false;
  bool _hasGeneratedDescription = false;
  bool _isMultiChoice = false;

  int _remainingGenerations = 8;
  int _dailyLimit = 8;

  Future<void> _loadSavedAiLimit() async {
    final limitData = await SharedPrefService.getAiLimitData();
    if (mounted) {
      setState(() {
        _remainingGenerations = limitData['remaining'] ?? 8;
        _dailyLimit = limitData['daily_limit'] ?? 8;
      });
    }
  }

  void _updateAiLimitFromResponse(Map<String, dynamic>? response) {
    if (response == null) return;
    final rawRemaining = response['remaining'] ?? response['data']?['remaining'];
    final rawLimit = response['daily_limit'] ?? response['data']?['daily_limit'];

    if (rawRemaining != null) {
      final parsedRemaining = int.tryParse(rawRemaining.toString());
      if (parsedRemaining != null && mounted) {
        setState(() {
          _remainingGenerations = parsedRemaining;
        });
      }
    } else {
      if (mounted && _remainingGenerations > 0) {
        setState(() {
          _remainingGenerations -= 1;
        });
      }
    }

    if (rawLimit != null) {
      final parsedLimit = int.tryParse(rawLimit.toString());
      if (parsedLimit != null && mounted) {
        setState(() {
          _dailyLimit = parsedLimit;
        });
      }
    }

    SharedPrefService.saveAiLimitData(
      remaining: _remainingGenerations,
      dailyLimit: _dailyLimit,
    );
  }

  // Hint animation state
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  List<String> get _hintTexts => [
    AppLocalizations.of(context)!.pleaseenteraquestion,
    AppLocalizations.of(context)!.pleaseenteratopic,
  ];

  List<File> _selectedImages = [];
  final List<TextEditingController> _labelControllers = [];
  static const int maxImages = 4;

  void _syncLabelControllers() {
    while (_labelControllers.length < _selectedImages.length) {
      final controller = TextEditingController();
      controller.addListener(_onLabelChanged);
      _labelControllers.add(controller);
    }
    while (_labelControllers.length > _selectedImages.length) {
      final controller = _labelControllers.removeLast();
      controller.removeListener(_onLabelChanged);
      controller.dispose();
    }
  }

  void _onLabelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedAiLimit();
    questionController.addListener(_onQuestionChanged);
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

  void _onQuestionChanged() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      questionErrorText = '';
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> generateQuestion() async {
    if (_remainingGenerations <= 0) {
      showToast(
        message:
            'No AI generations left today. Your credits will reset tomorrow.',
      );
      return;
    }

    final query = questionController.text.trim();

    if (query.isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(context)!.pleaseenteratopic;
      });
      return;
    }

    setState(() {
      _isGeneratingQuestion = true;
    });

    try {
      final response = await service.generateQuestion(input: query);
      debugPrint('generateQuestion response: $response');
      _updateAiLimitFromResponse(response);

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
        questionFocusNode.requestFocus();
        _onQuestionChanged();
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

  List<String> _getValidOptions() {
    final labels = _labelControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (labels.isNotEmpty) {
      return labels;
    }
    final count = _selectedImages.length;
    if (count >= 2) {
      return List.generate(count, (index) => 'Option ${index + 1}');
    }
    return ['Option 1', 'Option 2'];
  }

  /// Generate description for the poll using AI
  Future<void> generateDescription() async {
    if (_remainingGenerations <= 0) {
      showToast(
        message:
            'No AI generations left today. Your credits will reset tomorrow.',
      );
      return;
    }

    final question = questionController.text.trim();
    final options = _getValidOptions();

    if (question.isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(context)!.pleaseenteraquestion;
      });
      return;
    }

    setState(() {
      _isGeneratingDescription = true;
    });

    try {
      final descResponse = await service.generateDescription(
        question: question,
        options: options,
      );
      debugPrint('generateDescription response: $descResponse');
      _updateAiLimitFromResponse(descResponse);

      final String descriptionText =
          (descResponse["description"] ?? descResponse["data"]?["description"])
              ?.toString()
              .trim() ??
          '';

      final dynamic rawHashtags =
          descResponse['hashtags'] ?? descResponse['data']?['hashtags'];
      List<String> hashtagsList = [];
      if (rawHashtags is List) {
        hashtagsList = rawHashtags
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (rawHashtags is String) {
        hashtagsList = rawHashtags
            .split(RegExp(r'[\s,]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      String fullText = descriptionText;
      if (hashtagsList.isNotEmpty) {
        final formattedHashtags = hashtagsList
            .map((h) => h.startsWith('#') ? h : '#$h')
            .join(' ');
        if (fullText.isNotEmpty) {
          fullText = '$fullText\n\n$formattedHashtags';
        } else {
          fullText = formattedHashtags;
        }
      }

      if (fullText.isNotEmpty) {
        setState(() {
          descriptionController.text = fullText;
          descriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: descriptionController.text.length),
          );
          _hasGeneratedDescription = true;
        });
        showToast(message: 'Description generated!');
      } else {
        showToast(
          message:
              descResponse['message']?.toString() ??
              'Failed to generate description',
        );
      }
    } catch (e) {
      debugPrint('generateDescription error: $e');
      showToast(message: e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingDescription = false;
        });
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final int remaining = maxImages - _selectedImages.length;
      if (remaining <= 0) return;

      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: remaining,
        allowCamera: true,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty && mounted) {
        final List<File>? finalFiles = await Navigator.push<List<File>>(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewCropScreen(initialImages: pickedFiles),
          ),
        );

        if (finalFiles != null && finalFiles.isNotEmpty && mounted) {
          setState(() {
            _selectedImages.addAll(finalFiles);
            if (_selectedImages.length > maxImages) {
              _selectedImages = _selectedImages.sublist(0, maxImages);
            }
            _syncLabelControllers();
            if (imageErrorText.isNotEmpty) {
              imageErrorText = '';
            }
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error picking images: ${e.toString()}');
    }
  }

  Future<void> _openPreviewCropScreen([int startIndex = 0]) async {
    if (_selectedImages.isEmpty) return;

    final List<File>? finalFiles = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewCropScreen(initialImages: _selectedImages),
      ),
    );

    if (finalFiles != null && finalFiles.isNotEmpty && mounted) {
      setState(() {
        _selectedImages = finalFiles;
        _syncLabelControllers();
        if (imageErrorText.isNotEmpty) {
          imageErrorText = '';
        }
      });
    }
  }

  void _onTapEditImage(int index) {
    final txt = AppTextColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal),
        ),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Edit Image',
                    style: AppTextStyles.sectionHeading.copyWith(
                      color: txt.title,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
                height: 1,
                endIndent: 12,
                indent: 12,
              ),
              SizedBox(height: 5.h),
              GestureDetector(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10),
                  child: Text(
                    'Crop image',
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.body,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _cropSingleImage(index);
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10),
                child: GestureDetector(
                  child: Text(
                    'Replace image',
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.body,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _replaceSingleImage(index);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10),
                child: GestureDetector(
                  child: Text(
                    'Remove',
                    style: AppTextStyles.bodyText.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeImage(index);
                  },
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cropSingleImage(int index) async {
    if (index < 0 || index >= _selectedImages.length) return;

    final croppedFile = await ImagePickerService.cropImage(
      _selectedImages[index],
    );
    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImages[index] = croppedFile;
      });
    }
  }

  Future<void> _replaceSingleImage(int index) async {
    try {
      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: 1,
        allowCamera: true,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty && mounted) {
        final List<File>? finalFiles = await Navigator.push<List<File>>(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewCropScreen(initialImages: pickedFiles),
          ),
        );

        if (finalFiles != null && finalFiles.isNotEmpty && mounted) {
          setState(() {
            _selectedImages[index] = finalFiles[0];
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error replacing image: ${e.toString()}');
    }
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      setState(() {
        _selectedImages.removeAt(index);
        if (index < _labelControllers.length) {
          _labelControllers.removeAt(index).dispose();
        }
      });
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

    if (_selectedImages.length < 2) {
      setState(() {
        imageErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleastoneimage;
      });
      return;
    }

    if (_selectedImages.length > maxImages) {
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
      final labels = List.generate(
        _selectedImages.length,
        (i) => (i < _labelControllers.length)
            ? _labelControllers[i].text.trim()
            : '',
      );

      final response = await ApiService.uploadImagePoll(
        question: questionController.text.trim(),
        description: descriptionController.text.trim(),
        pollOptions: _selectedImages,
        labels: labels,
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

      if (response != null) {
        if (!mounted) return;
        showToast(message: 'New image poll created!');
        questionController.clear();
        descriptionController.clear();
        for (final controller in _labelControllers) {
          controller.dispose();
        }
        _labelControllers.clear();
        setState(() {
          _selectedImages.clear();
          uploadProgress = 0.0;
          _isMultiChoice = false;
        });
        // Clear cached posts so the profile screen updates immediately
        Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
        Navigator.of(context).pop(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating image poll: $e');
      }
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      showToast(message: errorMessage);
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.addnewpollimage,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        children: [
          SizedBox(height: 10.h),
          AiGenerationLimitBanner(
            remainingGenerations: _remainingGenerations,
          ),
          SizedBox(height: 15.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.question,
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              SizedBox(
                height: 30,
                child: GenerateQuestionButton(
                  isGenerating: _isGeneratingQuestion,
                  hasGenerated: _hasGeneratedQuestion,
                  isEnabled: _remainingGenerations > 0,
                  onTap: (_isGeneratingQuestion || _remainingGenerations <= 0)
                      ? null
                      : generateQuestion,
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: questionController,
            focusNode: questionFocusNode,
            hintText: _hintTexts[_currentHintIndex],
            focusedBorderColor:
                questionController.text.trim().isNotEmpty
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.descriptionhashtagsoptional,
                  style: CustomTextStyles.lblPrimaryText(context),
                ),
              ),
              SizedBox(
                height: 30,
                child: GenerateDescriptionButton(
                  isGenerating: _isGeneratingDescription,
                  hasGenerated: _hasGeneratedDescription,
                  isEnabled: _remainingGenerations > 0,
                  onTap:
                      (_isGeneratingDescription || _remainingGenerations <= 0)
                          ? null
                          : generateDescription,
                ),
              ),
            ],
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: descriptionController,
            hintText: AppLocalizations.of(context)!.typedescriptionorhashtags,
            maxLines: 5,
            minLines: 1,
            focusedBorderColor: Theme.of(context).colorScheme.onPrimary,
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.polloptions,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 10.h),
          _buildPollOptionsSection(context),
          if (imageErrorText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.h, bottom: 10.h),
              child: Center(
                child: Text(
                  imageErrorText,
                  style: CustomTextStyles.msgErrorText(context),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          SizedBox(height: 16.h),
          Text(
            AppLocalizations.of(context)!.votingmode,
            style: CustomTextStyles.lblPrimaryText(context),
          ),
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
                          AppLocalizations.of(context)!.singlechoice,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          AppLocalizations.of(context)!.voterspickoneoption,
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
                          AppLocalizations.of(context)!.multiplechoice,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: txt.title,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          AppLocalizations.of(context)!.votersrankalloptions,
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

  Widget _buildPollOptionsSection(BuildContext context) {
    final txt = AppTextColors.of(context);

    if (_selectedImages.isEmpty) {
      // Empty state - Screenshot 1
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: SizedBox(
              width: double.infinity,
              height: 150.h,
              child: CustomPaint(
                painter: DottedBorderPainter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.5),
                  strokeWidth: 1.5,
                  gap: 5,
                ),
                child: Center(
                  child: Assets.images.addImage.image(
                    height: 25.sp,
                    width: 25.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.2),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            AppLocalizations.of(
              context,
            )!.addtwoorfoursimilarimagesegoutfitsplacesfood,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.muted,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(
                Icons.add,
                size: 18,
                color: AppColors.primaryColor,
              ),
              label: Text(
                AppLocalizations.of(context)!.addoption,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5,
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
        ],
      );
    } else {
      // Selected images grid - Screenshot 2
      final rows = <List<int>>[];
      for (var i = 0; i < _selectedImages.length; i += 2) {
        rows.add([i, if (i + 1 < _selectedImages.length) i + 1]);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows.map((row) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      ...row.map((i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i % 2 == 0 ? 6.w : 0,
                              left: i % 2 == 1 ? 6.w : 0,
                            ),
                            child: GestureDetector(
                              onTap: () => _openPreviewCropScreen(i),
                              child: AspectRatio(
                                aspectRatio: 1.4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.button,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.file(
                                          _selectedImages[i],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 5.h,
                                        right: 5.w,
                                        child: GestureDetector(
                                          onTap: () => _onTapEditImage(i),
                                          child: Container(
                                            width: 22.w,
                                            height: 22.h,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.edit,
                                              color: Colors.white,
                                              size: 12.sp,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (row.length == 1) const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
                Padding(
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
                            child: _buildLabelField(context, i),
                          ),
                        );
                      }),
                      if (row.length == 1) const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ],
            );
          }),
          if (_selectedImages.length < maxImages) ...[
            SizedBox(height: 4.h),
            Text(
              'Add 2-4 similar images (e.g. outfits, places, food)',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 11.5.sp,
                color: txt.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(
                  Icons.add,
                  size: 18,
                  color: AppColors.primaryColor,
                ),
                label: Text(
                  'Add Option',
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
          ],
        ],
      );
    }
  }

  Widget _buildLabelField(BuildContext context, int index) {
    if (index >= _labelControllers.length) return const SizedBox();
    return SecondryTextfield(
      controller: _labelControllers[index],
      hintText: 'Add label',
      focusedBorderColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    questionController.removeListener(_onQuestionChanged);
    questionController.dispose();
    questionFocusNode.dispose();
    descriptionController.dispose();
    for (final controller in _labelControllers) {
      controller.removeListener(_onLabelChanged);
      controller.dispose();
    }
    super.dispose();
  }
}
