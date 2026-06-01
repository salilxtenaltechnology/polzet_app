// ignore_for_file: deprecated_member_use, unused_field

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/dialog/custom_diolog.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import 'account/delete_account.dart';
import 'biometric/biometric_service.dart';
import 'biometric/enable_biometric_screen.dart';
import 'password/change_password.dart';
import 'pin/pin_status.dart';
import 'pin/set_pin_screen.dart';

class Security extends StatefulWidget {
  const Security({super.key});

  @override
  State<StatefulWidget> createState() => SecurityState();
}

class SecurityState extends State<Security> with UtilityMixin {
  final ApiService apiService = ApiService();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showUpdatePasswordButton = false;
  bool _isPinSecurity = false;
  final bool _isFaceLock = false;
  bool _isFingerprint = false;
  bool _isLoading = false;
  bool _isSavePassword = false;
  bool _isBiometricAvailable = false;

  String _initialCurrentPassword = "";
  String _initialNewPassword = "";
  String _initialConfirmPassword = "";
  final String _passwordErrorText = '';

  String? currentPasswordErrorText;
  String? newPasswordErrorText;
  String? confirmPasswordErrorText;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    _checkBiometricSupport();

    _currentPasswordController.addListener(() {
      checkIfChangedPassword(
        _currentPasswordController.text,
        _initialCurrentPassword,
      );
    });
    _newPasswordController.addListener(() {
      checkIfChangedPassword(_newPasswordController.text, _initialNewPassword);
    });
    _confirmPasswordController.addListener(() {
      checkIfChangedPassword(
        _confirmPasswordController.text,
        _initialConfirmPassword,
      );
    });
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final fingerprint = await BiometricService.isFingerprintEnabled();
      final pinSecurity = await PinService.isPinSecurityEnabled();
      setState(() {
        _isPinSecurity = pinSecurity;
        _isFingerprint = fingerprint;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading security settings: $e');
    }
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final isAvailable = await BiometricService.isBiometricAvailable();
      final availableBiometrics =
          await BiometricService.getAvailableBiometrics();
      setState(() {
        _isBiometricAvailable = isAvailable;
        _availableBiometrics = availableBiometrics;
      });
    } catch (e) {
      setState(() => _isBiometricAvailable = false);
      _showErrorSnackBar('Error checking biometric support: $e');
    }
  }

  // ── PIN Toggle ─────────────────────────────────────────────────────────────
  Future<void> _handlePinSecurityToggle(bool value) async {
    if (value) {
      final isPinSet = await PinService.isPinSet();
      if (isPinSet) {
        setState(() => _isPinSecurity = true);
        await PinService.setPinSecurityEnabled(true);
        showToast(message: 'PIN security enabled');
      } else {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SetPinScreen(isSettingNewPin: true),
          ),
        );
        if (result == true) {
          setState(() => _isPinSecurity = true);
          await PinService.setPinSecurityEnabled(true);
        } else {
          setState(() => _isPinSecurity = false);
        }
      }
    } else {
      showPinSecurityDiolog(
        context,
        AppLocalizations.of(context)!.disablepinsecurity,
        AppLocalizations.of(context)!.areyousurewanttodisablepinsecurity,
        () async {
          Navigator.of(context).pop();
          setState(() => _isPinSecurity = false);
          await PinService.setPinSecurityEnabled(false);
          showToast(message: 'PIN security disabled');
        },
      );
    }
  }

  // ── Fingerprint Toggle ─────────────────────────────────────────────────────
  Future<void> _handleFingerprintToggle(bool value) async {
    if (value && !_isBiometricAvailable) {
      _showErrorSnackBar(
        'Biometric authentication is not available on this device',
      );
      return;
    }

    if (value) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EnableBiometricScreen()),
      );
      if (result == true) {
        setState(() => _isFingerprint = true);
        showToast(message: 'Fingerprint security enabled');
      } else {
        setState(() => _isFingerprint = false);
      }
    } else {
      setState(() => _isFingerprint = false);
      await BiometricService.saveFingerprintEnabled(false);
      showToast(message: 'Fingerprint security disabled');
    }
  }

  Future<void> _handleFaceLockToggle(bool value) async {}

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showChangePinOption() async {
    showPinSecurityDiolog(
      context,
      AppLocalizations.of(context)!.changeoin,
      AppLocalizations.of(context)!.doyouwanttochangeyourcurrentpin,
      () async {
        Navigator.of(context).pop();
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SetPinScreen(isSettingNewPin: false),
          ),
        );
        if (result == true) {
          showToast(message: 'PIN changed successfully');
        }
      },
    );
  }

  void updatePassword() async {
    setState(() {
      _initialCurrentPassword = _currentPasswordController.text;
      _initialNewPassword = _newPasswordController.text;
      _initialConfirmPassword = _confirmPasswordController.text;
      _showUpdatePasswordButton = true;
    });

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(newPassword)) {
      if (!mounted) return;
      setState(() {
        newPasswordErrorText =
            'Password must be at least 8 characters long and include one uppercase letter and one special character.';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSavePassword = true);

    final result = await apiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmNewPassword: confirmPassword,
      onError: (currentPasswordError, newPasswordError, confirmPasswordError) {
        setState(() {
          currentPasswordErrorText = currentPasswordError;
          newPasswordErrorText = newPasswordError;
          confirmPasswordErrorText = confirmPasswordError;
        });
      },
    );

    if (!mounted) return;

    if (result.isEmpty) {
      setState(() {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _initialCurrentPassword = '';
        _initialNewPassword = '';
        _initialConfirmPassword = '';
        _showUpdatePasswordButton = false;
        currentPasswordErrorText = null;
        newPasswordErrorText = null;
        confirmPasswordErrorText = null;
      });
    }

    setState(() => _isSavePassword = false);
  }

  void checkIfChangedPassword(String current, String initial) {
    if (!_isLoading) {
      setState(() => _showUpdatePasswordButton = current != initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(
        title: AppLocalizations.of(context)!.security,
        showBackButton: true,
      ),
      body: _isLoading
          ? Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            )
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              children: [
                _buildSecurityCard(),
                SizedBox(height: 20.h),
                _buildChangePasswordCard(),
                _buildDeleteAccountCard(),
                if (!_isBiometricAvailable) ...[
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Biometric authentication is not available on this device. Please check your device settings.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSecurityCard() {
    return Column(
      children: [
        _buildSecurityTile(
          icon: Icons.password_outlined,
          title: AppLocalizations.of(context)!.pinsecurity,
          value: _isPinSecurity,
          isEnabled: true, // always enabled
          onChanged: _handlePinSecurityToggle,
          trailing: _isPinSecurity
              ? GestureDetector(
                  onTap: _showChangePinOption,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.changeoin,
                      style: AppTextStyles.subText.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                )
              : null,
        ),

        SizedBox(height: 10.h),

        _buildSecurityTile(
          icon: Icons.fingerprint,
          title: AppLocalizations.of(context)!.fingerprintsecurity,
          value: _isFingerprint,
          isEnabled: _isBiometricAvailable, // only device capability matters
          onChanged: _handleFingerprintToggle,
        ),

        SizedBox(height: 10.h),

        _buildSecurityTile(
          icon: FeatherIcons.smile,
          title: AppLocalizations.of(context)!.facerecognition,
          value: _isFaceLock,
          isEnabled: _availableBiometrics.contains(BiometricType.face),
          onChanged: _handleFaceLockToggle,
        ),
      ],
    );
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required String title,
    required bool value,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
  }) {
    final txt = AppTextColors.of(context);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                height: 37,
                width: 37,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.title,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[trailing, SizedBox(width: 8.w)],
              Transform.scale(
                scale: 0.85,
                child: CupertinoSwitch(
                  activeTrackColor: AppColors.primaryColor,
                  value: value,
                  onChanged: isEnabled ? onChanged : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    final txt = AppTextColors.of(context);

    return GestureDetector(
      onTap: () => navigationPush(context, const ChangePasswordScreen()),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                height: 47,
                width: 47,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  Assets.images.icSecurity.path,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.changepassword,
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.title,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.updateyourpasswordandsecureyouraccount,
                      style: AppTextStyles.subText.copyWith(
                        color: txt.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15.5,
                color: Color(0XFF595959),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountCard() {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => navigationPush(context, const DeleteAccountScreen()),
      child: Container(
        margin: const EdgeInsets.only(top: 15),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFFF85D7F).withOpacity(0.06)
              : const Color(0XFFFFF1F4),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: const Color(0XFFD63C5E).withOpacity(0.4),
            width: 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 2)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                height: 47,
                width: 47,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(Assets.images.icDelete.path),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.deleteaccount,
                      style: AppTextStyles.bodyText.copyWith(
                        color: const Color(0XFFD63C5E).withOpacity(0.8),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.permanentlydeleteyourpolzetaccountandalldata,
                      style: AppTextStyles.subText.copyWith(
                        color: txt.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15.5,
                color: Color(0XFF595959),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
