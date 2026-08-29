// ignore_for_file: unused_element, deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../provider/user_provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/app_api.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import '../../../../widgets/banner/ai_generation_limit_banner.dart';
import '../../../../widgets/button/generate_question_button.dart';
import '../../../../widgets/button/generate_option_button.dart';
import '../../../../widgets/button/generate_description_button.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

class NewTextPoll extends StatefulWidget {
  final String? initialQuestion;
  final String? initialDescription;

  const NewTextPoll({super.key, this.initialQuestion, this.initialDescription});

  @override
  State<NewTextPoll> createState() => _NewThingsPollState();
}

class _NewThingsPollState extends State<NewTextPoll> with UtilityMixin {
  // Constants
  static const int minOptions = 2;
  static const int maxOptions = 4;

  // Controllers & FocusNodes
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  final FocusNode questionFocusNode = FocusNode();
  final List<TextEditingController> optionControllers = [];

  // State
  bool _isLoading = false;
  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;
  bool _isGeneratingOptions = false;
  bool _hasGeneratedOptions = false;
  bool _isGeneratingDescription = false;
  bool _hasGeneratedDescription = false;
  bool _isMultiChoice = false;
  String questionErrorText = '';
  String optionsErrorText = '';

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
    if (widget.initialQuestion != null &&
        widget.initialQuestion!.trim().isNotEmpty) {
      questionController.text = widget.initialQuestion!;
    }
    if (widget.initialDescription != null &&
        widget.initialDescription!.trim().isNotEmpty) {
      descriptionController.text = widget.initialDescription!;
    }
    _initializeOptionFields();
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

  /// Initialize with minimum required option fields
  void _initializeOptionFields() {
    for (int i = 0; i < minOptions; i++) {
      final controller = TextEditingController();
      controller.addListener(_onOptionChanged);
      optionControllers.add(controller);
    }
  }

  /// Handle question change to clear error and update active border state
  void _onQuestionChanged() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      questionErrorText = '';
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Clear options error and update UI state on option text changes
  void _onOptionChanged() {
    if (optionsErrorText.isNotEmpty) {
      final validCount = _getValidOptions().length;
      if (validCount >= minOptions) {
        optionsErrorText = '';
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// Get list of non-empty options
  List<String> _getValidOptions() {
    return optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .map((controller) => controller.text.trim())
        .toList();
  }

  /// Validate all inputs before submission
  bool _validateInputs() {
    bool isValid = true;

    // Validate question
    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(context)!.pleaseenteraquestion;
      });
      isValid = false;
    }

    // Validate options count
    final validOptions = _getValidOptions();
    if (validOptions.length < minOptions) {
      setState(() {
        optionsErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleasttwooptions;
      });
      isValid = false;
    }

    if (kDebugMode) {
      print('Validation - Valid options: ${validOptions.length}');
      print('Validation - Is valid: $isValid');
    }

    return isValid;
  }

  /// Add new option field (up to maxOptions)
  void addOptionField() {
    if (optionControllers.length < maxOptions) {
      setState(() {
        final newController = TextEditingController();
        newController.addListener(_onOptionChanged);
        optionControllers.add(newController);
      });
    }
  }

  /// Remove option field (minimum minOptions required)
  void removeOptionField(int index) {
    if (optionControllers.length > minOptions) {
      setState(() {
        optionControllers[index].removeListener(_onOptionChanged);
        optionControllers[index].dispose();
        optionControllers.removeAt(index);
      });
    }
  }

  /// Reset form to initial state
  void _resetForm() {
    // Clear text fields
    descriptionController.clear();
    questionController.clear();

    // Dispose existing option controllers
    for (var controller in optionControllers) {
      controller.removeListener(_onOptionChanged);
      controller.dispose();
    }

    // Reset to initial state
    setState(() {
      optionControllers.clear();
      _initializeOptionFields();
      questionErrorText = '';
      optionsErrorText = '';
      _hasGeneratedQuestion = false;
      _hasGeneratedOptions = false;
      _hasGeneratedDescription = false;
      _isMultiChoice = false;
    });
  }

  /// Generate or improve the question using AI
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
      final response = await ApiService().generateQuestion(input: query);
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

  /// Generate options for the poll question using AI
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
        questionErrorText = AppLocalizations.of(context)!.pleaseenteraquestion;
      });
      return;
    }

    setState(() {
      _isGeneratingOptions = true;
    });

    try {
      final response = await ApiService().generateOptions(input: question);
      debugPrint('generateOptions response: $response');
      _updateAiLimitFromResponse(response);

      final List<dynamic>? optionsList = response['options'];
      if (optionsList != null && optionsList.isNotEmpty) {
        setState(() {
          final count = optionsList.length.clamp(minOptions, maxOptions);

          // Ensure we have enough controllers
          while (optionControllers.length < count) {
            final controller = TextEditingController();
            controller.addListener(_onOptionChanged);
            optionControllers.add(controller);
          }

          // Dispose excess controllers
          while (optionControllers.length > count) {
            final controller = optionControllers.removeLast();
            controller.removeListener(_onOptionChanged);
            controller.dispose();
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

    if (options.length < minOptions) {
      setState(() {
        optionsErrorText = AppLocalizations.of(
          context,
        )!.pleaseenteratleasttwooptions;
      });
      return;
    }

    setState(() {
      _isGeneratingDescription = true;
    });

    try {
      final descResponse = await ApiService().generateDescription(
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

  /// Create poll post via API
  Future<void> addPoll() async {
    // Clear previous errors
    setState(() {
      questionErrorText = '';
      optionsErrorText = '';
    });

    // Validate inputs
    if (!_validateInputs()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final validOptions = _getValidOptions();

      final formData = FormData.fromMap({
        "question": questionController.text.trim(),
        "description": descriptionController.text.trim(),
        "poll_type": "text",
        "voting_type": _isMultiChoice ? "ranking" : "single_choice",
        "max_options": maxOptions.toString(),
      });

      // Add each poll option as a separate field
      for (var option in validOptions) {
        formData.fields.add(MapEntry('poll_options', option));
      }
      // Make API call
      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      // Handle success
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        showToast(message: 'New things poll created!');

        // Clear cached posts so the profile screen updates immediately
        Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();

        // Reset form
        _resetForm();

        // Go back to the previous screen
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _handleDioError(e);
    } catch (e) {
      if (!mounted) return;
      showToast(message: 'Unexpected error: $e');
      if (kDebugMode) {
        print('Unexpected error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle Dio errors with proper messages
  void _handleDioError(DioException e) {
    String errorMsg;

    if (e.response != null) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorData = e.response?.data;

      if (kDebugMode) {
        print('Error response: $errorData');
      }

      switch (statusCode) {
        case 400:
          errorMsg = _extractValidationError(errorData) ?? 'Validation failed';
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

  /// Extract validation error from response
  String? _extractValidationError(dynamic errorData) {
    if (errorData == null) return null;

    // Try to extract specific field errors
    final errors = errorData['errors'];
    if (errors != null) {
      if (errors['poll_options'] != null) {
        return errors['poll_options'].toString();
      }
      if (errors['question'] != null) {
        return errors['question'].toString();
      }
      if (errors['description'] != null) {
        return errors['description'].toString();
      }
    }

    // Fall back to general message
    return errorData['message']?.toString();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    descriptionController.dispose();
    questionController.removeListener(_onQuestionChanged);
    questionController.dispose();
    questionFocusNode.dispose();
    for (var controller in optionControllers) {
      controller.removeListener(_onOptionChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.addnewpollanswer,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),

            // AI Generation Limit Banner
            AiGenerationLimitBanner(
              remainingGenerations: _remainingGenerations,
            ),
            SizedBox(height: 15.h),

            // Question Field
            _buildQuestionField(),
            SizedBox(height: 20.h),

            // Description Field
            _buildDescriptionField(),
            SizedBox(height: 20.h),

            // Poll Options
            _buildPollOptionsSection(),
            SizedBox(height: 20.h),
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
    final bool isQuestionEntered = questionController.text.trim().isNotEmpty;
    final primaryColor = Theme.of(context).colorScheme.onPrimary;

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
          focusedBorderColor: isQuestionEntered ? primaryColor : null,
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
    final primaryColor = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          focusedBorderColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildPollOptionsSection() {
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

        ...List.generate(optionControllers.length, (index) {
          return _buildOptionField(index);
        }),

        if (optionControllers.length < maxOptions) ...[
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: addOptionField,
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
            padding: EdgeInsets.only(top: 10.h, bottom: 10.h),
            child: Text(
              optionsErrorText,
              style: CustomTextStyles.msgErrorText(context),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionField(int index) {
    final canRemove = optionControllers.length > minOptions;
    final isOptionEntered = optionControllers[index].text.trim().isNotEmpty;
    final primaryColor = Theme.of(context).colorScheme.onPrimary;

    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: Row(
        children: [
          Expanded(
            child: SecondryTextfield(
              controller: optionControllers[index],
              hintText: '${AppLocalizations.of(context)!.option} ${index + 1}',
              focusedBorderColor: isOptionEntered ? primaryColor : null,
            ),
          ),
          if (canRemove) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => removeOptionField(index),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Color(0xFF8E8E8E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
