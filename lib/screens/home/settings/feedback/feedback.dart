// ignore_for_file: unused_field, deprecated_member_use
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';

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
      _screenshotFile = file;   // ✅ just store the File
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

  // ── Get device info ───────────────────────────────────────
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

  // ── Submit ────────────────────────────────────────────────
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

    // Capture context-dependent values BEFORE any await

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

      if (!mounted) return; // ← guard after await

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
      if (!mounted) return; // ← guard after await in catch
      showToast(message: e.toString());
    } finally {
      if (mounted) setState(() => isSubmitting = false); // ← guard in finally
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: const PrimaryBackButton(),
        title: Text(
          AppLocalizations.of(context)!.sharefeedback,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
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
                      _buildLabel('Screenshot (Optional)'),
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
      ),
    );
  }

  // ── Issue ID Banner ───────────────────────────────────────
  Widget _buildIssueIdBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              color: AppColors.primaryColor,
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
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Issue ID: $_submittedIssueId',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A2E),
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
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Screenshot Picker ─────────────────────────────────────
  Widget _buildScreenshotPicker() {
    if (_screenshotFile != null) {
      return Stack(
        children: [
          Container(
            height: 160.h,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            style: BorderStyle.solid,
          ),
        ),
        child: _isPickingImage
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryColor,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Attach screenshot (PNG/JPEG, max 3MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            AppLocalizations.of(context)!.howwouldyourateyourexperince,
            style: TextStyle(
              fontSize: 11.2.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
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
              style: TextStyle(
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
        return Colors.grey;
    }
  }

  // ── Label Widget ─────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1A2E),
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A2E),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 1),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          hint: Text(
            AppLocalizations.of(context)!.complaint,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          dropdownColor: Colors.white,
          isExpanded: true,
          items: feedbackOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['value'],
              child: Text(
                opt['label']!,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => selectedCategory = newValue);
            }
          },
          iconEnabledColor: Colors.grey.shade400,
        ),
      ),
    );
  }

  // ── Submit Button ─────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 32.h,
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
                borderRadius: BorderRadius.circular(16),
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
