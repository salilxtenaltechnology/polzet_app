// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:dio/dio.dart';
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/app_api.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../core/constants/app_colors.dart';
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

class NewHotTakePoll extends StatefulWidget {
  const NewHotTakePoll({super.key});

  @override
  State<NewHotTakePoll> createState() => _NewHotTakePollState();
}

class _NewHotTakePollState extends State<NewHotTakePoll> {
  final ApiService service = ApiService();
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final _dio = Dio();
  bool isLoading = false;
  String questionErrorText = '';
  File? _image;

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
        final List<File>? finalFiles = await Navigator.push<List<File>>(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewCropScreen(initialImages: pickedFiles),
          ),
        );

        if (finalFiles != null && finalFiles.isNotEmpty && mounted) {
          setState(() {
            _image = finalFiles[0];
          });
        }
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
                  _cropCurrentImage();
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
                    _pickImage();
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

  Future<void> _createHotTakePoll() async {
    setState(() {
      questionErrorText = '';
    });

    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = 'Please enter a question or topic';
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: AppLocalizations.of(context)!.shareahottake),
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
              Text(
                '${AppLocalizations.of(context)!.addimage} (${AppLocalizations.of(context)!.optional})',
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              SizedBox(height: 7.h),
              _buildImageSelector(context),
              SizedBox(height: 20.h),
              Text(
                AppLocalizations.of(context)!.reactions,
                style: CustomTextStyles.lblPrimaryText(context),
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
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
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
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 20),
        height: 70.h,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.addpoll,
          onPressed: isLoading ? null : _createHotTakePoll,
          isLoading: isLoading,
        ),
      ),
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
