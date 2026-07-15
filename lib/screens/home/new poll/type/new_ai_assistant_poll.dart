// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../api/app_api.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';
import '../../../../widgets/text_field/secondry_textfield.dart';

class PopularTopic {
  final String title;
  final AssetGenImage image;

  const PopularTopic({required this.title, required this.image});
}

class NewAiAssistantPoll extends StatefulWidget {
  const NewAiAssistantPoll({super.key});

  @override
  State<NewAiAssistantPoll> createState() => _NewAiAssistantPollState();
}

class _NewAiAssistantPollState extends State<NewAiAssistantPoll> {
  final _dio = Dio();
  final TextEditingController questionController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final List<TextEditingController> optionControllers = [];

  // State
  bool isEditing = false;
  bool _isLoading = false;
  String questionErrorText = '';
  String optionsErrorText = '';



  final List<PopularTopic> popularTopics = [
    PopularTopic(title: 'Fashion', image: Assets.images.icFashion),
    PopularTopic(title: 'Movies', image: Assets.images.icMovie),
    PopularTopic(title: 'Books', image: Assets.images.icBook),
    PopularTopic(title: 'Food', image: Assets.images.icFood),
    PopularTopic(title: 'Gaming', image: Assets.images.icGame),
    PopularTopic(title: 'Technology', image: Assets.images.icTechnology),
    PopularTopic(title: 'Travel', image: Assets.images.icTravel),
    PopularTopic(title: 'Sports', image: Assets.images.icSports),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize 4 options
    for (int i = 0; i < 4; i++) {
      optionControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    questionController.dispose();
    descriptionController.dispose();
    for (var controller in optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Suggest initial question, options, description based on topic
  void _generatePollData(String topic) {
    if (topic.trim().isEmpty) return;

    setState(() {
      questionController.text = topic;
      isEditing = true;
    });
  }

  // Get list of non-empty options
  List<String> _getValidOptions() {
    return optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .map((controller) => controller.text.trim())
        .toList();
  }

  // Validate fields before API post
  bool _validateInputs() {
    bool isValid = true;

    if (questionController.text.trim().isEmpty) {
      setState(() {
        questionErrorText = AppLocalizations.of(context)!.pleaseenteraquestion;
      });
      isValid = false;
    } else {
      setState(() {
        questionErrorText = '';
      });
    }

    final validOptions = _getValidOptions();
    if (validOptions.length < 2) {
      setState(() {
        optionsErrorText = AppLocalizations.of(context)!.pleaseenteratleasttwooptions;
      });
      isValid = false;
    } else {
      setState(() {
        optionsErrorText = '';
      });
    }

    return isValid;
  }

  // Create poll post via API
  Future<void> addPoll() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);

    try {
      final accessToken = await SharedPrefService.getToken();
      final validOptions = _getValidOptions();

      final formData = FormData.fromMap({
        "question": questionController.text.trim(),
        "description": descriptionController.text.trim(),
        "poll_type": "text",
        "voting_type": "ranking",
        "max_options": validOptions.length.toString(),
      });

      for (var option in validOptions) {
        formData.fields.add(MapEntry('poll_options', option));
      }

      final response = await _dio.post(
        ApiConstants.userPosts,
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showToast(message: 'New AI suggested poll created!');
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
    String errorMsg = 'Error processing request';
    if (e.response != null) {
      final errorData = e.response?.data;
      final errors = errorData?['errors'];
      if (errors != null) {
        if (errors['poll_options'] != null) {
          errorMsg = errors['poll_options'].toString();
        } else if (errors['question'] != null) {
          errorMsg = errors['question'].toString();
        } else if (errors['description'] != null) {
          errorMsg = errors['description'].toString();
        }
      } else {
        errorMsg = errorData?['message']?.toString() ?? 'Error: ${e.response?.statusMessage}';
      }
    } else {
      errorMsg = 'Connection error: ${e.message}';
    }
    showToast(message: errorMsg);
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final hasTopic = questionController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Create with Polzet AI'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text(
                'Enter a topic and let AI suggest questions, options, and ideas instantly',
                style: AppTextStyles.subText.copyWith(
                  fontSize: 14,
                  color: txt.body,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 25.h),

              if (!isEditing) ...[
                // --- Topic Selection Mode (State A) ---
                Text(
                  'What do you want to create today?',
                  style: CustomTextStyles.lblPrimaryText(context),
                ),
                SizedBox(height: 7.h),
                SecondryTextfield(
                  controller: questionController,
                  hintText: 'Type question or topic',
                  onChanged: (val) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 5),
                Text(
                  'Add topic (e.g. fashion, gaming, food)',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12,
                    color: txt.muted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 15.h),
                Text('Popular', style: CustomTextStyles.lblPrimaryText(context)),
                SizedBox(height: 12.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: popularTopics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 16.h,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final topic = popularTopics[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          questionController.text = topic.title;
                          questionController.selection = TextSelection.fromPosition(
                            TextPosition(offset: topic.title.length),
                          );
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 56.h,
                            width: 56.h,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.08),
                            ),
                            child: Center(
                              child: topic.image.image(
                                width: 24.h,
                                height: 24.h,
                                color: Theme.of(context).colorScheme.primary,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            topic.title,
                            style: AppTextStyles.subText.copyWith(
                              fontSize: 12.8,
                              color: txt.body,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                // --- Edit Form Mode (State B) ---
                
                // Question Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question',
                      style: CustomTextStyles.lblPrimaryText(context),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        children: [
                          Assets.images.icAssistant.image(
                            width: 14.w,
                            height: 14.h,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Generate Question',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimary)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 7.h),
                SecondryTextfield(
                  controller: questionController,
                  hintText: 'Type question',
                  onChanged: (val) {
                    if (questionErrorText.isNotEmpty && val.trim().isNotEmpty) {
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

                // Description & Hashtags Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Description & Hashtags',
                      style: CustomTextStyles.lblPrimaryText(context),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'Generate Description',
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.transparent
                        )
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 7.h),
                SecondryTextfield(
                  controller: descriptionController,
                  hintText: 'Type description or hashtags',
                  maxLines: 5,
                  minLines: 3,
                ),
                SizedBox(height: 20.h),

                // Options Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Options',
                      style: CustomTextStyles.lblPrimaryText(context),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        children: [
                           Assets.images.icAssistant.image(
                            width: 14.w,
                            height: 14.h,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Generate Options',
                            style: AppTextStyles.bodyText.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onPrimary)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                ...List.generate(4, (index) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 15.h),
                    child: SecondryTextfield(
                      controller: optionControllers[index],
                      hintText: 'Option ${index + 1}',
                      onChanged: (val) {
                        if (optionsErrorText.isNotEmpty) {
                          final validCount = _getValidOptions().length;
                          if (validCount >= 2) {
                            setState(() {
                              optionsErrorText = '';
                            });
                          }
                        }
                      },
                    ),
                  );
                }),
                if (optionsErrorText.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h, bottom: 10.h),
                    child: Text(
                      optionsErrorText,
                      style: CustomTextStyles.msgErrorText(context),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: isEditing
          ? BottomAppBar(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              height: 70.h,
              color: Theme.of(context).colorScheme.background,
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  title: 'Create Poll',
                  onPressed: _isLoading ? null : addPoll,
                  isLoading: _isLoading,
                ),
              ),
            )
          : BottomAppBar(
              padding: EdgeInsets.zero,
              height: 70.h,
              color: Theme.of(context).colorScheme.background,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: EdgeInsets.only(left: 20.w),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Create manually',
                            style: AppTextStyles.subText.copyWith(
                              fontSize: 14,
                              color: txt.body,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Opacity(
                      opacity: hasTopic ? 1.0 : 0.4,
                      child: PrimaryButton(
                        title: 'Continue',
                        onPressed: hasTopic ? () => _generatePollData(questionController.text) : null,
                        isLoading: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
