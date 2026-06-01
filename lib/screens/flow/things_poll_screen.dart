// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../api/app_api.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../widgets/show_toast.dart';
import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import 'all_set_screen.dart';

class ThingsPollScreen extends StatefulWidget {
  const ThingsPollScreen({super.key});

  @override
  State<ThingsPollScreen> createState() => _ThingsPollScreenState();
}

class _ThingsPollScreenState extends State<ThingsPollScreen> {
  // ── Constants ─────────────────────────────────────────────────────────────
  static const int _minOptions = 2;
  static const int _maxOptions = 4;

  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [];

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String _questionError = '';
  String _optionsError = '';

  final _dio = Dio();

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initOptionFields();
    _questionCtrl.addListener(_clearQuestionError);
  }

  void _initOptionFields() {
    for (int i = 0; i < _minOptions; i++) {
      final ctrl = TextEditingController();
      ctrl.addListener(_clearOptionsError);
      _optionCtrls.add(ctrl);
    }
  }

  // ── Error listeners ───────────────────────────────────────────────────────

  void _clearQuestionError() {
    if (_questionError.isNotEmpty && _questionCtrl.text.trim().isNotEmpty) {
      setState(() => _questionError = '');
    }
  }

  void _clearOptionsError() {
    if (_optionsError.isNotEmpty && _getValidOptions().length >= _minOptions) {
      setState(() => _optionsError = '');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<String> _getValidOptions() {
    return _optionCtrls
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();
  }

  bool _validateInputs() {
    bool isValid = true;

    if (_questionCtrl.text.trim().isEmpty) {
      setState(() => _questionError = 'Please enter a question');
      isValid = false;
    }

    if (_getValidOptions().length < _minOptions) {
      setState(() => _optionsError = 'Please enter at least two options');
      isValid = false;
    }

    return isValid;
  }

  // ── Add / Remove options ──────────────────────────────────────────────────

  void _addOption() {
    if (_optionCtrls.length < _maxOptions) {
      setState(() {
        final ctrl = TextEditingController();
        ctrl.addListener(_clearOptionsError);
        _optionCtrls.add(ctrl);
      });
    }
  }

  void _removeOption(int index) {
    if (_optionCtrls.length > _minOptions) {
      setState(() {
        _optionCtrls[index].removeListener(_clearOptionsError);
        _optionCtrls[index].dispose();
        _optionCtrls.removeAt(index);
      });
    }
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _createPoll() async {
    setState(() {
      _questionError = '';
      _optionsError = '';
    });

    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final validOptions = _getValidOptions();

      final formData = FormData.fromMap({
        "question": _questionCtrl.text.trim(),
        "max_options": _maxOptions.toString(),
      });

      for (final option in validOptions) {
        formData.fields.add(MapEntry('poll_options', option));
      }

      if (kDebugMode) {
        print('Poll request fields: ${formData.fields}');
        print('Poll options count: ${validOptions.length}');
      }

      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showToast(message: 'New poll created successfully!');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AllSetScreen()),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      _handleDioError(e);
    } catch (e) {
      if (!mounted) return;
      showToast(message: 'Unexpected error: $e');
      if (kDebugMode) print('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleDioError(DioException e) {
    String errorMsg;

    if (e.response != null) {
      final statusCode = e.response?.statusCode ?? 0;
      final errorData = e.response?.data;
      if (kDebugMode) print('Error response: $errorData');

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

  String? _extractValidationError(dynamic errorData) {
    if (errorData == null) return null;
    final errors = errorData['errors'];
    if (errors != null) {
      if (errors['poll_options'] != null) {
        return errors['poll_options'].toString();
      }
      if (errors['question'] != null) {
        return errors['question'].toString();
      }
    }
    return errorData['message']?.toString();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _questionCtrl.removeListener(_clearQuestionError);
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.removeListener(_clearOptionsError);
      c.dispose();
    }
    super.dispose();
  }

  // ── Build (UI unchanged) ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ),
                  Text(
                    'Step 3 of 3',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: txt.title.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Ask your question',
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onBackground,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask a question and add options for people to vote',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.5,
                        color: txt.body,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Question label
                    Text(
                      'Question',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _questionCtrl,
                      hint: 'What dress should I wear?',
                      maxLines: 2,
                    ),
                    if (_questionError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _questionError,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Options label
                    Text(
                      'Options',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Option fields
                    ...List.generate(_optionCtrls.length, (i) {
                      final showRemove = _optionCtrls.length > _minOptions;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _optionCtrls[i],
                                hint: 'Option ${i + 1}',
                              ),
                            ),
                            if (showRemove) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeOption(i),
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
                    }),
                    const SizedBox(height: 5),
                    Text(
                      'Add 2–4 clear options (e.g. outfits, places, food)',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: txt.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (_optionsError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _optionsError,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Add Option button
                    if (_optionCtrls.length < _maxOptions)
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: OutlinedButton.icon(
                          onPressed: _addOption,
                          icon: Icon(
                            Icons.add,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
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
                              borderRadius: BorderRadius.circular(
                                AppRadius.button,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Bottom actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createPoll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Create Poll',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTextStyles.bodyText.copyWith(
        fontSize: 14,
        color: const Color(0xFF2C2C2C),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.subText.copyWith(
          fontSize: 14.5,
          color: const Color(0XFF898989),
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
      ),
    );
  }
}
