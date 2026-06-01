// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../core/themes/app_text_styles.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import 'biometric_service.dart';

class EnableBiometricScreen extends StatefulWidget {
  const EnableBiometricScreen({super.key});

  @override
  State<EnableBiometricScreen> createState() => _EnableBiometricScreenState();
}

class _EnableBiometricScreenState extends State<EnableBiometricScreen>
    with SingleTickerProviderStateMixin {
  bool _isSuccess = false;
  bool _isLoading = false;
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _handleEnableFingerprint() async {
    setState(() => _isLoading = true);

    try {
      final isAuthenticated = await BiometricService.authenticateWithBiometrics(
        reason: 'Enable Fingerprint Security',
        useErrorDialogs: true,
        stickyAuth: true,
      );

      if (!mounted) return;

      if (isAuthenticated) {
        await BiometricService.saveFingerprintEnabled(true);

        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });

        _checkController.forward();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.fingerprint,
        showBackButton: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.3),
                        width: 0.7,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.fingerprint,
                    size: 50,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  if (_isSuccess)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: ScaleTransition(
                        scale: _checkScale,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 28.h),

            Text(
              AppLocalizations.of(context)!.usefingerprint,
              textAlign: TextAlign.center,
              style: AppTextStyles.subSectionHeading.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),

            SizedBox(height: 10.h),

            Text(
              AppLocalizations.of(
                context,
              )!.unlocktheappfasterandmoresecurelybyusingyourfingerprint,
              textAlign: TextAlign.center,
              style: AppTextStyles.subSectionHeading.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: txt.muted,
              ),
            ),

            const Spacer(flex: 3),

            // Button stays at bottom
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isSuccess
                  ? const SizedBox()
                  : SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleEnableFingerprint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          disabledBackgroundColor: AppColors.primaryColor
                              .withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppLocalizations.of(context)!.enablefingerprint,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
            ),

            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}
