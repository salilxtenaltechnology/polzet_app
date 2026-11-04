// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../api/services/image/image_picker_service.dart';
import '../../../../api/services/image/image_preview_crop_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/dotted_border/dotted_border.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import 'preview_post.dart';
import 'reorder_image.dart';

class HashtagTextEditingController extends TextEditingController {
  HashtagTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final bool hasComposing = withComposing && value.isComposingRangeValid;
    if (hasComposing || !text.contains('#')) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final RegExp exp = RegExp(r'(#[a-zA-Z0-9_]+)');
    final List<TextSpan> spans = [];

    text.splitMapJoin(
      exp,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: (style ?? const TextStyle()).copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          spans.add(
            TextSpan(
              text: nonMatch,
              style: style,
            ),
          );
        }
        return '';
      },
    );

    return TextSpan(style: style, children: spans);
  }
}

class CreatePost extends StatefulWidget {
  const CreatePost({super.key});

  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost>
    with UtilityMixin, WidgetsBindingObserver {
  static const int maxImages = 10;
  final TextEditingController _captionController =
      HashtagTextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final ApiService _apiService = ApiService();
  List<File> _selectedImages = [];
  int _selectedPreviewIndex = 0;
  bool _isLoading = false;
  bool _wasKeyboardVisible = false;

  final _categoryLayerLink = LayerLink();
  final GlobalKey _categoryFieldKey = GlobalKey();
  OverlayEntry? _categoryOverlayEntry;
  bool _isCategoryDropdownOpen = false;
  double _categoryFieldWidth = 0;
  final _categorySearchController = TextEditingController();
  final FocusNode _categorySearchFocusNode = FocusNode();

  String? _selectedCategory;
  final List<String> _suggestedHashtags = [
    'travel',
    'weekend',
    'explore',
    'polzet',
    'trending',
  ];

  final List<String> _categories = [
    'AI & Tech',
    'Current Affairs',
    'Education',
    'Fashion',
    'Finance',
    'Fitness',
    'Food',
    'Gaming',
    'Memes',
    'Movies',
    'Music',
    'Relationships',
    'Sports',
    'Technology',
    'Travel',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _captionController.addListener(_onCaptionChanged);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;

    final isKeyboardVisible = views.first.viewInsets.bottom > 0;

    if (_wasKeyboardVisible && !isKeyboardVisible) {
      _captionFocusNode.unfocus();
    }

    if (_isCategoryDropdownOpen) {
      _categoryOverlayEntry?.markNeedsBuild();
    }

    _wasKeyboardVisible = isKeyboardVisible;
  }

  void _onCaptionChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _categoryOverlayEntry?.remove();
    _categoryOverlayEntry = null;
    _categorySearchController.dispose();
    _categorySearchFocusNode.dispose();

    _captionController.removeListener(_onCaptionChanged);
    _captionController.dispose();
    _captionFocusNode.dispose();

    super.dispose();
  }

  bool get _canOpenPreview =>
      _captionController.text.trim().isNotEmpty && _selectedImages.isNotEmpty;

  Future<void> _onTapPreview() async {
    _closeCategoryDropdown();
    if (_captionController.text.trim().isEmpty) {
      showToast(message: 'Please enter a caption');
      return;
    }
    if (_selectedImages.isEmpty) {
      showToast(message: 'Please select at least one image');
      return;
    }
    final result = await navigationPush(
      context,
      PreviewPost(
        caption: _captionController.text.trim(),
        selectedImages: _selectedImages,
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _publishPost() async {
    _closeCategoryDropdown();
    if (_isLoading) return;

    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      showToast(message: 'Please enter a caption');
      return;
    }
    if (_selectedImages.isEmpty) {
      showToast(message: 'Please select at least one image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.createSocialPost(
        description: caption,
        images: _selectedImages,
        category: _selectedCategory,
      );

      if (!mounted) return;

      showToast(message: 'Post created successfully!');
      Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadUserDataSilently(force: true);

      Navigator.of(context).pop(response);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();
      showToast(
        message: errorMsg.isNotEmpty ? errorMsg : 'Failed to create post',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        setState(() {
          _selectedImages.addAll(pickedFiles);
          if (_selectedImages.length > maxImages) {
            _selectedImages = _selectedImages.sublist(0, maxImages);
          }
          _selectedPreviewIndex = _selectedImages.length - 1;
        });
      }
    } catch (e) {
      showToast(message: 'Error picking images: ${e.toString()}');
    }
  }

  Future<void> _openPreviewCropScreen([int startIndex = 0]) async {
    if (_selectedImages.isEmpty) return;

    final List<File>? finalFiles = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewCropScreen(
          initialImages: _selectedImages,
          initialIndex: startIndex,
          maxImages: maxImages,
        ),
      ),
    );

    if (finalFiles != null && finalFiles.isNotEmpty && mounted) {
      setState(() {
        _selectedImages = List<File>.from(finalFiles);
        if (_selectedPreviewIndex >= _selectedImages.length) {
          _selectedPreviewIndex = _selectedImages.isEmpty
              ? 0
              : _selectedImages.length - 1;
        }
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
                    AppLocalizations.of(context)!.editimage,
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
                    AppLocalizations.of(context)!.cropimage,
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
                    AppLocalizations.of(context)!.replaceimage,
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
              if (_selectedImages.length > 1)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10),
                  child: GestureDetector(
                    child: Text(
                    AppLocalizations.of(context)!.reorder,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.body,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await navigationPush(
                        context,
                        ReorderImage(images: _selectedImages),
                      );
                      if (result != null && result is List<File> && mounted) {
                        setState(() {
                          _selectedImages = List<File>.from(result);
                          if (_selectedPreviewIndex >= _selectedImages.length) {
                            _selectedPreviewIndex = _selectedImages.isEmpty
                                ? 0
                                : _selectedImages.length - 1;
                          }
                        });
                      }
                    },
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10),
                child: GestureDetector(
                  child: Text(
                    AppLocalizations.of(context)!.remove,
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
        setState(() {
          _selectedImages[index] = pickedFiles[0];
        });
      }
    } catch (e) {
      showToast(message: 'Error replacing image: ${e.toString()}');
    }
  }

  void _removeImage(int index) {
    if (index >= 0 && index < _selectedImages.length) {
      setState(() {
        _selectedImages.removeAt(index);
        if (_selectedPreviewIndex >= _selectedImages.length) {
          _selectedPreviewIndex = _selectedImages.isEmpty
              ? 0
              : _selectedImages.length - 1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.createpost,
        showBackButton: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _closeCategoryDropdown();
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.h, vertical: 5),
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.sharedphotosandthoughtswithyourscommunity,
                  style: AppTextStyles.subText.copyWith(
                    fontSize: 14,
                    color: txt.body,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              _selectedImages.isEmpty
                  ? _buildEmptyImagePicker(context)
                  : _buildSelectedImagesPreview(context),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.caption,
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _captionController,
                focusNode: _captionFocusNode,
                autofocus: false,
                hint: AppLocalizations.of(context)!.whatsonyourmind,
                maxLines: 7,
                maxLength: 1000,
                keyboardType: TextInputType.multiline,
                isReadOnly: false,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _suggestedHashtags
                      .map((tag) => _buildHashtags(hashtags: tag))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.category,
                style: CustomTextStyles.lblPrimaryText(context),
              ),
              const SizedBox(height: 10),
              _buildCategoryField(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        height: 70.h,
        color: Theme.of(context).colorScheme.background,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _onTapPreview,
                child: Container(
                  padding: const EdgeInsets.only(left: 15, top: 12),
                  height: 50,
                  color: Colors.transparent,
                  child: Text(
                    AppLocalizations.of(context)!.preview,
                    style: AppTextStyles.bodyText.copyWith(
                      color: _canOpenPreview && !_isLoading
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _isLoading ? null : _publishPost,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? AppColors.primaryColor.withOpacity(0.6)
                        : AppColors.primaryColor,
                    borderRadius: AppRadius.buttonRadius,
                  ),
                  child: Center(
                    child: _isLoading
                        ? Loader(color: Colors.white)
                        : Text(
                            AppLocalizations.of(context)!.publishpoll,
                            style: AppTextStyles.bodyText.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
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

  Widget _buildEmptyImagePicker(BuildContext context) {
    return GestureDetector(
      onTap: _pickImages,
      child: SizedBox(
        width: double.infinity,
        height: 180.h,
        child: CustomPaint(
          painter: DottedBorderPainter(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
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

  Widget _buildSelectedImagesPreview(BuildContext context) {
    if (_selectedPreviewIndex >= _selectedImages.length) {
      _selectedPreviewIndex = _selectedImages.isEmpty
          ? 0
          : _selectedImages.length - 1;
    }
    final activeImage = _selectedImages[_selectedPreviewIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Image Preview
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => _openPreviewCropScreen(_selectedPreviewIndex),
                child: SizedBox(
                  width: double.infinity,
                  height: 200.h,
                  child: Image.file(
                    activeImage,
                    fit: BoxFit.cover,
                    key: ValueKey('${activeImage.path}_$_selectedPreviewIndex'),
                  ),
                ),
              ),
              Positioned(
                top: 8.h,
                right: 8.w,
                child: GestureDetector(
                  onTap: () => _onTapEditImage(_selectedPreviewIndex),
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.edit, color: Colors.white, size: 13.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // Thumbnails + Dotted '+' Add Button Row
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount:
                _selectedImages.length +
                (_selectedImages.length < maxImages ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(width: 10.w),
            itemBuilder: (context, index) {
              if (index < _selectedImages.length) {
                final isSelected = index == _selectedPreviewIndex;
                final file = _selectedImages[index];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPreviewIndex = index;
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 65,
                        height: 70,
                        padding: isSelected ? const EdgeInsets.all(1) : null,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  width: 1.2,
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            width: 64.w,
                            height: 64.w,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 3.w,
                        right: 5.w,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _removeImage(index),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.close,
                                size: 11.5,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                // Add more images button
                return GestureDetector(
                  onTap: _pickImages,
                  child: SizedBox(
                    width: 65,
                    height: 70,
                    child: CustomPaint(
                      painter: DottedBorderPainter(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                        strokeWidth: 1.5,
                        gap: 4,
                        borderRadius: 7,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.9),
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isReadOnly,
    FocusNode? focusNode,
    bool autofocus = false,
    TextInputType keyboardType = TextInputType.text,
    String errorText = '',
    int? maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool showFocusBorder = true,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final effectiveShowFocusBorder =
        showFocusBorder && (!isReadOnly || controller.text.trim().isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: maxLines == 1 ? 48 : null,
          child: TextField(
            readOnly: isReadOnly,
            autofocus: autofocus,
            focusNode: focusNode,
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            minLines: 3,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: AppTextStyles.subText.copyWith(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.w400,
            ),
            buildCounter: maxLength != null
                ? (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$currentLength/$maxLength',
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 12,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    );
                  }
                : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.subText.copyWith(
                fontSize: 14,
                color: const Color(0XFF898989),
                fontWeight: FontWeight.w400,
              ),
              contentPadding: const EdgeInsets.all(12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: BorderSide(
                  color: errorText.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  effectiveShowFocusBorder ? 12 : AppRadius.card,
                ),
                borderSide: BorderSide(
                  color: errorText.isNotEmpty
                      ? Theme.of(context).colorScheme.error
                      : (!effectiveShowFocusBorder
                            ? Theme.of(context).colorScheme.outline
                            : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Theme.of(context).colorScheme.primary)),
                  width: !effectiveShowFocusBorder ? 1.5 : 1,
                ),
              ),
            ),
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  bool _isHashtagInCaption(String tag) {
    final pattern = RegExp(
      r'(?:^|\s)#' + RegExp.escape(tag) + r'(?:\s|$)',
      caseSensitive: false,
    );
    return pattern.hasMatch(_captionController.text);
  }

  void _onHashtagTapped(String tag) {
    final cleanTag = tag.replaceAll('#', '').trim();
    if (cleanTag.isEmpty) return;

    final String hashtag = '#$cleanTag';
    final String currentText = _captionController.text;

    if (_isHashtagInCaption(cleanTag)) {
      final String newText = _removeHashtag(currentText, cleanTag);
      _captionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else {
      String newText;
      if (currentText.trim().isEmpty) {
        newText = hashtag;
      } else {
        final trimmed = currentText.trimRight();
        final bool endsWithHashtag =
            RegExp(r'#[a-zA-Z0-9_]+$').hasMatch(trimmed);
        if (endsWithHashtag) {
          newText = '$trimmed $hashtag';
        } else {
          newText = '$trimmed\n$hashtag';
        }
      }

      if (newText.length > 1000) {
        showToast(message: 'Caption cannot exceed 1000 characters');
        return;
      }

      _captionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  String _removeHashtag(String text, String tag) {
    final escaped = RegExp.escape(tag);

    // 1. Preceded and followed by space: " #tag " -> " "
    final midPattern = RegExp(' #$escaped ', caseSensitive: false);
    if (midPattern.hasMatch(text)) {
      return text.replaceFirst(midPattern, ' ');
    }
    // 2. Start of line or preceded by newline, and followed by space: "\n#tag " -> "\n"
    final startOfLineWithNext = RegExp(
      r'(^|\n)#' + escaped + ' ',
      caseSensitive: false,
    );
    if (startOfLineWithNext.hasMatch(text)) {
      return text.replaceFirstMapped(
        startOfLineWithNext,
        (m) => m.group(1) ?? '',
      );
    }
    // 3. Preceded by space at end of line or string: " #tag" -> ""
    final endOfLinePattern = RegExp(
      r' #' + escaped + r'(?=\n|$)',
      caseSensitive: false,
    );
    if (endOfLinePattern.hasMatch(text)) {
      return text.replaceFirst(endOfLinePattern, '');
    }
    // 4. Alone on a new line: "\n#tag" -> ""
    final aloneOnNewLine = RegExp(
      r'\n#' + escaped + r'(?=\n|$)',
      caseSensitive: false,
    );
    if (aloneOnNewLine.hasMatch(text)) {
      return text.replaceFirst(aloneOnNewLine, '');
    }
    // 5. Alone at the start of string: "^#tag" -> ""
    final aloneAtStart = RegExp(
      r'^#' + escaped + r'(?:\n|$)',
      caseSensitive: false,
    );
    if (aloneAtStart.hasMatch(text)) {
      return text.replaceFirst(aloneAtStart, '');
    }
    return text
        .replaceAll(
          RegExp(r'#' + escaped + r'(?=\s|$)', caseSensitive: false),
          '',
        )
        .trimRight();
  }

  Widget _buildHashtags({required String hashtags}) {
    final cleanTag = hashtags.replaceAll('#', '').trim();
    final isSelected = _isHashtagInCaption(cleanTag);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onHashtagTapped(cleanTag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '#$cleanTag',
          style: AppTextStyles.bodyText.copyWith(
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Category Dropdown Overlay Logic ──────────────────────────────────────────
  void _toggleCategoryDropdown() {
    if (_isCategoryDropdownOpen) {
      _closeCategoryDropdown();
    } else {
      _openCategoryDropdown();
    }
  }

  void _openCategoryDropdown() {
    if (_categoryOverlayEntry != null) return;

    _categorySearchController.clear();

    _categoryOverlayEntry = OverlayEntry(
      builder: (context) {
        List<String> currentFiltered = List.from(_categories);

        return StatefulBuilder(
          builder: (context, setOverlayState) {
            final mediaQuery = MediaQuery.of(context);
            final keyboardHeight = mediaQuery.viewInsets.bottom;
            final screenHeight = mediaQuery.size.height;
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final txt = AppTextColors.of(context);

            // Calculate field's global position and available space above/below
            final renderBox =
                _categoryFieldKey.currentContext?.findRenderObject()
                    as RenderBox?;
            final fieldOffset = renderBox?.localToGlobal(Offset.zero);
            final fieldTop = fieldOffset?.dy ?? 0;
            final fieldHeight = renderBox?.size.height ?? 48.0;
            final fieldBottom = fieldTop + fieldHeight;

            final spaceBelow = screenHeight - keyboardHeight - fieldBottom;
            final spaceAbove =
                fieldTop - mediaQuery.padding.top - kToolbarHeight;

            // When keyboard is visible or space below is too tight, show above the field
            final bool showAbove =
                (keyboardHeight > 0 || spaceBelow < 250) &&
                (spaceAbove > spaceBelow);

            final double availableListHeight = showAbove
                ? (spaceAbove - 85).clamp(80.0, 220.0)
                : (spaceBelow - 85).clamp(80.0, 220.0);

            return Stack(
              children: [
                // Dismiss on outside tap
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _closeCategoryDropdown();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // Dropdown overlay menu positioned relative to dropdown field
                Positioned(
                  width: _categoryFieldWidth > 0
                      ? _categoryFieldWidth
                      : (mediaQuery.size.width - 24.w),
                  child: CompositedTransformFollower(
                    link: _categoryLayerLink,
                    showWhenUnlinked: false,
                    targetAnchor: showAbove
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
                    followerAnchor: showAbove
                        ? Alignment.bottomLeft
                        : Alignment.topLeft,
                    offset: Offset(0, showAbove ? -6 : 6),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? const Color(0xFF1F1F23)
                          : Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1F1F23)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search field inside dropdown menu
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2A2A2E)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _categorySearchController,
                                  focusNode: _categorySearchFocusNode,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 13.5,
                                    color: txt.title,
                                  ),
                                  onChanged: (q) {
                                    setOverlayState(() {
                                      if (q.trim().isEmpty) {
                                        currentFiltered = List.from(
                                          _categories,
                                        );
                                      } else {
                                        final query = q.toLowerCase().trim();
                                        currentFiltered = _categories.where((
                                          c,
                                        ) {
                                          return c.toLowerCase().contains(
                                            query,
                                          );
                                        }).toList();
                                      }
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!.searchcategory,
                                    hintStyle: AppTextStyles.bodyText.copyWith(
                                      fontSize: 13.5,
                                      color: const Color(0xFF898989),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 19,
                                      color: Color(0xFF898989),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 40,
                                    ),
                                    suffixIcon:
                                        _categorySearchController
                                            .text
                                            .isNotEmpty
                                        ? IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 34,
                                              minHeight: 40,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Color(0xFF898989),
                                            ),
                                            onPressed: () {
                                              _categorySearchController.clear();
                                              setOverlayState(() {
                                                currentFiltered = List.from(
                                                  _categories,
                                                );
                                              });
                                            },
                                          )
                                        : null,
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 40,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.only(
                                      right: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.5),
                            // Filtered category list
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: availableListHeight,
                              ),
                              child: currentFiltered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Text(
                                        'No category found',
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 13,
                                          color: txt.muted,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: currentFiltered.length,
                                      itemBuilder: (context, index) {
                                        final category = currentFiltered[index];
                                        final isSelected =
                                            category.toLowerCase() ==
                                            (_selectedCategory ?? '')
                                                .toLowerCase();

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedCategory = category;
                                            });
                                            _closeCategoryDropdown();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            color: isSelected
                                                ? (isDarkMode
                                                      ? const Color(0xFF2A2A2E)
                                                      : const Color(0xFFF0F0F0))
                                                : Colors.transparent,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    category,
                                                    style: AppTextStyles
                                                        .bodyText
                                                        .copyWith(
                                                          fontSize: 13.5,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                          color: txt.title,
                                                        ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_categoryOverlayEntry!);
    setState(() {
      _isCategoryDropdownOpen = true;
    });
  }

  void _closeCategoryDropdown() {
    _categorySearchFocusNode.unfocus();
    _categoryOverlayEntry?.remove();
    _categoryOverlayEntry = null;
    if (mounted) {
      setState(() {
        _isCategoryDropdownOpen = false;
      });
    }
  }

  Widget _buildCategoryField() {
    return LayoutBuilder(
      key: _categoryFieldKey,
      builder: (context, constraints) {
        _categoryFieldWidth = constraints.maxWidth;

        return CompositedTransformTarget(
          link: _categoryLayerLink,
          child: InkWell(
            onTap: _toggleCategoryDropdown,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              height: 48,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCategory ?? AppLocalizations.of(context)!.selectacategory,
                      style: _selectedCategory != null
                          ? AppTextStyles.bodyText.copyWith(
                              fontSize: 14.5,
                              color: Theme.of(context).colorScheme.onBackground,
                              fontWeight: FontWeight.w500,
                            )
                          : AppTextStyles.subText.copyWith(
                              fontSize: 14,
                              color: const Color(0XFF898989),
                              fontWeight: FontWeight.w400,
                            ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isCategoryDropdownOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
