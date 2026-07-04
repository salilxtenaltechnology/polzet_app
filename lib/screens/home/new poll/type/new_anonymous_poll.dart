// ignore_for_file: deprecated_member_use, use_build_context_synchronously

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
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';

class NewAnonymousPoll extends StatefulWidget {
  const NewAnonymousPoll({super.key});

  @override
  State<NewAnonymousPoll> createState() => _NewAnonymousPollState();
}

class _NewAnonymousPollState extends State<NewAnonymousPoll> {
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  final List<TextEditingController> optionControllers = [];
  final List<File?> _images = [];
  final List<String> optionErrorTexts = [];
  static const int minOptions = 2;
  static const int maxOptions = 4;

  // API loading & validation state
  bool _isLoading = false;
  String questionErrorText = '';
  String optionsErrorText = '';

  final _dio = Dio();

  @override
  void initState() {
    super.initState();
    questionController.addListener(_clearQuestionError);
    _initializeOptionFields();
  }

  void _initializeOptionFields() {
    for (int i = 0; i < minOptions; i++) {
      _images.add(null);
      final controller = TextEditingController();
      controller.addListener(_clearOptionsError);
      optionControllers.add(controller);
      optionErrorTexts.add('');
    }
  }

  void addOptionField() {
    if (optionControllers.length < maxOptions) {
      setState(() {
        _images.add(null);
        final newController = TextEditingController();
        newController.addListener(_clearOptionsError);
        optionControllers.add(newController);
        optionErrorTexts.add('');
      });
    }
  }

  void removeOptionField(int index) {
    if (optionControllers.length > minOptions) {
      setState(() {
        _images.removeAt(index);
        optionControllers[index].removeListener(_clearOptionsError);
        optionControllers[index].dispose();
        optionControllers.removeAt(index);
        optionErrorTexts.removeAt(index);
      });
      _clearOptionsError();
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
          _clearOptionsError();
        });
      }
    } catch (e) {
      showToast(message: 'Error picking image: ${e.toString()}');
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

  void _clearQuestionError() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      setState(() {
        questionErrorText = '';
      });
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
    questionController.removeListener(_clearQuestionError);
    questionController.dispose();
    descriptionController.dispose();
    for (var controller in optionControllers) {
      controller.removeListener(_clearOptionsError);
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
      appBar: const CommonAppBar(title: 'Ask Anonymously'),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 10.h),
            Text(
              'Share questions privately and get honest opinions from people',
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
                      'Your voters will be hidden on this poll',
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

  Widget _buildOptionsSection() {
    final rows = <List<int>>[];
    for (var i = 0; i < optionControllers.length; i += 2) {
      rows.add([i, if (i + 1 < optionControllers.length) i + 1]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.polloptions,
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 10.h),
        ...rows.map((row) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...row.map((i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i % 2 == 0 ? 6.w : 0,
                        left: i % 2 == 1 ? 6.w : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              _buildImageOption(context, i),
                              if (_images[i] != null)
                                Positioned(
                                  top: 8.h,
                                  right: 10.w,
                                  child: GestureDetector(
                                    onTap: () => removeImage(i),
                                    child: Container(
                                      width: 18.w,
                                      height: 18.h,
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
                                        Icons.close,
                                        color: Colors.white,
                                        size: 12.sp,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(
                                child: SecondryTextfield(
                                  controller: optionControllers[i],
                                  hintText: 'Add label',
                                ),
                              ),
                              if (optionControllers.length > minOptions) ...[
                                SizedBox(width: 4.w),
                                GestureDetector(
                                  onTap: () => removeOptionField(i),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Color(0xFF8E8E8E),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (optionErrorTexts[i].isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 5.h),
                              child: Text(
                                optionErrorTexts[i],
                                style: CustomTextStyles.msgErrorText(context),
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
                '+ Add options',
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
              textAlign: TextAlign.start,
            ),
          ),
      ],
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
                        ).colorScheme.onSurface.withOpacity(0.2),
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
}
