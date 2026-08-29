// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/app_api.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/banner/ai_generation_limit_banner.dart';
import '../../../../widgets/button/generate_question_button.dart';
import '../../../../widgets/button/generate_option_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import 'image_preview_crop_screen.dart';

class NewAnonymousPoll extends StatefulWidget {
  const NewAnonymousPoll({super.key});

  @override
  State<NewAnonymousPoll> createState() => _NewAnonymousPollState();
}

class _NewAnonymousPollState extends State<NewAnonymousPoll> {
  final ApiService service = ApiService();
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final FocusNode questionFocusNode = FocusNode();

  final List<TextEditingController> optionControllers = [];
  final List<File?> _images = [];
  final List<String> optionErrorTexts = [];
  static const int minOptions = 2;
  static const int maxOptions = 4;

  // API loading & validation state
  bool _isLoading = false;
  String questionErrorText = '';
  String optionsErrorText = '';

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;
  bool _isGeneratingOptions = false;
  bool _hasGeneratedOptions = false;
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

  final _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadSavedAiLimit();
    questionController.addListener(_onQuestionChanged);
    _initializeOptionFields();
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

  Future<void> generateOptions() async {
    if (_remainingGenerations <= 0) {
      showToast(
        message:
            'No AI generations left today. Your credits will reset tomorrow.',
      );
      return;
    }

    final question = questionController.text.trim();

    if (question.isEmpty) {
      setState(() {
        questionErrorText = 'Please enter a question';
      });
      return;
    }

    setState(() {
      _isGeneratingOptions = true;
    });

    try {
      final response = await service.generateOptions(input: question);
      debugPrint('generateOptions response: $response');
      _updateAiLimitFromResponse(response);

      final List<dynamic>? optionsList = response['options'];
      if (optionsList != null && optionsList.isNotEmpty) {
        setState(() {
          final count = optionsList.length.clamp(minOptions, maxOptions);

          // Ensure we have enough controllers and match arrays
          while (optionControllers.length < count) {
            _images.add(null);
            final controller = TextEditingController();
            controller.addListener(_clearOptionsError);
            optionControllers.add(controller);
            optionErrorTexts.add('');
          }

          // Dispose excess controllers and match arrays
          while (optionControllers.length > count) {
            _images.removeLast();
            final controller = optionControllers.removeLast();
            controller.removeListener(_clearOptionsError);
            controller.dispose();
            optionErrorTexts.removeLast();
          }

          // Populate options
          for (int i = 0; i < count; i++) {
            optionControllers[i].text = optionsList[i].toString();
          }

          _hasGeneratedOptions = true;
        });
        _onOptionChanged();
        showToast(message: 'Options generated!');
      } else {
        showToast(
          message:
              response['message']?.toString() ?? 'Failed to generate options',
        );
      }
    } catch (e) {
      debugPrint('generateOptions error: $e');
      showToast(message: e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingOptions = false;
        });
      }
    }
  }

  void _initializeOptionFields() {
    for (int i = 0; i < minOptions; i++) {
      _images.add(null);
      final controller = TextEditingController();
      controller.addListener(_onOptionChanged);
      optionControllers.add(controller);
      optionErrorTexts.add('');
    }
  }

  void addOptionField() {
    if (optionControllers.length < maxOptions) {
      setState(() {
        _images.add(null);
        final newController = TextEditingController();
        newController.addListener(_onOptionChanged);
        optionControllers.add(newController);
        optionErrorTexts.add('');
      });
    }
  }

  void removeOptionField(int index) {
    if (optionControllers.length > minOptions) {
      setState(() {
        _images.removeAt(index);
        optionControllers[index].removeListener(_onOptionChanged);
        optionControllers[index].dispose();
        optionControllers.removeAt(index);
        optionErrorTexts.removeAt(index);
      });
      _onOptionChanged();
    }
  }

  Future<void> _pickImage(int index) async {
    try {
      int otherSelectedCount = 0;
      for (int i = 0; i < _images.length; i++) {
        if (i != index && _images[i] != null) {
          otherSelectedCount++;
        }
      }
      final int allowedMaxImages = (maxOptions - otherSelectedCount).clamp(
        1,
        maxOptions,
      );

      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: allowedMaxImages,
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
            int currentAssignIndex = index;
            for (int k = 0; k < finalFiles.length; k++) {
              while (currentAssignIndex >= optionControllers.length &&
                  optionControllers.length < maxOptions) {
                _images.add(null);
                final newController = TextEditingController();
                newController.addListener(_onOptionChanged);
                optionControllers.add(newController);
                optionErrorTexts.add('');
              }
              if (currentAssignIndex < optionControllers.length) {
                _images[currentAssignIndex] = finalFiles[k];
                currentAssignIndex++;
              }
            }
            _clearOptionsError();
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error picking image: ${e.toString()}');
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
                    removeImage(index);
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
    if (index < 0 || index >= _images.length || _images[index] == null) return;

    final croppedFile = await ImagePickerService.cropImage(_images[index]!);
    if (croppedFile != null && mounted) {
      setState(() {
        _images[index] = croppedFile;
        _clearOptionsError();
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
            _images[index] = finalFiles[0];
            _clearOptionsError();
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error replacing image: ${e.toString()}');
    }
  }

  void removeImage(int index) {
    setState(() {
      _images[index] = null;
      _clearOptionsError();
    });
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

  bool _validateInputs() {
    bool isValid = true;

    // Validate question
    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(context)!.pleaseenteraquestion;
      });
      isValid = false;
    }

    // Reset option errors
    setState(() {
      optionsErrorText = '';
      for (int i = 0; i < optionErrorTexts.length; i++) {
        optionErrorTexts[i] = '';
      }
    });

    // Validate options
    final List<int> filledIndices = [];
    int textOnlyCount = 0;
    int imageOnlyCount = 0;
    int imageWithTextCount = 0;

    for (int i = 0; i < optionControllers.length; i++) {
      final text = optionControllers[i].text.trim();
      final hasImage = _images[i] != null;
      if (text.isNotEmpty || hasImage) {
        filledIndices.add(i);
        if (text.isNotEmpty && !hasImage) {
          textOnlyCount++;
        } else if (text.isEmpty && hasImage) {
          imageOnlyCount++;
        } else if (text.isNotEmpty && hasImage) {
          imageWithTextCount++;
        }
      }
    }

    if (filledIndices.length < minOptions) {
      setState(() {
        optionsErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleasttwooptions;
      });
      isValid = false;
      return isValid;
    }

    final hasTextOnly = textOnlyCount > 0;
    final hasImageOnly = imageOnlyCount > 0;
    final hasImageWithText = imageWithTextCount > 0;

    // We can't mix text-only options with image-based options (either image-only or image-with-text)
    if (hasTextOnly && (hasImageOnly || hasImageWithText)) {
      setState(() {
        optionsErrorText =
            'Mismatch options: Do not mix text-only and image options';
      });
      isValid = false;
    }
    // We can't mix image-only options with image-with-text options (i.e. if one image has a label, all images must have a label)
    else if (hasImageOnly && hasImageWithText) {
      setState(() {
        for (int i = 0; i < optionControllers.length; i++) {
          final text = optionControllers[i].text.trim();
          final hasImage = _images[i] != null;
          if (hasImage && text.isEmpty) {
            optionErrorTexts[i] = 'Please enter label';
          }
        }
      });
      isValid = false;
    }

    return isValid;
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

  void _onOptionChanged() {
    _clearOptionsError();
    if (mounted) {
      setState(() {});
    }
  }

  void _clearOptionsError() {
    // Clear the error for any option if the user typed text or removed the image
    setState(() {
      for (int i = 0; i < optionControllers.length; i++) {
        final text = optionControllers[i].text.trim();
        final hasImage = _images[i] != null;
        if (text.isNotEmpty || !hasImage) {
          optionErrorTexts[i] = '';
        }
      }
    });

    if (optionsErrorText.isNotEmpty) {
      final List<int> filledIndices = [];
      int textOnlyCount = 0;
      int imageOnlyCount = 0;
      int imageWithTextCount = 0;

      for (int i = 0; i < optionControllers.length; i++) {
        final text = optionControllers[i].text.trim();
        final hasImage = _images[i] != null;
        if (text.isNotEmpty || hasImage) {
          filledIndices.add(i);
          if (text.isNotEmpty && !hasImage) {
            textOnlyCount++;
          } else if (text.isEmpty && hasImage) {
            imageOnlyCount++;
          } else if (text.isNotEmpty && hasImage) {
            imageWithTextCount++;
          }
        }
      }

      if (filledIndices.length >= minOptions) {
        final hasTextOnly = textOnlyCount > 0;
        final hasImageOnly = imageOnlyCount > 0;
        final hasImageWithText = imageWithTextCount > 0;

        bool hasMismatch = false;
        if (hasTextOnly && (hasImageOnly || hasImageWithText)) {
          hasMismatch = true;
        } else if (hasImageOnly && hasImageWithText) {
          hasMismatch = true;
        }

        if (!hasMismatch) {
          setState(() {
            optionsErrorText = '';
          });
        }
      }
    }
  }

  Future<void> addPoll() async {
    // Clear previous errors
    setState(() {
      questionErrorText = '';
      optionsErrorText = '';
      for (int i = 0; i < optionErrorTexts.length; i++) {
        optionErrorTexts[i] = '';
      }
    });

    // Validate inputs
    if (!_validateInputs()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final formData = FormData();

      // Common fields
      formData.fields.addAll([
        MapEntry("question", questionController.text.trim()),
        MapEntry("description", descriptionController.text.trim()),
        const MapEntry("poll_type", "anonymous"),
        MapEntry("voting_type", _isMultiChoice ? "ranking" : "single_choice"),
        const MapEntry("is_anonymous", "true"),
      ]);

      // Identify the filled options
      final List<int> filledIndices = [];
      for (int i = 0; i < optionControllers.length; i++) {
        final text = optionControllers[i].text.trim();
        final hasImage = _images[i] != null;
        if (text.isNotEmpty || hasImage) {
          filledIndices.add(i);
        }
      }

      // Add each poll option as a separate field
      for (var index in filledIndices) {
        final optionText = optionControllers[index].text.trim();
        formData.fields.add(MapEntry('poll_options', optionText));
      }

      // Add images and their indices
      final List<int> imageIndices = [];
      int apiOptionIndex = 0;
      for (var index in filledIndices) {
        final imageFile = _images[index];
        if (imageFile != null) {
          final String ext = path.extension(imageFile.path).toLowerCase();
          final String subType = ext.startsWith('.')
              ? ext.substring(1)
              : 'jpeg';
          final multipartFile = await MultipartFile.fromFile(
            imageFile.path,
            filename: path.basename(imageFile.path),
            contentType: MediaType(
              'image',
              subType == 'jpg' ? 'jpeg' : (subType.isEmpty ? 'jpeg' : subType),
            ),
          );
          formData.files.add(MapEntry('images', multipartFile));
          imageIndices.add(apiOptionIndex);
        }
        apiOptionIndex++;
      }

      if (imageIndices.isNotEmpty) {
        formData.fields.add(
          MapEntry('image_indices', jsonEncode(imageIndices)),
        );
      }

      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      debugPrint('Response status: $formData');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        showToast(message: 'New anonymous poll created!');

        Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();

        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _handleDioError(e);
    } catch (e) {
      if (!mounted) return;
      showToast(message: 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDioError(DioException e) {
    String errorMsg;

    if (e.response != null) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorData = e.response?.data;

      switch (statusCode) {
        case 400:
          errorMsg = errorData?['message']?.toString() ?? 'Validation failed';
          break;
        case 401:
          errorMsg = 'Unauthorized. Please login again.';
          break;
        case 403:
          errorMsg = 'Access forbidden.';
          break;
        case 500:
          errorMsg = 'Server error. Please try again later.';
          break;
        default:
          errorMsg =
              errorData?['message']?.toString() ??
              'Error: ${e.response?.statusMessage}';
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      errorMsg = 'Connection timeout. Please check your internet.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      errorMsg = 'Server taking too long to respond.';
    } else {
      errorMsg = 'Connection error: ${e.message}';
    }

    showToast(message: errorMsg);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    questionController.removeListener(_onQuestionChanged);
    questionController.dispose();
    questionFocusNode.dispose();
    descriptionController.dispose();
    for (var controller in optionControllers) {
      controller.removeListener(_onOptionChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.askanonymously),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),
            AiGenerationLimitBanner(
              remainingGenerations: _remainingGenerations,
            ),
            SizedBox(height: 15.h),
            Text(
              AppLocalizations.of(
                context,
              )!.sharequestionsprivatelyandgethonestopinionsfrompeople,
              style: AppTextStyles.subText.copyWith(
                fontSize: 14,
                color: txt.body,
                fontWeight: FontWeight.w400,
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color.fromARGB(255, 28, 28, 28)
                    : const Color(0XFFFAF7F8).withOpacity(0.8),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0XFF9B3046).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FeatherIcons.eyeOff,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.yourvoterswillbehiddenonthispoll,
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 13.5,
                        color: txt.title,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildQuestionField(),
            SizedBox(height: 20.h),
            _buildDescriptionField(),
            SizedBox(height: 20.h),
            _buildOptionsSection(),
            SizedBox(height: 30.h),
          ],
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
            onPressed: _isLoading ? null : addPoll,
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
            child: _isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: Loader(color: Colors.white),
                  )
                : Text(
                    AppLocalizations.of(context)!.addpoll,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.descriptionhashtagsoptional,
          style: CustomTextStyles.lblPrimaryText(context),
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

  Widget _buildOptionsSection() {
    final txt = AppTextColors.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.polloptions,
              style: CustomTextStyles.lblPrimaryText(context),
            ),
            SizedBox(
              height: 30,
              child: GenerateOptionButton(
                isGenerating: _isGeneratingOptions,
                hasGenerated: _hasGeneratedOptions,
                isEnabled: _remainingGenerations > 0,
                onTap: (_isGeneratingOptions || _remainingGenerations <= 0)
                    ? null
                    : generateOptions,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ...List.generate(optionControllers.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_images[i] == null) {
                          _pickImage(i);
                        } else {
                          _onTapEditImage(i);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            width: 45.w,
                            height: 45.w,
                            child: _images[i] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _images[i]!,
                                      fit: BoxFit.cover,
                                      width: 45.w,
                                      height: 45.w,
                                    ),
                                  )
                                : CustomPaint(
                                    painter: DottedBorderPainter(
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.3)
                                          : const Color(
                                              0XFF9B3046,
                                            ).withOpacity(0.4),
                                      strokeWidth: 1.2,
                                      gap: 4,
                                    ),
                                    child: Center(
                                      child: Assets.images.addImage.image(
                                        height: 18.sp,
                                        width: 18.sp,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                          ),
                          if (_images[i] != null)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => _onTapEditImage(i),
                                child: Container(
                                  width: 17.w,
                                  height: 17.h,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 11.sp,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: SecondryTextfield(
                        controller: optionControllers[i],
                        hintText: _getOptionText(context, i),
                        focusedBorderColor:
                            optionControllers[i].text.trim().isNotEmpty
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Color(0xFF8E8E8E),
                          ),
                          onPressed: () {
                            if (optionControllers.length > minOptions) {
                              removeOptionField(i);
                            } else {
                              setState(() {
                                optionControllers[i].clear();
                                removeImage(i);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (optionErrorTexts[i].isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h, left: 60.w),
                    child: Text(
                      optionErrorTexts[i],
                      style: CustomTextStyles.msgErrorText(context),
                    ),
                  ),
              ],
            ),
          );
        }),
        SizedBox(height: 5.h),
        if (optionControllers.length < maxOptions) ...[
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: addOptionField,
              icon: Icon(
                Icons.add,
                size: 17,
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
          SizedBox(height: 15.h),
        ],
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
        if (optionsErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h, bottom: 10.h),
            child: Text(
              optionsErrorText,
              style: CustomTextStyles.msgErrorText(context),
              textAlign: TextAlign.start,
            ),
          ),
      ],
    );
  }
}
