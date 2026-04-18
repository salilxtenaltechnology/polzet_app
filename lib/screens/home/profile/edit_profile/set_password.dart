// ignore_for_file: deprecated_member_use
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/show_toast.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen>
    with UtilityMixin {
  final ApiService _apiService = ApiService();

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isNewPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isSaving = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // ✅ Validation
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.pleasefillinallfields);
      return;
    }

    if (newPassword.length < 8) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.passwordmustbeatleasteightcharacters);
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = AppLocalizations.of(context)!.passworddonotmatch);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    final error = await _apiService.setPassword(newPassword);

    if (!mounted) return;

    if (error.isEmpty) {
      showToast(message: 'Password set successfully!');
      Navigator.pop(context);
    } else {
      setState(() => _errorMessage = error);
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: const PrimaryBackButton(),
        title: Text(
          AppLocalizations.of(context)!.setpassword,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12.h),
            Text(
              AppLocalizations.of(context)!.newpassword,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6.h),
            _buildPasswordTextField(
              _newPasswordController,
              TextInputType.visiblePassword,
              AppLocalizations.of(context)!.enternewpassword,
              _isNewPasswordHidden,
              () =>
                  setState(() => _isNewPasswordHidden = !_isNewPasswordHidden),
            ),

            SizedBox(height: 16.h),

            // ─── Confirm Password ────────────────────────────────────────
            Text(
              AppLocalizations.of(context)!.confirmpassword,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 6.h),
            _buildPasswordTextField(
              _confirmPasswordController,
              TextInputType.visiblePassword,
            AppLocalizations.of(context)!.reenternewpassword,
              _isConfirmPasswordHidden,
              () => setState(
                () => _isConfirmPasswordHidden = !_isConfirmPasswordHidden,
              ),
            ),

            // ─── Error Message ───────────────────────────────────────────
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: Text(
                  _errorMessage,
                  style: CustomTextStyles.msgErrorText(context),
                ),
              ),

            SizedBox(height: 24.h),
            GestureDetector(
              onTap: _isSaving ? null : _savePassword,
              child: Container(
                height: 35.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _isSaving
                      ? AppColors.primaryColor.withOpacity(0.6)
                      : AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(50.r),
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                           AppLocalizations.of(context)!.savepassword,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.sp,
                          ),
                        ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              margin: EdgeInsets.only(top: 15.h),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryColor,
                    size: 18,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                     AppLocalizations.of(context)!.setapasswordsoyoucansigninwithoutgoogle,
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordTextField(
    TextEditingController controller,
    TextInputType inputType,
    String hintText,
    bool isHidden,
    VoidCallback? onTap,
  ) {
    return SizedBox(
      height: 35.h,
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        style: CustomTextStyles.lblPrimaryText(context),
        obscureText: isHidden,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(left: 10.w),
          hintText: hintText,
          hintStyle: CustomTextStyles.lblPrimaryHintText(context),
          border: InputBorder.none,
          suffixIcon: IconButton(
            onPressed: onTap,
            icon: Icon(
              isHidden ? FeatherIcons.eyeOff : FeatherIcons.eye,
              size: 20,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.13),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.primaryColor.withOpacity(0.7),
            ),
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ),
    );
  }
}
