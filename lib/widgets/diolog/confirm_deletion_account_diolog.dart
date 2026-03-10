// ignore_for_file: deprecated_member_use, must_be_immutable
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../provider/user_provider.dart';
import '../custom_text_styles.dart';
import '../show_toast.dart';
import '../text_field/primary_textfield.dart';

class ConfirmDeletionAccountDioloig extends StatefulWidget {
  const ConfirmDeletionAccountDioloig({super.key, required this.onPressed});

  final Function(String password)? onPressed; // ✅ passes password back

  @override
  State<ConfirmDeletionAccountDioloig> createState() =>
      _ConfirmDeletionAccountDioloigState();
}

class _ConfirmDeletionAccountDioloigState
    extends State<ConfirmDeletionAccountDioloig> {
  bool isConfirmPasswordHidden = true;
  bool _isPasswordHidden = true;

  final usernameController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userProvider = context.read<UserProvider>();
    usernameController.text = userProvider.username!;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 325,
      padding: EdgeInsets.fromLTRB(15.w, 12.h, 15.w, 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Confirm Account Deletion',
            style: CustomTextStyles.appBarTitleText(context),
          ),
          SizedBox(height: 10.h),
          Text(
            'Enter your password to permanently delete your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xB0757575),
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12.h),
          PrimaryTextfield(
            controller: usernameController,
            isPassword: false,
            isRead: true,
            keyboardType: TextInputType.text,
            labelText: 'Username',
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
            labelText: 'Confirm password',
            prefixIcon: Icon(
              FeatherIcons.lock,
              size: 17,
              color: Theme.of(
                context,
              ).colorScheme.onBackground.withOpacity(0.13),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordHidden ? FeatherIcons.eyeOff : FeatherIcons.eye,
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
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context)!.close.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.onBackground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 15.w),
              GestureDetector(
                onTap: () async {
                  final password = confirmPasswordController.text.trim();
                  if (password.isEmpty) {
                    showToast(message: 'Please enter your password');
                    return;
                  }
                  widget.onPressed?.call(password);
                },
                child: Text(
                  'YES, DELETE',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.redColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
