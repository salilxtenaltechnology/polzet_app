// ignore_for_file: unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
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

  final _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late AnimationController _submitController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _submitAnimation;

  final List<Map<String, dynamic>> categories = [
    {'value': 'bug', 'label': 'Bug Report', 'icon': Icons.bug_report_rounded},
    {
      'value': 'suggestion',
      'label': 'Suggestion',
      'icon': Icons.lightbulb_rounded,
    },
    {'value': 'general', 'label': 'General', 'icon': Icons.chat_bubble_rounded},
    {'value': 'complaint', 'label': 'Complaint', 'icon': Icons.warning_rounded},
  ];

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
    _submitAnimation = CurvedAnimation(
      parent: _submitController,
      curve: Curves.easeInOut,
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

  Future<void> _submitFeedback() async {
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
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final String email = userProvider.user?.email ?? '';

      final result = await ApiService().submitFeedback(
        email: email,
        subject: subjectController.text.trim(),
        category: selectedCategory!,
        message: messageController.text.trim(),
        rating: starRating,
      );

      if (result['status'] == true) {
        showToast(message: 'Feedback submitted successfully!');

        // Clear form
        subjectController.clear();
        messageController.clear();
        setState(() {
          selectedCategory = null;
          starRating = 0;
        });
      } else {
        showToast(message: 'Something went wrong.');
      }
    } catch (e) {
      showToast(message: e.toString());
    } finally {
      setState(() => isSubmitting = false);
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
                            return AppLocalizations.of(context)!.messageisrequired;
                          }
                          if (v.length < 10) {
                            return AppLocalizations.of(context)!.messagemustbeatleasttencharacters;
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
        return '😞 ${AppLocalizations.of(context)!.broken}';
      case 2:
        return '😕 ${AppLocalizations.of(context)!.confusing}';
      case 3:
        return '😐 ${AppLocalizations.of(context)!.okay}';
      case 4:
        return '😊 ${AppLocalizations.of(context)!.good}';
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
  final List<String> feedbackOptions = [
    AppLocalizations.of(context)!.bugreport,
    AppLocalizations.of(context)!.featurerequest,
    AppLocalizations.of(context)!.uiissue,
    AppLocalizations.of(context)!.perfomance,
    AppLocalizations.of(context)!.general,
    AppLocalizations.of(context)!.complaint,
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
        items: feedbackOptions.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(
              option,
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
 



//  colors: [AppColors.primaryColor,Color(0xFFE93A5D)],