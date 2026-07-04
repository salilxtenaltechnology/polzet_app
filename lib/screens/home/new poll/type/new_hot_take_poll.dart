// ignore_for_file: deprecated_member_use, use_build_context_synchronously

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

import '../../../../api/app_api.dart';
import '../../../../api/services/image/image_picker_service.dart';
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

class NewHotTakePoll extends StatefulWidget {
  const NewHotTakePoll({super.key});

  @override
  State<NewHotTakePoll> createState() => _NewHotTakePollState();
}

class _NewHotTakePollState extends State<NewHotTakePoll> {
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final _dio = Dio();
  bool isLoading = false;
  String questionErrorText = '';
  File? _image;

  @override
  void dispose() {
    questionController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
          _image = finalFile;
        });
      }
    } catch (e) {
      showToast(message: 'Error picking image: ${e.toString()}');
    }
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
      appBar: const CommonAppBar(title: 'Share a Hot Take'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10.h),
              Text(
                'Post bold opinions, spark debates, and hear both sides',
                style: AppTextStyles.subText.copyWith(
                  fontSize: 14,
                  color: txt.body,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'Your hot take',
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              SizedBox(height: 7.h),
              SecondryTextfield(
                controller: questionController,
                hintText: 'Type question or topic',
                onChanged: (value) {
                  if (questionErrorText.isNotEmpty && value.trim().isNotEmpty) {
                    setState(() {
                      questionErrorText = '';
                    });
                  }
                },
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
                minLines: 3,
              ),
              SizedBox(height: 20.h),
              Text(
                '${AppLocalizations.of(context)!.addimage} (Optional)',
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              SizedBox(height: 7.h),
              _buildImageSelector(context),
              SizedBox(height: 20.h),
              Text(
                'Reactions',
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
      onTap: _pickImage,
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
                        top: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: _removeImage,
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
