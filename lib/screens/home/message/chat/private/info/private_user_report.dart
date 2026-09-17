// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/widgets/button/primary_button.dart';

import '../../../../../../api/api_service.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/bottomsheets/report/report_submitted_bottom_sheet.dart';
import '../../../../../../widgets/show_toast.dart';

class PrivateUserReport extends StatefulWidget {
  final dynamic userId;
  final bool isReported;

  const PrivateUserReport({
    super.key,
    this.userId,
    this.isReported = false,
  });

  @override
  State<PrivateUserReport> createState() => _PrivateUserReportState();
}

class _PrivateUserReportState extends State<PrivateUserReport> {
  final _apiService = ApiService();
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reportReasons = const [
    'Spam Or Misleading',
    'Harassment Or Bullying',
    'Hate Or Hateful Content',
    'Sexual Or Inappropriate Content',
    'Violence Or Dangerous Content',
    'Scam Or Fraud',
    'Something Else',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isReported) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          await showReportSubmittedBottomSheet(context);
          if (mounted) {
            Navigator.pop(context);
          }
        }
      });
    }
  }

  String _getReasonKey(String reason) {
    switch (reason) {
      case 'Spam Or Misleading':
        return 'spam';
      case 'Harassment Or Bullying':
        return 'harassment';
      case 'Hate Or Hateful Content':
        return 'hate';
      case 'Sexual Or Inappropriate Content':
        return 'sexual';
      case 'Violence Or Dangerous Content':
        return 'violence';
      case 'Scam Or Fraud':
        return 'scam';
      case 'Something Else':
        return 'other';
      default:
        return 'spam';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null || _isSubmitting) return;

    final targetUserId = widget.userId?.toString();
    if (targetUserId == null || targetUserId.isEmpty) {
      showToast(message: 'User ID is missing');
      return;
    }

    final reason = _getReasonKey(_selectedReason!);
    final details = _detailsController.text.trim().isNotEmpty
        ? _detailsController.text.trim()
        : 'User report';
    const severity = 'medium';

    setState(() => _isSubmitting = true);

    try {
      await _apiService.reportUserProfile(
        userId: targetUserId,
        reason: reason,
        details: details,
        severity: severity,
      );

      if (mounted) {
        await showReportSubmittedBottomSheet(context);
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error reporting user: $e');
      showToast(message: 'Failed to submit report: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Report User'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section Title ─────────────────────────────────────────────────
            Text(
              'Why are you reporting this user?',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: txt.title,
              ),
            ),
            SizedBox(height: 8.h),

            // ── Reasons List ──────────────────────────────────────────────────
            ..._reportReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 7.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          reason,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                            color: txt.title,
                          ),
                        ),
                      ),
                      Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryColor
                                : txt.body,
                            width: 1,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 11.w,
                                  height: 11.w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── Something Else Additional Details (Conditional) ───────────────
            if (_selectedReason == 'Something Else') ...[
              SizedBox(height: 10.h),
              RichText(
                text: TextSpan(
                  text: 'Tell us more about ',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.2.sp,
                    fontWeight: FontWeight.w500,
                    color: txt.title,
                  ),
                  children: [
                    TextSpan(
                      text: '(optional)',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14.sp,
                        color: txt.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.background,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _detailsController,
                  maxLines: 5,
                  minLines: 4,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.5.sp,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Add more additional details, this will help us to review your report',
                    hintStyle: AppTextStyles.bodyText.copyWith(
                      fontSize: 13.5,
                      color: const Color(0XFFB3B3B3),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(10.w),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 25),
        height: 90,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: 'Submit Report',
          onPressed:
              (_selectedReason != null && !_isSubmitting) ? _submitReport : null,
          isLoading: _isSubmitting,
        ),
      ),
    );
  }
}
