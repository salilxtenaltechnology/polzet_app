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
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import 'image_preview_crop_screen.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';

class NewBattelPoll extends StatefulWidget {
  const NewBattelPoll({super.key});

  @override
  State<NewBattelPoll> createState() => _NewBattelPollState();
}

class _NewBattelPollState extends State<NewBattelPoll> {
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
  List<String> get _hintTexts => [
    AppLocalizations.of(context)!.pleaseenteraquestion,
    AppLocalizations.of(context)!.pleaseenteratopic,
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

  Future<void> _pickMultiImages(int index) async {
    try {
      int otherSelectedCount = 0;
      for (int i = 0; i < _images.length; i++) {
        if (i != index && _images[i] != null) {
          otherSelectedCount++;
        }
      }
      final int allowedMaxImages = (2 - otherSelectedCount).clamp(1, 2);

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
            if (finalFiles.length >= 2) {
              _images[0] = finalFiles[0];
              _images[1] = finalFiles[1];
            } else {
              _images[index] = finalFiles[0];
            }
            imageErrorText = '';
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error picking images: ${e.toString()}');
    }
  }

  Future<void> _cropSingleImage(int index) async {
    if (index < 0 || index >= _images.length || _images[index] == null) return;

    final croppedFile = await ImagePickerService.cropImage(_images[index]!);
    if (croppedFile != null && mounted) {
      setState(() {
        _images[index] = croppedFile;
        imageErrorText = '';
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
                    _pickMultiImages(index);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10),
                child: GestureDetector(
                  child: Text(
                    'Remove',
                    style: AppTextStyles.bodyText.copyWith(
                      color: txt.body,
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

  void _removeImage(int index) {
    setState(() {
      _images[index] = null;
      imageErrorText = '';
    });
  }

  Future<void> _createBattlePoll() async {
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

    if (!hasLabel1 && !hasLabel2 && !hasImage1 && !hasImage2) {
      setState(() {
        imageErrorText = 'Please enter label or select image';
      });
      hasError = true;
    } else if (hasLabel1 && hasLabel2 && hasImage1 && hasImage2) {
      // 2 image and label -> valid
    } else if (hasLabel1 && hasLabel2 && !hasImage1 && !hasImage2) {
      // 2 label -> valid
    } else if (!hasLabel1 && !hasLabel2 && hasImage1 && hasImage2) {
      // 2 image -> valid
    } else if (hasLabel1 && !hasImage1 && !hasLabel2 && hasImage2) {
      // 1 label 1 image -> not allow
      setState(() {
        imageErrorText =
            'Mismatched options: One option with text only and one with image only is not allowed';
      });
      hasError = true;
    } else if (!hasLabel1 && hasImage1 && hasLabel2 && !hasImage2) {
      // 1 label 1 image -> not allow
      setState(() {
        imageErrorText =
            'Mismatched options: One option with text only and one with image only is not allowed';
      });
      hasError = true;
    } else if (hasLabel1 && hasLabel2 && (hasImage1 != hasImage2)) {
      // 2 label 1 image
      setState(() {
        imageErrorText = 'Please select image';
      });
      hasError = true;
    } else if (hasImage1 && hasImage2 && (hasLabel1 != hasLabel2)) {
      // 2 image 1 label
      setState(() {
        if (!hasLabel1) {
          label1ErrorText = 'Please enter label';
        }
        if (!hasLabel2) {
          label2ErrorText = 'Please enter label';
        }
      });
      hasError = true;
    } else if (!hasImage1 && !hasImage2 && (hasLabel1 != hasLabel2)) {
      // 1 label blank (no images at all)
      setState(() {
        if (!hasLabel1) {
          label1ErrorText = 'Please enter label';
        }
        if (!hasLabel2) {
          label2ErrorText = 'Please enter label';
        }
      });
      hasError = true;
    } else if (!hasLabel1 && !hasLabel2 && (hasImage1 != hasImage2)) {
      // 1 image blank (no labels at all)
      setState(() {
        imageErrorText = 'Please select image';
      });
      hasError = true;
    } else {
      // One option has both image + label, and the other is empty
      setState(() {
        if (!hasLabel1 && !hasImage1) {
          label1ErrorText = 'Please enter label';
        }
        if (!hasLabel2 && !hasImage2) {
          label2ErrorText = 'Please enter label';
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
        const MapEntry('poll_type', 'battle'),
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
        showToast(message: 'New battle poll created!');
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
      appBar:  CommonAppBar(title:  AppLocalizations.of(context)!.startabattle),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),
              Text(
                AppLocalizations.of(
                  context,
                )!.putcompetitorsheadtoheadandseewhichsidewins,
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
                    AppLocalizations.of(context)!.startbattel,
                    style: CustomTextStyles.lblPrimaryText(context),
                  ),
                  GestureDetector(
                    onTap: _isGeneratingQuestion ? null : generateQuestion,
                    child: Row(
                      children: [
                        _isGeneratingQuestion
                            ? const SizedBox()
                            : Assets.images.icAssistant.image(
                                width: 14.w,
                                height: 14.h,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                        const SizedBox(width: 5),
                        Text(
                          _isGeneratingQuestion
                              ? AppLocalizations.of(context)!.generating
                              : _hasGeneratedQuestion
                              ? AppLocalizations.of(context)!.regeneratequestion
                              : AppLocalizations.of(context)!.generatequestion,
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
                AppLocalizations.of(context)!.descriptionhashtagsoptional,
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              SizedBox(height: 7.h),
              SecondryTextfield(
                controller: descriptionController,
                hintText: AppLocalizations.of(
                  context,
                )!.typedescriptionorhashtags,
                maxLines: 5,
                minLines: 1,
              ),
              SizedBox(height: 20.h),
              _buildCompetitorsSection(context),
              SizedBox(height: 12.h),
              Text(
                AppLocalizations.of(context)!.addtwosimilarimagesegoutfitsplacesfood,
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.muted,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
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
          onPressed: isLoading ? null : _createBattlePoll,
          isLoading: isLoading,
        ),
      ),
    );
  }

  Widget _buildCompetitorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.competitors,
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 12.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildCompetitorCard(
                context,
                0,
                label1Controller,
                label1ErrorText,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildCompetitorCard(
                context,
                1,
                label2Controller,
                label2ErrorText,
              ),
            ),
          ],
        ),
        if (imageErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Center(
              child: Text(
                imageErrorText,
                style: CustomTextStyles.msgErrorText(context),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompetitorCard(
    BuildContext context,
    int index,
    TextEditingController controller,
    String errorText,
  ) {
    final bool hasImage = _images[index] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (hasImage) {
              _onTapEditImage(index);
            } else {
              _pickMultiImages(index);
            }
          },
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
                            child: Image.file(
                              _images[index]!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 5.h,
                            right: 5.w,
                            child: GestureDetector(
                              onTap: () => _onTapEditImage(index),
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
        SizedBox(height: 12.h),
        SecondryTextfield(
          controller: controller,
          hintText: AppLocalizations.of(context)!.addlabel,
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
