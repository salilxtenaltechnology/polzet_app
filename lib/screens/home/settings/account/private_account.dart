// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../api/app_api.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/token/shared_preferences.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/loader.dart';

class PrivateAccount extends StatefulWidget {
  const PrivateAccount({super.key});

  @override
  State<PrivateAccount> createState() => _PrivateAccountState();
}

class _PrivateAccountState extends State<PrivateAccount> {
  bool isPrivate = false;
  bool isLoading = true;
  bool isUpdating = false;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final accessToken = await SharedPrefService.getToken();

    try {
      var response = await _dio.get(
        ApiConstants.userProfile,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = response.data;
        setState(() {
          isPrivate = data['is_private'] ?? false;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading account data')),
        );
      }
    }
  }

  Future<void> _updatePrivacySetting(bool value) async {
    setState(() {
      isUpdating = true;
    });

    final accessToken = await SharedPrefService.getToken();

    try {
      String isPrivateValue = value.toString();
      final response = await _dio.patch(
        ApiConstants.updateProfile,
        data: {'is_private': isPrivateValue},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          isPrivate = value;
          isUpdating = false;
        });
        if (mounted) {
          showToast(
            message: value
                ? 'Your account is now private'
                : 'Your account is now public',
          );
        }
      } else if (response.statusCode == 400) {
        setState(() {
          isUpdating = false;
        });
        if (mounted) {
          showToast(message: 'Failed to update');
        }
      } else {
        setState(() {
          isUpdating = false;
        });
        if (mounted) {
          showToast(message: 'Failed to update profile');
        }
      }
    } on DioException catch (e) {
      setState(() {
        isUpdating = false;
      });
      if (mounted) {
        showToast(message: '${e.response?.data['message']}');
      }
    } catch (e) {
      setState(() {
        isUpdating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.accountprivacy,
        showBackButton: true,
      ),

      body: isLoading
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Column(
                    children: [
                      _labelModel(
                        AppLocalizations.of(context)!.privatepolzet,
                        isPrivate,
                        isUpdating
                            ? null
                            : (value) {
                                _updatePrivacySetting(value);
                              },
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.whenyourpolzetaccountispublic,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.5),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.whenyourpolzetaccountisprivate,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.5),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUpdating)
                  Center(
                    child: Loader(color: Theme.of(context).colorScheme.primary),
                  ),
              ],
            ),
    );
  }

  Widget _labelModel(
    String labelName,
    bool isSwitch,
    ValueChanged<bool>? onChanged,
  ) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labelName,
                    style: CustomTextStyles.lblPrimaryText(context),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.85,
              child: CupertinoSwitch(
                activeTrackColor: AppColors.primaryColor,
                value: isSwitch,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
