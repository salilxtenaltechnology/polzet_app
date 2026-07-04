// ignore_for_file: unused_field, deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/loader.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  String? selectedCategory;
  int starRating = 0;
  int hoverRating = 0;
  bool isSubmitting = false;

  // Screenshot
  File? _screenshotFile;
  bool _isPickingImage = false;

  // Issue ID from response
  String? _submittedIssueId;

  final _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late AnimationController _submitController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _submitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    _fadeController.dispose();
    _submitController.dispose();
    super.dispose();
  }

  // ── Pick Screenshot ───────────────────────────────────────
  Future<void> _pickScreenshot() async {
    setState(() => _isPickingImage = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked == null) return;

      final file = File(picked.path);
      final int sizeInBytes = await file.length();
      if (!mounted) return;

      if (sizeInBytes > 3 * 1024 * 1024) {
        showToast(message: 'Screenshot must be under 3 MB');
        return;
      }

      if (!mounted) return;
      setState(() {
        _screenshotFile = file;
      });
    } catch (e) {
      if (!mounted) return;
      showToast(message: 'Failed to pick image');
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _removeScreenshot() {
    setState(() {
      _screenshotFile = null;
    });
  }

  Map<String, String> _getDeviceInfo() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final w = view.physicalSize.width.toInt();
    final h = view.physicalSize.height.toInt();
    return {
      'browser': 'Flutter App',
      'os': Platform.operatingSystem,
      'screen_resolution': '${w}x$h',
      'user_agent': 'Polzet Flutter/${Platform.operatingSystemVersion}',
    };
  }

  Future<void> _submitFeedback() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String email = (userProvider.email?.isNotEmpty == true)
        ? userProvider.email!
        : await SharedPrefService.getEmail() ?? '';
    final deviceInfo = _getDeviceInfo();
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategory == null) {
      showToast(message: 'Please select a category');
      return;
    }
    if (starRating == 0) {
      showToast(message: 'Please give a rating');
      return;
    }

    setState(() => isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await ApiService().submitFeedback(
        email: email,
        subject: subjectController.text.trim(),
        category: selectedCategory!,
        message: messageController.text.trim(),
        rating: starRating,
        reaction: _getRatingEmoji(),
        screenshotFile: _screenshotFile,
        deviceInfo: deviceInfo,
      );

      if (!mounted) return;

      if (result['status'] == true) {
        final issueId = result['data']?['issue_id'] as String? ?? '';
        setState(() => _submittedIssueId = issueId);
        showToast(message: 'Thank you for helping improve Polzet ❤️');
        subjectController.clear();
        messageController.clear();
        setState(() {
          selectedCategory = null;
          starRating = 0;
          _screenshotFile = null;
        });
      } else {
        showToast(message: 'Something went wrong.');
      }
    } catch (e) {
      if (!mounted) return;
      showToast(message: e.toString());
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  String _getRatingEmoji() {
    switch (starRating) {
      case 1:
        return '😡';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '🤩';
      default:
        return '😐';
    }
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.sharefeedback,
        showBackButton: true,
      ),

      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12).w,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Issue ID Banner (shown after submit) ──
                    if (_submittedIssueId != null &&
                        _submittedIssueId!.isNotEmpty) ...[
                      _buildIssueIdBanner(),
                      SizedBox(height: 12.h),
                    ],

                    // ── Rating Card ──
                    _buildRatingCard(),
                    SizedBox(height: 12.h),

                    // ── Subject Field ──
                    _buildLabel(AppLocalizations.of(context)!.subject),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: subjectController,
                      hint: AppLocalizations.of(
                        context,
                      )!.egAppissueloginproblem,
                      maxLines: 1,
                      validator: (v) => v == null || v.isEmpty
                          ? AppLocalizations.of(context)!.subjectisrequired
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Category ──
                    _buildLabel(AppLocalizations.of(context)!.category),
                    const SizedBox(height: 8),
                    _buildCategorySelector(),
                    const SizedBox(height: 20),

                    // ── Message ──
                    _buildLabel(AppLocalizations.of(context)!.message),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: messageController,
                      hint: AppLocalizations.of(
                        context,
                      )!.describeyourissueorsuggestionindetails,
                      maxLines: 5,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return AppLocalizations.of(
                            context,
                          )!.messageisrequired;
                        }
                        if (v.length < 10) {
                          return AppLocalizations.of(
                            context,
                          )!.messagemustbeatleasttencharacters;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Char Count ──
                    Align(
                      alignment: Alignment.centerRight,
                      child: ValueListenableBuilder(
                        valueListenable: messageController,
                        builder: (_, __, ___) => Text(
                          '${messageController.text.length} ${AppLocalizations.of(context)!.characters}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Screenshot ──
                    _buildLabel(AppLocalizations.of(context)!.screenshotsoptional),
                    const SizedBox(height: 8),
                    _buildScreenshotPicker(),
                    const SizedBox(height: 32),

                    // ── Submit Button ──
                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Issue ID Banner ───────────────────────────────────────
  Widget _buildIssueIdBanner() {
    final txt = AppTextColors.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 20,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue Submitted',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: txt.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Issue ID: $_submittedIssueId',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: txt.body,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _submittedIssueId!));
              showToast(message: 'Issue ID copied!');
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.copy_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Screenshot Picker ─────────────────────────────────────
  Widget _buildScreenshotPicker() {
    final txt = AppTextColors.of(context);
    if (_screenshotFile != null) {
      return Stack(
        children: [
          Container(
            height: 160.h,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(_screenshotFile!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeScreenshot,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFE53E3E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isPickingImage ? null : _pickScreenshot,
      child: Container(
        width: double.infinity,
        height: 100.h,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: _isPickingImage
            ? Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Loader(color: Theme.of(context).colorScheme.onPrimary),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: txt.muted,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Attach screenshot (PNG/JPEG, max 3MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: txt.muted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Rating Card Widget ────────────────────────────────────
  Widget _buildRatingCard() {
    final txt = AppTextColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.howwouldyourateyourexperince,
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: txt.title,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isFilled =
                  starIndex <= (hoverRating > 0 ? hoverRating : starRating);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => starRating = starIndex);
                },
                onTapDown: (_) => setState(() => hoverRating = starIndex),
                onTapUp: (_) => setState(() => hoverRating = 0),
                onTapCancel: () => setState(() => hoverRating = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: hoverRating == starIndex ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isFilled
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 42,
                      color: isFilled
                          ? const Color(0xFFFFB800)
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _getRatingLabel(),
              key: ValueKey(starRating),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _getRatingColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel() {
    switch (starRating) {
      case 1:
        return '😡 ${AppLocalizations.of(context)!.broken}';
      case 2:
        return '😕 ${AppLocalizations.of(context)!.confusing}';
      case 3:
        return '😐 ${AppLocalizations.of(context)!.okay}';
      case 4:
        return '🙂 ${AppLocalizations.of(context)!.good}';
      case 5:
        return '🤩 ${AppLocalizations.of(context)!.loveit}';
      default:
        return AppLocalizations.of(context)!.tapastartorate;
    }
  }

  Color _getRatingColor() {
    final txt = AppTextColors.of(context);
    switch (starRating) {
      case 1:
        return const Color(0xFFE53E3E);
      case 2:
        return const Color(0xFFED8936);
      case 3:
        return const Color(0xFFD69E2E);
      case 4:
        return const Color(0xFF38A169);
      case 5:
        return AppColors.primaryColor;
      default:
        return txt.muted;
    }
  }

  // ── Label Widget ─────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onBackground,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── TextField Widget ──────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    String? Function(String?)? validator,
  }) {
    final txt = AppTextColors.of(context);
    return TextFormField(
      controller: controller,
      cursorColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
      cursorWidth: 1.5,
      maxLines: maxLines,
      validator: validator,
      style: AppTextStyles.bodyText.copyWith(
        color: txt.title,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyText.copyWith(
          color: const Color(0XFF898989),
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.all(16),
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(11),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 0.7,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final List<Map<String, String>> feedbackOptions = [
      {'value': 'bug', 'label': AppLocalizations.of(context)!.bugreport},
      {
        'value': 'suggestion',
        'label': AppLocalizations.of(context)!.featurerequest,
      },
      {'value': 'ui', 'label': AppLocalizations.of(context)!.uiissue},
      {
        'value': 'performance',
        'label': AppLocalizations.of(context)!.perfomance,
      },
      {'value': 'general', 'label': AppLocalizations.of(context)!.general},
      {'value': 'complaint', 'label': AppLocalizations.of(context)!.complaint},
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          hint: Text(
            AppLocalizations.of(context)!.complaint,
            style: AppTextStyles.bodyText.copyWith(
              color: const Color(0XFF898989),
              fontWeight: FontWeight.w400,
              fontSize: 13.5,
            ),
          ),
          dropdownColor: Theme.of(context).colorScheme.tertiaryContainer,
          isExpanded: true,
          items: feedbackOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['value'],
              child: Text(
                opt['label']!,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => selectedCategory = newValue);
            }
          },
          iconEnabledColor: const Color(0XFF898989),
        ),
      ),
    );
  }

  // ── Submit Button ─────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitFeedback,
        style:
            ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.6),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.all(
                Colors.white.withOpacity(0.1),
              ),
            ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isSubmitting
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  key: const ValueKey('submit'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(context)!.submitfeedback,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
