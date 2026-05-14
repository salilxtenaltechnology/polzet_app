// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_radius.dart';
import '../../languages/l10n/generated/app_localizations.dart';
import '../../provider/user_provider.dart';
import '../../core/themes/app_text_styles.dart';
import '../text_field/primary_textfield.dart';

class ConfirmDeletionAccountDioloig extends StatefulWidget {
  const ConfirmDeletionAccountDioloig({super.key, required this.onPressed});

  final Function(String password)? onPressed;

  @override
  State<ConfirmDeletionAccountDioloig> createState() =>
      _ConfirmDeletionAccountDioloigState();
}

class _ConfirmDeletionAccountDioloigState
    extends State<ConfirmDeletionAccountDioloig> {
  bool isConfirmPasswordHidden = true;
  bool _isPasswordHidden = true;
  String? _passwordErrorText;

  final usernameController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    usernameController.text = userProvider.username!;
    confirmPasswordController.addListener(() {
      if (_passwordErrorText != null &&
          confirmPasswordController.text.isNotEmpty) {
        setState(() => _passwordErrorText = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.confirmaccountdeletion,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.enteryourpasswordtopermentlydeleteyouraccount,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                SizedBox(height: 12.h),
                PrimaryTextfield(
                  controller: usernameController,
                  isPassword: false,
                  isRead: true,
                  keyboardType: TextInputType.text,
                  labelText: AppLocalizations.of(context)!.username,
                  prefixIcon: Icon(
                    FeatherIcons.user,
                    size: 17,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.13),
                  ),
                ),
                PrimaryTextfield(
                  controller: confirmPasswordController,
                  isPassword: _isPasswordHidden,
                  keyboardType: TextInputType.text,
                  labelText: AppLocalizations.of(context)!.confirmpassword,
                  prefixIcon: Icon(
                    FeatherIcons.lock,
                    size: 17,
                    color: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.13),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordHidden
                          ? FeatherIcons.eyeOff
                          : FeatherIcons.eye,
                      color: Theme.of(
                        context,
                      ).colorScheme.onBackground.withOpacity(0.2),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordHidden = !_isPasswordHidden;
                      });
                    },
                  ),
                ),
                if (_passwordErrorText != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h, left: 4.w),
                    child: Text(
                      _passwordErrorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0XFFDCDCDC)),

          IntrinsicHeight(
            child: Row(
              children: [
                // Cancel button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cancel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5.sp,
                          color: const Color(0XFF898989),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),

                // Vertical divider
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0XFFDCDCDC),
                ),

                // Log out button
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final password = confirmPasswordController.text.trim();
                      if (password.isEmpty) {
                        setState(() {
                          _passwordErrorText = 'Please enter your password';
                        });
                        return;
                      }
                      setState(() => _passwordErrorText = null);
                      widget.onPressed?.call(password);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.yesdelete,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subText.copyWith(
                          fontSize: 13.5.sp,
                          color: const Color(0XFFE5484D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
