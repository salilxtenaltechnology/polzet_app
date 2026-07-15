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
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';

class NewThisOrThat extends StatefulWidget {
  const NewThisOrThat({super.key});

  @override
  State<NewThisOrThat> createState() => _NewThisOrThatState();
}

class _NewThisOrThatState extends State<NewThisOrThat> {
  final ApiService service = ApiService();
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController label1Controller = TextEditingController();
  final TextEditingController label2Controller = TextEditingController();

  final List<File?> _images = [null, null];
  bool isLoading = false;
  final _dio = Dio();

  String questionErrorText = '';
  String imageErrorText = '';
  String label1ErrorText = '';
  String label2ErrorText = '';

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;

  // Hint animation state
  int _currentHintIndex = 0;
  Timer? _hintTimer;
  final List<String> _hintTexts = [
    'Please enter a question',
    'Please enter a topic',
  ];

  @override
  void initState() {
    super.initState();
    questionController.addListener(_clearQuestionError);
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

  void _clearQuestionError() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      setState(() {
        questionErrorText = '';
      });
    }
  }

  Future<void> generateQuestion() async {
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
        _clearQuestionError();
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
    questionController.removeListener(_clearQuestionError);
    questionController.dispose();
    descriptionController.dispose();
    label1Controller.dispose();
    label2Controller.dispose();
    super.dispose();
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
          imageErrorText = '';
        });
      }
    } catch (e) {
      showToast(message: 'Error picking image: ${e.toString()}');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images[index] = null;
      imageErrorText = '';
    });
  }

  Future<void> _createThisOrThatPoll() async {
    setState(() {
      questionErrorText = '';
      imageErrorText = '';
      label1ErrorText = '';
      label2ErrorText = '';
    });

    bool hasError = false;

    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = 'Please enter a question or topic';
      });
      hasError = true;
    }

    final bool hasLabel1 = label1Controller.text.trim().isNotEmpty;
    final bool hasLabel2 = label2Controller.text.trim().isNotEmpty;
    final bool hasImage1 = _images[0] != null;
    final bool hasImage2 = _images[1] != null;

    if (!hasLabel1) {
      setState(() {
        label1ErrorText = 'Please enter label';
      });
      hasError = true;
    }
    if (!hasLabel2) {
      setState(() {
        label2ErrorText = 'Please enter label';
      });
      hasError = true;
    }
    if (!hasImage1 || !hasImage2) {
      setState(() {
        if (!hasImage1 && !hasImage2) {
          imageErrorText = 'Please select images for both labels';
        } else if (!hasImage1) {
          imageErrorText = 'Please select image for first label';
        } else {
          imageErrorText = 'Please select image for scond label';
        }
      });
      hasError = true;
    }

    if (hasError) return;

    setState(() => isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('question', questionController.text.trim()),
        MapEntry('description', descriptionController.text.trim()),
        const MapEntry('poll_type', 'this_or_that'),
        const MapEntry('voting_type', 'single_choice'),
        const MapEntry('max_options', '1'),
      ]);

      // Add labels as poll_options
      formData.fields.add(
        MapEntry('poll_options', label1Controller.text.trim()),
      );
      formData.fields.add(
        MapEntry('poll_options', label2Controller.text.trim()),
      );

      // Add images and their indices if selected
      final List<int> indices = [];
      for (int i = 0; i < _images.length; i++) {
        final imageFile = _images[i];
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
          indices.add(i);
        }
      }
      if (indices.isNotEmpty) {
        formData.fields.add(MapEntry('image_indices', jsonEncode(indices)));
      }

      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showToast(message: 'New this or that poll created!');
        Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
        Navigator.of(context).pop(response.data);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final errorMsg =
          e.response?.data?['message'] ?? 'Failed to create battle poll';
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Create This or That'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),
              Text(
                'Compare two choices and discover what people prefer',
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
                    'Ask quickly',
                    style: CustomTextStyles.lblPrimaryText(context),
                  ),
                  GestureDetector(
                    onTap: _isGeneratingQuestion ? null : generateQuestion,
                    child: Row(
                      children: [
                        _isGeneratingQuestion
                            ? SizedBox(
                                width: 12.w,
                                height: 12.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : Assets.images.icAssistant.image(
                                width: 14.w,
                                height: 14.h,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        const SizedBox(width: 5),
                        Text(
                          _isGeneratingQuestion
                              ? 'Generating...'
                              : _hasGeneratedQuestion
                              ? 'Regenerate Question'
                              : 'Generate Question',
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 7.h),
              SecondryTextfield(
                controller: questionController,
                hintText: _hintTexts[_currentHintIndex],
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
                'Description & Hashtags (Optional)',
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              SizedBox(height: 7.h),
              SecondryTextfield(
                controller: descriptionController,
                hintText: 'Type description or hashtags',
                maxLines: 5,
                minLines: 1,
              ),
              SizedBox(height: 20.h),
              _buildCompetitorsSection(context),
              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 20),
        height: 70.h,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.addpoll,
          onPressed: isLoading ? null : _createThisOrThatPoll,
          isLoading: isLoading,
        ),
      ),
    );
  }

  Widget _buildCompetitorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Options', style: CustomTextStyles.lblPrimaryText(context)),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: _buildImageSelector(context, 0)),
            SizedBox(width: 12.w),
            Expanded(child: _buildImageSelector(context, 1)),
          ],
        ),
        if (imageErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text(
              imageErrorText,
              style: CustomTextStyles.msgErrorText(context),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: 12.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLabelField(
                context,
                0,
                label1Controller,
                label1ErrorText,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildLabelField(
                context,
                1,
                label2Controller,
                label2ErrorText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageSelector(BuildContext context, int index) {
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
                      Positioned(
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
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
    );
  }

  Widget _buildLabelField(
    BuildContext context,
    int index,
    TextEditingController controller,
    String errorText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SecondryTextfield(
          controller: controller,
          hintText: 'Add label',
          onChanged: (value) {
            if (errorText.isNotEmpty && value.trim().isNotEmpty) {
              setState(() {
                if (index == 0) {
                  label1ErrorText = '';
                } else {
                  label2ErrorText = '';
                }
              });
            }
          },
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 5.h),
            child: Text(
              errorText,
              style: CustomTextStyles.msgErrorText(context),
            ),
          ),
      ],
    );
  }
}
