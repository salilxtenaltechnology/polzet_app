// ignore_for_file: unused_element, deprecated_member_use, use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../provider/user_provider.dart';

import '../../../../api/app_api.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_styles.dart';

class NewTextPoll extends StatefulWidget {
  const NewTextPoll({super.key});

  @override
  State<NewTextPoll> createState() => _NewThingsPollState();
}

class _NewThingsPollState extends State<NewTextPoll> with UtilityMixin {
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
      final accessToken = await SharedPrefService.getToken();
      final validOptions = _getValidOptions();

      final formData = FormData.fromMap({
        "question": questionController.text.trim(),
        "description": descriptionController.text.trim(),
        "poll_type": "text",
        "voting_type": "ranking",
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
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.addnewpollanswer,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),

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
          hintText: AppLocalizations.of(context)!.enteryourquestion,
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
          'Description & Hashtags (Optional)',
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 7.h),
        SecondryTextfield(
          controller: descriptionController,
          hintText: 'Type description or hashtags',
          maxLines: 5,
          minLines: 3,
        ),
      ],
    );
  }

  Widget _buildPollOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.polloptions,
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 10.h),

        ...List.generate(optionControllers.length, (index) {
          return _buildOptionField(index);
        }),

        if (optionControllers.length < maxOptions)
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

        if (optionsErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h, bottom: 10.h),
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

    return Padding(
      padding: EdgeInsets.only(bottom: 15.h),
      child: Row(
        children: [
          Expanded(
            child: SecondryTextfield(
              controller: optionControllers[index],
              hintText: '${AppLocalizations.of(context)!.option} ${index + 1}',
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
