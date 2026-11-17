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
import '../../../../api/services/image/image_preview_crop_screen.dart';
import '../../../../models/poll/inspired_poll_data.dart';
import '../widgets/inspired_poll_card.dart';
import '../widgets/poll_keyboard_dismiss_wrapper.dart';

class NewImagePoll extends StatefulWidget {
  final String? initialQuestion;
  final String? initialDescription;
  final List<String>? initialOptions;
  final String? initialVotingType;
  final InspiredPollData? inspiredData;
  final String? inspiredPostId;

  const NewImagePoll({
    super.key,
    this.initialQuestion,
    this.initialDescription,
    this.initialOptions,
    this.initialVotingType,
    this.inspiredData,
    this.inspiredPostId,
  });

  @override
  State<NewImagePoll> createState() => _NewImagePollState();
}

class _NewImagePollState extends State<NewImagePoll> {
  int _currentStep = 0;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Movies', 'image': Assets.images.icMovie.path},
    {'name': 'Sports', 'image': Assets.images.icSports.path},
    {'name': 'Technology', 'image': Assets.images.icTechnology.path},
    {'name': 'AI & Tech', 'image': Assets.images.icTech.path},
    {'name': 'Gaming', 'image': Assets.images.icGame.path},
    {'name': 'Travel', 'image': Assets.images.icTravel.path},
    {'name': 'Music', 'image': Assets.images.icMusic.path},
    {'name': 'Memes', 'image': Assets.images.icMeme.path},
    {'name': 'Fitness', 'image': Assets.images.icFiteness.path},
    {'name': 'Fashion', 'image': Assets.images.icFashion.path},
    {'name': 'Food', 'image': Assets.images.icFood.path},
    {'name': 'Education', 'image': Assets.images.icBook.path},
    {'name': 'Finance', 'image': Assets.images.icFinance.path},
    {'name': 'Relationships', 'image': Assets.images.icRelationships.path},
    {'name': 'Current Affairs', 'image': Assets.images.icCurrentAffairs.path},
  ];

  final ApiService service = ApiService();
  final questionController = TextEditingController();
  final descriptionController = TextEditingController();
  final FocusNode questionFocusNode = FocusNode();

  String questionErrorText = '';
  String imageErrorText = '';
  String categoryErrorText = '';
  bool isLoading = false;
  bool isUploading = false;
  double uploadProgress = 0.0;

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;
  bool _isGeneratingDescription = false;
  bool _hasGeneratedDescription = false;
  bool _isMultiChoice = false;
  String? _selectedCategory;

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
    final rawRemaining =
        response['remaining'] ?? response['data']?['remaining'];
    final rawLimit =
        response['daily_limit'] ?? response['data']?['daily_limit'];

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
      final index = _labelControllers.length;
      final initialText =
          (widget.initialOptions != null &&
              index < widget.initialOptions!.length)
          ? widget.initialOptions![index]
          : '';
      final controller = TextEditingController(text: initialText);
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
    if (widget.initialQuestion != null &&
        widget.initialQuestion!.trim().isNotEmpty) {
      questionController.text = widget.initialQuestion!;
    }
    if (widget.initialDescription != null &&
        widget.initialDescription!.trim().isNotEmpty) {
      descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialVotingType != null &&
        widget.initialVotingType!.trim().isNotEmpty) {
      final v = widget.initialVotingType!.trim().toLowerCase();
      _isMultiChoice = v.contains('rank') || v.contains('multi');
    }
    _loadSavedAiLimit();
    questionController.addListener(_onQuestionChanged);
    _startHintAnimation();

    final hasAutoFilled =
        (widget.initialQuestion != null &&
            widget.initialQuestion!.trim().isNotEmpty) ||
        (widget.initialOptions != null && widget.initialOptions!.isNotEmpty) ||
        (widget.initialVotingType != null &&
            widget.initialVotingType!.trim().isNotEmpty);
    if (hasAutoFilled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showToast(message: 'Poll auto-filled! Review & publish');
      });
    }
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
        questionErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteraquestionortopic;
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
        setState(() {
          _selectedImages.addAll(pickedFiles);
          if (_selectedImages.length > maxImages) {
            _selectedImages = _selectedImages.sublist(0, maxImages);
          }
          _syncLabelControllers();
          if (imageErrorText.isNotEmpty) {
            imageErrorText = '';
          }
        });
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
        builder: (_) => ImagePreviewCropScreen(
          initialImages: _selectedImages,
          initialIndex: startIndex,
          maxImages: maxImages,
        ),
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
                    AppLocalizations.of(context)!.editimage,
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
                    AppLocalizations.of(context)!.cropimage,
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
                    AppLocalizations.of(context)!.replaceimage,
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
                    AppLocalizations.of(context)!.remove,
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
        setState(() {
          _selectedImages[index] = pickedFiles[0];
        });
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

  void _onNextStep() {
    setState(() {
      questionErrorText = '';
      imageErrorText = '';
    });

    bool isValid = true;

    // Validate question
    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteraquestionortopic;
      });
      isValid = false;
    }

    // Validate images
    if (_selectedImages.length < 2) {
      setState(() {
        imageErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleastoneimage;
      });
      isValid = false;
    } else if (_selectedImages.length > maxImages) {
      setState(() {
        imageErrorText = 'Maximum $maxImages images allowed';
      });
      isValid = false;
    }

    if (isValid) {
      setState(() {
        _currentStep = 1;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  void addImagePoll() async {
    final accessToken = await SharedPrefService.getToken();

    // Validate inputs
    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteraquestionortopic;
        _currentStep = 0;
      });
      return;
    }

    if (_selectedImages.length < 2) {
      setState(() {
        imageErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleastoneimage;
        _currentStep = 0;
      });
      return;
    }

    if (_selectedImages.length > maxImages) {
      setState(() {
        imageErrorText = 'Maximum $maxImages images allowed';
        _currentStep = 0;
      });
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      setState(() {
        categoryErrorText = 'Please select category';
      });
      return;
    }

    setState(() {
      isLoading = true;
      uploadProgress = 0.0;
      questionErrorText = '';
      imageErrorText = '';
      categoryErrorText = '';
    });

    try {
      final originalPostId =
          widget.inspiredPostId ?? widget.inspiredData?.postId;

      final labels = List.generate(
        _selectedImages.length,
        (i) => (i < _labelControllers.length)
            ? _labelControllers[i].text.trim()
            : '',
      );

      final response = await ApiService.addImagePoll(
        question: questionController.text.trim(),
        description: descriptionController.text.trim(),
        pollOptions: _selectedImages,
        labels: labels,
        maxOptions: maxImages,
        votingType: _isMultiChoice ? "ranking" : "single_choice",
        category: _selectedCategory,
        inspiration_id: originalPostId,
        inspired_by_post_id: originalPostId,
        parent_post_id: originalPostId,
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
          _selectedCategory = null;
          categoryErrorText = '';
          _currentStep = 0;
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
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentStep > 0) {
          setState(() => _currentStep = 0);
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title: AppLocalizations.of(context)!.addnewpollimage,
          onBack: () {
            if (_currentStep > 0) {
              setState(() => _currentStep = 0);
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0.0);
              }
            } else {
              Navigator.of(context).pop();
            }
          },
          actions: [
            // AI Generation Limit Banner
            AiGenerationLimitBanner(remainingGenerations: _remainingGenerations),
          ],
        ),
        body: PollKeyboardDismissWrapper(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),

                // Steps UI
                _buildStepIndicator(),
                SizedBox(height: 18.h),

                // Step 1: Poll Content
                if (_currentStep == 0) ...[
                  // Inspired Poll Card
                  if (widget.inspiredData != null) ...[
                    InspiredPollCard(inspiredData: widget.inspiredData!),
                    SizedBox(height: 15.h),
                  ],

                  // Question Field
                  _buildQuestionField(),
                  SizedBox(height: 20.h),

                  // Poll Options (Images)
                  Text(
                    AppLocalizations.of(context)!.polloptions,
                    style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontSize: 14, 
                fontWeight: FontWeight.w500,
              ),
                  ),
                  SizedBox(height: 10.h),
                  _buildPollOptionsSection(context),
                  if (imageErrorText.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h, bottom: 10.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            imageErrorText,
                            style: CustomTextStyles.msgErrorText(context),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 20.h),

                  // Voting Mode (New UI)
                  _buildVotingModeSection(),
                  SizedBox(height: 20.h),
                ],

                // Step 2: Poll Details
                if (_currentStep == 1) ...[
                  // Description Field
                  _buildDescriptionField(),
                  SizedBox(height: 20.h),

                  // Category Section
                  _buildCategorySection(),
                  SizedBox(height: 20.h),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          padding: const EdgeInsets.only(bottom: 20),
          height: 70.h,
          color: Theme.of(context).colorScheme.background,
          child: PrimaryButton(
            title: _currentStep == 0
                ? AppLocalizations.of(context)!.nextdetails
                : AppLocalizations.of(context)!.addpoll,
            onPressed: isLoading
                ? null
                : (_currentStep == 0 ? _onNextStep : addImagePoll),
            isLoading: isLoading,
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final lineColor =
        isDarkMode ? const Color(0xFF383840) : const Color(0xFFD9D9D9);
    final txt = AppTextColors.of(context);

    final bool isStep1Active = _currentStep == 0;
    final bool isStep2Active = _currentStep == 1;

    final bool isStep1Complete =
        questionController.text.trim().isNotEmpty &&
        _selectedImages.length >= 2 &&
        _selectedImages.length <= maxImages;
    final bool isStep2Complete =
        _selectedCategory != null && _selectedCategory!.trim().isNotEmpty;

    return Row(
      children: [
        // Step 1: Poll Content
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_currentStep > 0) {
              setState(() => _currentStep = 0);
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0.0);
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: isStep1Complete || isStep1Active || _currentStep > 0
                      ? AppColors.primaryColor
                      : txt.title.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isStep1Complete
                      ? const Icon(Icons.check, size: 17, color: Colors.white)
                      : Text(
                          '1',
                          style: TextStyle(
                            color: isStep1Active || _currentStep > 0
                                ? Colors.white
                                : txt.title,
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                AppLocalizations.of(context)!.pollcontent,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),

        // Connecting Line
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 14.w),
            height: 2,
            decoration: BoxDecoration(
              color: isStep2Active
                  ? AppColors.primaryColor.withOpacity(0.8)
                  : lineColor,
              borderRadius: BorderRadius.circular(1.0),
            ),
          ),
        ),

        // Step 2: Poll Details
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_currentStep == 0) {
              _onNextStep();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: isStep2Complete || isStep2Active
                      ? AppColors.primaryColor
                      : txt.title.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isStep2Complete
                      ? const Icon(Icons.check, size: 17, color: Colors.white)
                      : Text(
                          '2',
                          style: TextStyle(
                            color: isStep2Active ? Colors.white : txt.title,
                            fontSize: 13.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                AppLocalizations.of(context)!.polldetails,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.2,
                  fontWeight: isStep2Active ? FontWeight.w600 : FontWeight.w400,
                  color: isStep2Active ? AppColors.primaryColor : txt.title,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionField() {
    final txt = AppTextColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.question,
              style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontSize: 14, 
                fontWeight: FontWeight.w500,
              ),
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
          focusedBorderColor: questionController.text.trim().isNotEmpty
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
      ],
    );
  }

  Widget _buildDescriptionField() {
    final txt = AppTextColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.descriptionhashtagsoptional,
               style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontSize: 14, 
                fontWeight: FontWeight.w500,
              ),
              ),
            ),
            SizedBox(
              height: 30,
              child: GenerateDescriptionButton(
                isGenerating: _isGeneratingDescription,
                hasGenerated: _hasGeneratedDescription,
                isEnabled: _remainingGenerations > 0,
                onTap: (_isGeneratingDescription || _remainingGenerations <= 0)
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
      ],
    );
  }

  Widget _buildVotingModeSection() {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedBorderColor =
        isDarkMode ? Colors.white54 : const Color(0xFF595959);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.howshouldpeoplevote,
          style: AppTextStyles.bodyText.copyWith(
            color: txt.title,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
         Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_isMultiChoice) {
                  setState(() {
                    _isMultiChoice = false;
                  });
                }
              },
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRadioIndicator(
                    isSelected: !_isMultiChoice,
                    primaryColor: primaryColor,
                    unselectedBorderColor: unselectedBorderColor,
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1), 
                    child: Text(
                    AppLocalizations.of(context)!.chooseone,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight:
                            !_isMultiChoice ? FontWeight.w600 : FontWeight.w400,
                        color: txt.heading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 32.w),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!_isMultiChoice) {
                  setState(() {
                    _isMultiChoice = true;
                  });
                }
              },
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRadioIndicator(
                    isSelected: _isMultiChoice,
                    primaryColor: primaryColor,
                    unselectedBorderColor: unselectedBorderColor,
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1), 
                    child: Text(
                     AppLocalizations.of(context)!.rankoptions,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight:
                            _isMultiChoice ? FontWeight.w600 : FontWeight.w400,
                        color: txt.heading,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

 Widget _buildRadioIndicator({
    required bool isSelected,
    required Color primaryColor,
    required Color unselectedBorderColor,
  }) {
    final txt = AppTextColors.of(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? primaryColor : txt.body,
          width: 1.2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                ),
              ),
            )
          : null,
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
              icon: Icon(
                Icons.add,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimary,
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
              AppLocalizations.of(
                context,
              )!.addtwoorfoursimilarimagesegoutfitsplacesfood,
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
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  AppLocalizations.of(context)!.addoption,
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
      hintText: AppLocalizations.of(context)!.addlabel,
      focusedBorderColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  Widget _buildCategoryField() {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final midpoint = (_categories.length / 2).ceil();
    final firstLayer = _categories.sublist(0, midpoint);
    final secondLayer = _categories.sublist(midpoint);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF222222) : const Color(0xFFDDDDDD),
          width: isDarkMode ? 1.3 : 1,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: firstLayer
                  .map((cat) => _buildCategoryChip(cat, txt, isDarkMode))
                  .toList(),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: secondLayer
                  .map((cat) => _buildCategoryChip(cat, txt, isDarkMode))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    Map<String, dynamic> cat,
    AppTextColors txt,
    bool isDarkMode,
  ) {
    final isSelected = _selectedCategory == cat['name'];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          if (_selectedCategory == cat['name']) {
            _selectedCategory = null;
          } else {
            _selectedCategory = cat['name'] as String;
            if (categoryErrorText.isNotEmpty) {
              categoryErrorText = '';
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : (isDarkMode
                      ? Colors.white.withOpacity(0.12)
                      : const Color(0xFFDDDDDD)),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              cat['image'] as String,
              width: 18,
              height: 18,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
            ),
            SizedBox(width: 6.w),
            Text(
              cat['name'] as String,
              style: AppTextStyles.bodyText.copyWith(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onBackground,
                fontSize: 12.7,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final txt = AppTextColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.category,
          style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontSize: 14, 
                fontWeight: FontWeight.w500,
              ),
        ),
        SizedBox(height: 10.h),
        _buildCategoryField(),
        if (categoryErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: Text(
              categoryErrorText,
              style: CustomTextStyles.msgErrorText(context),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _scrollController.dispose();
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
