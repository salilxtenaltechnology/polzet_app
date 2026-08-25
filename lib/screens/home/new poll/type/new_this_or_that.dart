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
import '../../../../widgets/banner/ai_generation_limit_banner.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/button/generate_question_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';
import 'image_preview_crop_screen.dart';

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
  final FocusNode questionFocusNode = FocusNode();

  List<File> _selectedImages = [];
  static const int maxImages = 2;
  bool isLoading = false;
  final _dio = Dio();

  String questionErrorText = '';
  String imageErrorText = '';
  String label1ErrorText = '';
  String label2ErrorText = '';

  bool _isGeneratingQuestion = false;
  bool _hasGeneratedQuestion = false;

  int _remainingGenerations = 5;
  int _dailyLimit = 5;

  Future<void> _loadSavedAiLimit() async {
    final limitData = await SharedPrefService.getAiLimitData();
    if (mounted) {
      setState(() {
        _remainingGenerations = limitData['remaining'] ?? 5;
        _dailyLimit = limitData['daily_limit'] ?? 5;
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

  @override
  void initState() {
    super.initState();
    _loadSavedAiLimit();
    questionController.addListener(_onQuestionChanged);
    label1Controller.addListener(_onLabelChanged);
    label2Controller.addListener(_onLabelChanged);
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

  void _onQuestionChanged() {
    if (questionErrorText.isNotEmpty &&
        questionController.text.trim().isNotEmpty) {
      questionErrorText = '';
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _onLabelChanged() {
    if (mounted) {
      setState(() {});
    }
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

  @override
  void dispose() {
    _hintTimer?.cancel();
    questionController.removeListener(_onQuestionChanged);
    questionController.dispose();
    questionFocusNode.dispose();
    descriptionController.dispose();
    label1Controller.removeListener(_onLabelChanged);
    label1Controller.dispose();
    label2Controller.removeListener(_onLabelChanged);
    label2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final int remaining = maxImages - _selectedImages.length;
      if (remaining <= 0) return;

      final List<File>? pickedFiles = await ImagePickerService.pickMultiImages(
        context: context,
        maxImages: remaining,
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
            _selectedImages.addAll(finalFiles);
            if (_selectedImages.length > maxImages) {
              _selectedImages = _selectedImages.sublist(0, maxImages);
            }
            if (imageErrorText.isNotEmpty) {
              imageErrorText = '';
            }
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error picking images: ${e.toString()}');
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

  Future<void> _cropSingleImage(int index) async {
    if (index < 0 || index >= _selectedImages.length) return;

    final croppedFile = await ImagePickerService.cropImage(
      _selectedImages[index],
    );
    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImages[index] = croppedFile;
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
            _selectedImages[index] = finalFiles[0];
          });
        }
      }
    } catch (e) {
      showToast(message: 'Error replacing image: ${e.toString()}');
    }
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      setState(() {
        _selectedImages.removeAt(index);
      });
    }
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

    if (_selectedImages.isNotEmpty) {
      if (!hasLabel1) {
        setState(() {
          label1ErrorText = 'Please enter label';
        });
        hasError = true;
      }
      if (_selectedImages.length > 1 && !hasLabel2) {
        setState(() {
          label2ErrorText = 'Please enter label';
        });
        hasError = true;
      }
    }
    if (_selectedImages.length < maxImages) {
      setState(() {
        imageErrorText = 'Please select 2 images';
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

      // Add images and their indices
      final List<int> indices = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final imageFile = _selectedImages[i];
        final String ext = path.extension(imageFile.path).toLowerCase();
        final String subType = ext.startsWith('.') ? ext.substring(1) : 'jpeg';
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
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.createthisorthat,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
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
                )!.comparetwochoicesanddiscoverwhatpeopleprefer,
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
                    AppLocalizations.of(context)!.askquickly,
                    style: CustomTextStyles.lblPrimaryText(context),
                  ),
                  SizedBox(
                    height: 30,
                    child: GenerateQuestionButton(
                      isGenerating: _isGeneratingQuestion,
                      hasGenerated: _hasGeneratedQuestion,
                      onTap: _isGeneratingQuestion ? null : generateQuestion,
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
                focusedBorderColor: Theme.of(context).colorScheme.onPrimary,
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
        Text(
          AppLocalizations.of(context)!.option,
          style: CustomTextStyles.lblPrimaryText(context),
        ),
        SizedBox(height: 12.h),
        _buildImagesSection(context),
        if (imageErrorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text(
              imageErrorText,
              style: CustomTextStyles.msgErrorText(context),
              textAlign: TextAlign.center,
            ),
          ),
        if (_selectedImages.isNotEmpty) ...[
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
              if (_selectedImages.length > 1)
                Expanded(
                  child: _buildLabelField(
                    context,
                    1,
                    label2Controller,
                    label2ErrorText,
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildImagesSection(BuildContext context) {
    final txt = AppTextColors.of(context);

    if (_selectedImages.isEmpty) {
      // Empty state - single selection box like NewImagePoll
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: SizedBox(
              width: double.infinity,
              height: 150.h,
              child: CustomPaint(
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
          SizedBox(height: 8.h),
          Text(
            AppLocalizations.of(
              context,
            )!.addtwosimilarimagesegoutfitsplacesfood,
            style: AppTextStyles.bodyText.copyWith(
              color: txt.muted,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: _pickImages,
              icon: Icon(
                Icons.add,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                AppLocalizations.of(context)!.addoption,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 13.5,
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
        ],
      );
    } else {
      // Selected images - show 2 boxes side by side with edit icon
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(_selectedImages.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == 0 ? 6.w : 0,
                      left: i == 1 ? 6.w : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => _onTapEditImage(i),
                      child: AspectRatio(
                        aspectRatio: 1.3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(
                                  _selectedImages[i],
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 5.h,
                                right: 5.w,
                                child: GestureDetector(
                                  onTap: () => _onTapEditImage(i),
                                  child: Container(
                                    width: 22.w,
                                    height: 22.h,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                      ),
                    ),
                  ),
                );
              }),
              if (_selectedImages.length == 1)
                const Expanded(child: SizedBox()),
            ],
          ),
          if (_selectedImages.length < maxImages) ...[
            SizedBox(height: 8.h),
            Text(
              'Add 2 images to compare (e.g. outfits, places, food)',
              style: AppTextStyles.bodyText.copyWith(
                color: txt.muted,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  'Add Option',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.5,
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
          ],
        ],
      );
    }
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
          focusedBorderColor: Theme.of(context).colorScheme.onPrimary,
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
