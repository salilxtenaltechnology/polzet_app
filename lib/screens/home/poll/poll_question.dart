// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/app_api.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../widgets/button/back_button.dart';
import '../../../widgets/button/primary_button.dart';
import '../../../widgets/custom_text_styles.dart';
import '../../../widgets/show_toast.dart';
import '../../../widgets/text_field/secondry_textfield.dart';

class PollQuestion extends StatefulWidget {
  const PollQuestion({super.key});

  @override
  State<PollQuestion> createState() => _PollQuestionState();
}

class _PollQuestionState extends State<PollQuestion> with UtilityMixin {
  // Constants
  static const int minOptions = 2;
  static const int maxOptions = 4;

  // Controllers
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> optionControllers = [];

  // State
  bool _isLoading = false;
  String questionErrorText = '';
  String optionsErrorText = '';

  final _dio = Dio();

  @override
  void initState() {
    super.initState();
    _initializeOptionFields();
    questionController.addListener(_clearQuestionError);
  }

  /// Initialize with minimum required option fields
  void _initializeOptionFields() {
    for (int i = 0; i < minOptions; i++) {
      final controller = TextEditingController();
      controller.addListener(_clearOptionsError);
      optionControllers.add(controller);
    }
  }

  /// Clear question error when user starts typing
  void _clearQuestionError() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      setState(() {
        questionErrorText = '';
      });
    }
  }

  /// Clear options error when valid options count is reached
  void _clearOptionsError() {
    if (optionsErrorText.isNotEmpty) {
      final validCount = _getValidOptions().length;
      if (validCount >= minOptions) {
        setState(() {
          optionsErrorText = '';
        });
      }
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
        newController.addListener(_clearOptionsError);
        optionControllers.add(newController);
      });
    }
  }

  /// Remove option field (minimum minOptions required)
  void removeOptionField(int index) {
    if (optionControllers.length > minOptions) {
      setState(() {
        optionControllers[index].removeListener(_clearOptionsError);
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
      controller.removeListener(_clearOptionsError);
      controller.dispose();
    }

    // Reset to initial state
    setState(() {
      optionControllers.clear();
      _initializeOptionFields();
      questionErrorText = '';
      optionsErrorText = '';
    });
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
      final accessToken = await SharedPrefService.getAccessToken();
      final validOptions = _getValidOptions();

      // Prepare request body - Use FormData to send poll_options as separate fields
      final formData = FormData.fromMap({
        "description": descriptionController.text.trim(),
        "question": questionController.text.trim(),
        "max_options": maxOptions.toString(),
      });

      // Add each poll option as a separate field
      for (var option in validOptions) {
        formData.fields.add(MapEntry('poll_options', option));
      }

      if (kDebugMode) {
        print('Request data: ${formData.fields}');
        print('Poll options count: ${validOptions.length}');
      }

      // Make API call
      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      // Handle success
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        showToast(message: 'New poll created successfully!');

        if (kDebugMode) {
          print('Poll created successfully: ${response.data}');
        }

        // Reset form
        _resetForm();
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
          errorMsg = errorData?['message']?.toString() ??
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
    descriptionController.dispose();
    questionController.dispose();
    for (var controller in optionControllers) {
      controller.removeListener(_clearOptionsError);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.addnewpollanswer,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),
            
            // Question Field
            _buildQuestionField(),
            
            SizedBox(height: 15.h),
            
            // Description Field
            _buildDescriptionField(),
            
            SizedBox(height: 15.h),
            
            // Poll Options
            _buildPollOptionsSection(),
            
            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 50.h,
        child: PrimaryButton(
          onPressed: _isLoading ? null : addPoll,
          title: AppLocalizations.of(context)!.addpoll,
          isLoading: _isLoading,
        ),
      ),
    );
  }

  /// Build question input field
  Widget _buildQuestionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.question,
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: questionController,
          hintText: AppLocalizations.of(context)!.enteryouranswerhere,
        ),
        if (questionErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: Text(
              questionErrorText,
              style: CustomTextStyles.msgErrorText,
            ),
          ),
      ],
    );
  }

  /// Build description input field
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.description,
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: descriptionController,
          hintText: AppLocalizations.of(context)!.enteryouranswerhere,
        ),
      ],
    );
  }

  /// Build poll options section
  Widget _buildPollOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poll Options',
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 10.h),
        
        // Option fields
        ...List.generate(optionControllers.length, (index) {
          return _buildOptionField(index);
        }),
        
        // Add option button
        if (optionControllers.length < maxOptions)
          TextButton.icon(
            onPressed: addOptionField,
            icon: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              AppLocalizations.of(context)!.addoption,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        
        // Options error message
        if (optionsErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h, bottom: 10.h),
            child: Text(
              optionsErrorText,
              style: CustomTextStyles.msgErrorText,
            ),
          ),
      ],
    );
  }

  /// Build individual option field
  Widget _buildOptionField(int index) {
    final canRemove = optionControllers.length > minOptions;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppLocalizations.of(context)!.option} ${index + 1}',
            style: CustomTextStyles.lblPrimaryText(context),
          ),
          SizedBox(height: 7.h),
          SecondryTextfield(
            controller: optionControllers[index],
            hintText: AppLocalizations.of(context)!.enteryouranswerhere,
            suffixIcon: canRemove
                ? IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => removeOptionField(index),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}