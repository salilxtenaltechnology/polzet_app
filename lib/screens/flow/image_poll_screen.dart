// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../api/services/api_service.dart';
import '../../../api/services/image/image_picker_service.dart';
import '../../../data/token/shared_preferences.dart';
import '../../../widgets/show_toast.dart';
import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';
import '../../widgets/dotted_border/dotted_border.dart';
import 'all_set_screen.dart';

/// Image poll option model
class _ImageOption {
  File? image;
  _ImageOption();
}

class ImagePollScreen extends StatefulWidget {
  const ImagePollScreen({super.key});

  @override
  State<ImagePollScreen> createState() => _ImagePollScreenState();
}

class _ImagePollScreenState extends State<ImagePollScreen> {
  // ── Constants ─────────────────────────────────────────────────────────────
  static const int _maxImages = 4;
  static const kDark = Color(0xFF111111);

  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _questionCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  final List<_ImageOption> _options = [_ImageOption(), _ImageOption()];

  bool _isLoading = false;
  String _questionError = '';
  String _imageError = '';

  // ── Image picking (uses ImagePickerService like PollImages) ───────────────

  Future<void> _pickImage(int index) async {
    try {
      final File? pickedFile = await ImagePickerService.pickImage(
        context: context,
        allowCamera: true,
      );

      if (pickedFile != null) {
        final File? croppedFile = await ImagePickerService.cropImage(
          pickedFile,
        );

        setState(() {
          _options[index].image = croppedFile ?? pickedFile;
          if (_imageError.isNotEmpty) _imageError = '';
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error picking image: $e');
    }
  }

  void _addOption() {
    if (_options.length < _maxImages) {
      setState(() => _options.add(_ImageOption()));
    }
  }

  void _removeOption(int index) {
    if (_options.length > 2) {
      setState(() => _options.removeAt(index));
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validateInputs() {
    bool isValid = true;

    if (_questionCtrl.text.trim().isEmpty) {
      setState(() => _questionError = 'Please enter a question');
      isValid = false;
    }

    final selectedImages = _options
        .where((o) => o.image != null)
        .map((o) => o.image!)
        .toList();

    if (selectedImages.length < 2) {
      setState(() => _imageError = 'Please add at least 2 images');
      isValid = false;
    }

    if (selectedImages.length > _maxImages) {
      setState(() => _imageError = 'Maximum $_maxImages images allowed');
      isValid = false;
    }

    return isValid;
  }

  // ── API call (mirrors PollImages.postImage) ───────────────────────────────

  Future<void> _createPoll() async {
    setState(() {
      _questionError = '';
      _imageError = '';
    });

    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();

      final selectedImages = _options
          .where((o) => o.image != null)
          .map((o) => o.image!)
          .toList();

      final Map<String, dynamic>? result = await ApiService.uploadImagePoll(
        description: _questionCtrl.text.trim(),
        question: 'Image Preference Poll',
        pollOptions: selectedImages,
        maxOptions: _maxImages,
        authToken: accessToken,
        onProgress: (progress) {
          if (kDebugMode) {
            print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );

      if (result != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AllSetScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;

      if (kDebugMode) print('Error creating poll: $e');

      final errorMessage = e.toString().replaceAll('Exception: ', '');

      if (errorMessage.contains('too large') || errorMessage.contains('10MB')) {
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
          message: errorMessage.isEmpty ? 'Error uploading poll' : errorMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  // ── Build (UI unchanged) ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rows = <List<int>>[];
    for (var i = 0; i < _options.length; i += 2) {
      rows.add([i, if (i + 1 < _options.length) i + 1]);
    }

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
                      'Create a visual poll',
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onBackground,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Let people choose by tapping on images',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.5,
                        color: txt.body,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Question
                    Text(
                      'Question',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _questionCtrl,
                      maxLines: 2,
                      onChanged: (value) {
                        if (_questionError.isNotEmpty &&
                            value.trim().isNotEmpty) {
                          setState(() => _questionError = '');
                        }
                      },
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF2C2C2C),
                      ),
                      decoration: InputDecoration(
                        hintText: 'What dress should I wear?',
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
                    ),
                    // Question error
                    if (_questionError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _questionError,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            color: Colors.red,
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
                        color: kDark,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Image grid (2 per row)
                    ...rows.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            ...row.map((i) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: i % 2 == 0 ? 6 : 0,
                                    left: i % 2 == 1 ? 6 : 0,
                                  ),
                                  child: _ImageOptionCard(
                                    option: _options[i],
                                    showRemove: _options.length > 2,
                                    onTap: () => _pickImage(i),
                                    onRemove: () => _removeOption(i),
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
                    const SizedBox(height: 5),
                    Text(
                      'Add 2–4 similar images (e.g. outfits, places, food)',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: txt.muted,
                      ),
                    ),
                    // Image error
                    if (_imageError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          _imageError,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Add Option
                    if (_options.length < _maxImages)
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.8),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onPrimary,
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

            // ── Bottom action
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
}

// ── _ImageOptionCard (UI unchanged) ──────────────────────────────────────────

class _ImageOptionCard extends StatelessWidget {
  final _ImageOption option;
  final bool showRemove;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImageOptionCard({
    required this.option,
    required this.showRemove,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1.3,
            child: CustomPaint(
              painter: DottedBorderPainter(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.4),
                strokeWidth: 1.5,
                gap: 5,
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: option.image != null
                      ? Image.file(option.image!, fit: BoxFit.cover)
                      : Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              FeatherIcons.share,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        if (showRemove)
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                size: 20,
                color: Color(0xFF8E8E8E),
              ),
            ),
          ),
      ],
    );
  }
}
