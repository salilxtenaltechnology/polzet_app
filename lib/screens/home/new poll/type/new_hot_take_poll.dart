// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/app_api.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../models/poll/inspired_poll_data.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/banner/ai_generation_limit_banner.dart';
import '../../../../widgets/button/generate_question_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import '../widgets/inspired_poll_card.dart';
import '../widgets/poll_keyboard_dismiss_wrapper.dart';

class NewHotTakePoll extends StatefulWidget {
  final String? initialQuestion;
  final String? initialDescription;
  final List<String>? initialOptions;
  final String? initialVotingType;
  final InspiredPollData? inspiredData;
  final String? inspiredPostId;

  const NewHotTakePoll({
    super.key,
    this.initialQuestion,
    this.initialDescription,
    this.initialOptions,
    this.initialVotingType,
    this.inspiredData,
    this.inspiredPostId,
  });

  @override
  State<NewHotTakePoll> createState() => _NewHotTakePollState();
}

class _NewHotTakePollState extends State<NewHotTakePoll> {
  int _currentStep = 0;
  final ScrollController _scrollController = ScrollController();
  final ApiService service = ApiService();
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final FocusNode questionFocusNode = FocusNode();
  final _dio = Dio();
  bool isLoading = false;
  String questionErrorText = '';
  String categoryErrorText = '';
  File? _image;

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;
  String? _selectedCategory;

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

  @override
  void dispose() {
    _hintTimer?.cancel();
    _scrollController.dispose();
    questionController.removeListener(_onQuestionChanged);
    questionController.dispose();
    questionFocusNode.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: 1,
        allowCamera: true,
      );

      if (pickedFiles != null && pickedFiles.isNotEmpty && mounted) {
        setState(() {
          _image = pickedFiles[0];
        });
      }
    } catch (e) {
      showToast(message: 'Error picking image: ${e.toString()}');
    }
  }

  Future<void> _cropCurrentImage() async {
    if (_image == null) return;

    final croppedFile = await ImagePickerService.cropImage(_image!);
    if (croppedFile != null && mounted) {
      setState(() {
        _image = croppedFile;
      });
    }
  }

  void _onTapEditImage() {
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
                  _cropCurrentImage();
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
                    _pickImage();
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
                    _removeImage();
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

  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  bool _validateStep1() {
    setState(() {
      questionErrorText = '';
    });

    bool isValid = true;

    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteraquestionortopic;
      });
      isValid = false;
    }

    return isValid;
  }

  void _onNextStep() {
    if (_validateStep1()) {
      setState(() {
        _currentStep = 1;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  Future<void> _createHotTakePoll() async {
    setState(() {
      questionErrorText = '';
      categoryErrorText = '';
    });

    if (!_validateStep1()) {
      setState(() {
        _currentStep = 0;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      setState(() {
        categoryErrorText = AppLocalizations.of(context)!.pleaseselectcategory;
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('question', questionController.text.trim()),
        MapEntry('description', descriptionController.text.trim()),
        const MapEntry('poll_type', 'hot_take'),
        const MapEntry('voting_type', 'single_choice'),
        const MapEntry('max_options', '1'),
      ]);

      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        formData.fields.add(MapEntry('category', _selectedCategory!));
      }

      final originalPostId =
          widget.inspiredPostId ?? widget.inspiredData?.postId;
      if (originalPostId != null && originalPostId.isNotEmpty) {
        formData.fields.add(MapEntry('inspiration_id', originalPostId));
        formData.fields.add(MapEntry('inspired_by_post_id', originalPostId));
        formData.fields.add(MapEntry('parent_post_id', originalPostId));
      }

      // Add static poll_options: Agree, Disagree
      formData.fields.add(const MapEntry('poll_options', 'Agree'));
      formData.fields.add(const MapEntry('poll_options', 'Disagree'));

      // Add image if selected
      if (_image != null) {
        final String ext = path.extension(_image!.path).toLowerCase();
        final String subType = ext.startsWith('.') ? ext.substring(1) : 'jpeg';
        final multipartFile = await MultipartFile.fromFile(
          _image!.path,
          filename: path.basename(_image!.path),
          contentType: MediaType(
            'image',
            subType == 'jpg' ? 'jpeg' : (subType.isEmpty ? 'jpeg' : subType),
          ),
        );
        formData.files.add(MapEntry('images', multipartFile));
        formData.fields.add(MapEntry('image_indices', jsonEncode([0])));
      }

      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showToast(message: 'New hot take created!');
        Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
        Navigator.of(context).pop(response.data);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final errorMsg =
          e.response?.data?['message'] ?? 'Failed to create hot take';
      showToast(message: errorMsg);
    } catch (e) {
      if (!mounted) return;
      showToast(message: 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
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
          title: AppLocalizations.of(context)!.shareahottake,
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
            AiGenerationLimitBanner(remainingGenerations: _remainingGenerations),
          ],
        ),
        body: PollKeyboardDismissWrapper(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),

                // Step Indicator
                _buildStepIndicator(),
                SizedBox(height: 18.h),

                // Step 1: Poll Content
                if (_currentStep == 0) ...[
                  // Inspired Poll Card
                  if (widget.inspiredData != null) ...[
                    InspiredPollCard(inspiredData: widget.inspiredData!),
                    SizedBox(height: 15.h),
                  ],

                  Text(
                    AppLocalizations.of(
                      context,
                    )!.postboldopinionssparkdebatesandhearbothsides,
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 14,
                      color: txt.body,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.yourhottake,
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
                          onTap:
                              (_isGeneratingQuestion ||
                                  _remainingGenerations <= 0)
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
                  SizedBox(height: 20.h),
                  Text(
                    '${AppLocalizations.of(context)!.addimage} (${AppLocalizations.of(context)!.optional})',
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.title,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 7.h),
                  _buildImageSelector(context),
                  SizedBox(height: 20.h),
                  _buildReactionsSection(),
                  SizedBox(height: 20.h),
                ],

                // Step 2: Poll Details
                if (_currentStep == 1) ...[
                  _buildDescriptionField(),
                  SizedBox(height: 20.h),
                  _buildCategorySection(),
                  SizedBox(height: 20.h),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.background,
          padding: const EdgeInsets.fromLTRB(16, 5, 16, 40),
          height: 90,
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : (_currentStep == 0 ? _onNextStep : _createHotTakePoll),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                disabledBackgroundColor: const Color(0x269B3046),
                disabledForegroundColor: const Color(0xFF898989),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: Loader(color: Colors.white),
                    )
                  : Text(
                      _currentStep == 0
                          ? AppLocalizations.of(context)!.nextdetails
                          : AppLocalizations.of(context)!.addpoll,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
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

    final bool isStep1Complete = questionController.text.trim().isNotEmpty;
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
              color: isStep2Active ? AppColors.primaryColor.withOpacity(0.8) : lineColor,
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
                            color: isStep2Active
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
               AppLocalizations.of(context)!.polldetails,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 14.2,
                  fontWeight: isStep2Active ? FontWeight.w600 : FontWeight.w400,
                  color: isStep2Active
                      ? AppColors.primaryColor
                      : txt.title,
                ),
              ),
            ],
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
        Text(
          AppLocalizations.of(context)!.descriptionhashtagsoptional,
          style: AppTextStyles.bodyText.copyWith(
            color: txt.title,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: descriptionController,
          hintText: AppLocalizations.of(
            context,
          )!.typedescriptionorhashtags,
          maxLines: 5,
          minLines: 1,
          focusedBorderColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ],
    );
  }

  Widget _buildReactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.reactions,
          style: AppTextStyles.bodyText.copyWith(
            color: AppTextColors.of(context).title,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF101F1B)
                      : const Color(0xFFE2FDF1),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF19322A)
                        : const Color(0xFFD1FAE5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      Assets.images.icAgree.path,
                      height: 23,
                      width: 23,
                    ),
                    SizedBox(width: 10.w),
                    const Text(
                      'Agree',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF201315)
                      : const Color(0xFFFDE5E5),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFCB5B5B).withOpacity(0.5)
                        : const Color(0xFFFC9393).withOpacity(0.4),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      Assets.images.icDisagree.path,
                      height: 23,
                      width: 23,
                      key: const ValueKey('disagree_icon'),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'Disagree',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFE53E3E)
                            : const Color(0xFFC81E1E),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildImageSelector(BuildContext context) {
    final bool hasImage = _image != null;
    return GestureDetector(
      onTap: () {
        if (hasImage) {
          _onTapEditImage();
        } else {
          _pickImage();
        }
      },
      child: SizedBox(
        width: double.infinity,
        height: 150.h,
        child: hasImage
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 5.h,
                        right: 5.w,
                        child: GestureDetector(
                          onTap: _onTapEditImage,
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
                        height: 27.sp,
                        width: 27.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.2),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
