// ignore_for_file: deprecated_member_use, unused_field

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:feather_icons/feather_icons.dart';

import 'package:local_auth/local_auth.dart';
import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../widgets/custom_text_styles.dart';
import '../../../../widgets/diolog/pin_security_diolog.dart';
import '../../../../widgets/loader.dart';
import '../../../../widgets/show_toast.dart';
import '../../../auth/forgot password/forgot_password_import.dart';
import 'biometric/biometric_service.dart';
import 'pin/pin_status.dart';
import 'pin/set_pin_screen.dart';

class Security extends StatefulWidget {
  const Security({super.key});

  @override
  State<StatefulWidget> createState() {
    return SecurityState();
  }
}

class SecurityState extends State<Security> with UtilityMixin {
  final ApiService apiService = ApiService();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showUpdatePasswordButton = false;
  bool _isCurrentPasswordHidden = true;
  bool _isNewPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isSecurity = false;
  bool _isPinSecurity = false;
  bool _isFaceLock = false;
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
      // final pinSecurity = await PinService.isPinSecurityEnabled();
      final fingerprint = await BiometricService.isFingerprintEnabled();
      final biometricEnabled = await BiometricService.isBiometricEnabled();
      final pinSecurity = await PinService.isPinSecurityEnabled(); // ✅ Add this

      setState(() {
        _isSecurity = biometricEnabled;
        _isPinSecurity = biometricEnabled ? pinSecurity : false;
        _isFingerprint = biometricEnabled ? fingerprint : false;
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
      setState(() {
        _isBiometricAvailable = false;
      });
      _showErrorSnackBar('Error checking biometric support: $e');
    }
  }

  Future<void> _handleSecurityToggle(bool value) async {
    setState(() {
      _isSecurity = value;

      // If security is turned off, disable all other security options
      if (!value) {
        _isPinSecurity = false;
        _isFaceLock = false;
        _isFingerprint = false;
      }
    });

    await BiometricService.saveBiometricEnabled(value);

    if (!value) {
      await PinService.setPinSecurityEnabled(false);
      await PinService.clearSavedPin(); // Clear PIN data

      await BiometricService.saveFingerprintEnabled(false);
    }
  }

  Future<void> _handlePinSecurityToggle(bool value) async {
    if (!_isSecurity) {
      _showErrorSnackBar('Please enable Security first');
      return;
    }

    if (value) {
      // ✅ Disable fingerprint when enabling PIN
      if (_isFingerprint) {
        setState(() => _isFingerprint = false);
        await BiometricService.saveFingerprintEnabled(false);
      }

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
          _saveSettings();
        } else {
          setState(() => _isPinSecurity = false);
        }
      }
    } else {
      final shouldDisable = await showDisablePINDiolog(
        context,
        AppLocalizations.of(context)!.disablepinsecurity,
        AppLocalizations.of(context)!.areyousurewanttodisablepinsecurity,
      );

      if (shouldDisable) {
        setState(() => _isPinSecurity = false);
        await PinService.setPinSecurityEnabled(false);
        _saveSettings();
        showToast(message: 'PIN security disabled');
      }
    }
  }

  Future<void> _handleFaceLockToggle(bool value) async {}

  Future<void> _handleFingerprintToggle(bool value) async {
    if (!_isSecurity) {
      _showErrorSnackBar('Please enable Security first');
      return;
    }

    if (value && !_isBiometricAvailable) {
      _showErrorSnackBar(
        'Biometric authentication is not available on this device',
      );
      return;
    }

    if (value) {
      // ✅ Disable PIN when enabling Fingerprint
      if (_isPinSecurity) {
        setState(() => _isPinSecurity = false);
        await PinService.setPinSecurityEnabled(false);
        await PinService.clearSavedPin();
      }

      final isAuthenticated = await _authenticateUser(
        'Enable Fingerprint Security',
      );
      if (!isAuthenticated) return;

      setState(() => _isFingerprint = true);
      await BiometricService.saveFingerprintEnabled(true);
      _saveSettings();
      showToast(message: 'Fingerprint Security enabled successfully');
    } else {
      setState(() => _isFingerprint = false);
      await BiometricService.saveFingerprintEnabled(false);
      _saveSettings();
    }
  }

  Future<bool> _authenticateUser(String reason) async {
    try {
      setState(() => _isLoading = true);

      final isAuthenticated = await BiometricService.authenticateWithBiometrics(
        reason: reason,
        useErrorDialogs: true,
        stickyAuth: true,
      );

      return isAuthenticated;
    } catch (e) {
      _showErrorSnackBar('Authentication failed: $e');
      return false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show option to change existing PIN
  void _showChangePinOption() async {
    final shouldChange = await showDisablePINDiolog(
      context,
      'Change PIN',
      'Do you want to change your current PIN?',
    );

    if (shouldChange) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SetPinScreen(
            isSettingNewPin: false, // Changing existing PIN
          ),
        ),
      );

      if (result == true) {
        showToast(message: 'PIN changed successfully');
      }
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      // Save all settings
      await BiometricService.saveBiometricEnabled(_isSecurity);
      // await PinService.setPinSecurityEnabled(_isPinSecurity);
      await BiometricService.saveFingerprintEnabled(_isFingerprint);

      //showToast(message: 'Security settings saved successfully');
      // Navigate back or to next screen
    } catch (e) {
      _showErrorSnackBar('Error saving settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _labelModel(
    IconData icon,
    String labelName,
    bool isSwitch,
    ValueChanged<bool> onChanged, {
    bool isEnabled = true,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.onBackground,
                size: 20.spMax,
              ),
              SizedBox(width: 10.w),
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
                  onChanged: isEnabled ? onChanged : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void updatePassword() async {
    setState(() {
      _initialCurrentPassword = _currentPasswordController.text;
      _initialNewPassword = _newPasswordController.text;
      _initialConfirmPassword = _confirmPasswordController.text;
      _showUpdatePasswordButton = true;
    });

    String currentPassword = _currentPasswordController.text.trim();
    String newPassword = _newPasswordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();

    if (!RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(newPassword)) {
      if (!mounted) return;
      setState(() {
        newPasswordErrorText =
            'Password must be at least 8 characters long and include one uppercase letter and one special character.';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isSavePassword = true);

    String result = await apiService.updatePassword(
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

    // Check if password update was successful (empty string means success)
    if (result.isEmpty) {
      // Clear all password controllers on success
      setState(() {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _initialCurrentPassword = '';
        _initialNewPassword = '';
        _initialConfirmPassword = '';
        _showUpdatePasswordButton = false;
        // Clear any error messages
        currentPasswordErrorText = null;
        newPasswordErrorText = null;
        confirmPasswordErrorText = null;
        Future.delayed(const Duration(seconds: 3), () {
          setState(() {
            _showUpdatePasswordButton = false;
          });
        });
      });
    }

    setState(() {
      _isSavePassword = false;
    });
  }

  void checkIfChangedPassword(String current, String initial) {
    if (!_isLoading) {
      setState(() {
        _showUpdatePasswordButton = current != initial;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 25.h,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        title: Text(
          AppLocalizations.of(context)!.security,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              children: [
                // Main Security Toggle
                _labelModel(
                  Iconsax.shield_tick_outline,
                  AppLocalizations.of(context)!.security,
                  _isSecurity,
                  _handleSecurityToggle,
                ),
                Divider(
                  thickness: 1,
                  height: 30,
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.1),
                ),
                _labelModel(
                  Icons.password_outlined,
                  AppLocalizations.of(context)!.pinsecurity,
                  _isPinSecurity,
                  _handlePinSecurityToggle,
                  isEnabled: _isSecurity && !_isFingerprint,
                ),
                SizedBox(height: 7.h),
                if (_isSecurity && _isPinSecurity) ...[
                  FutureBuilder<PinStatus>(
                    future: PinService.getPinStatus(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final pinStatus = snapshot.data!;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 3.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${AppLocalizations.of(context)!.lastchanged}${_formatDate(pinStatus.lastChangeDate!)}',
                                  // 'PIN Security Active${pinStatus.lastChangeDate != null ? ' •  : ''}',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10.sp,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _showChangePinOption,
                                child: Text(
                                  AppLocalizations.of(context)!.change,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],

                // Face Recognition - Only enabled when main security is on
                _labelModel(
                  FeatherIcons.smile,
                  AppLocalizations.of(context)!.facerecognition,
                  _isFaceLock,
                  _handleFaceLockToggle,
                  isEnabled:
                      _isSecurity &&
                      _availableBiometrics.contains(BiometricType.face),
                ),
                SizedBox(height: 10.h),
                // Fingerprint Security - Only enabled when main security is on
                _labelModel(
                  Icons.fingerprint,
                  AppLocalizations.of(context)!.fingerprintsecurity,
                  _isFingerprint,
                  _handleFingerprintToggle,
                  isEnabled:
                      _isSecurity && _isBiometricAvailable && !_isPinSecurity,
                ),

                // Security disabled info
                if (!_isSecurity) ...[
                  SizedBox(height: 20.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.enablesecurityfirsttoaccess,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11.4.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Biometric Support Info
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
                Divider(
                  thickness: 1.1,
                  height: 30,
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.2),
                ),
                Text(
                  AppLocalizations.of(context)!.changepassword,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  AppLocalizations.of(context)!.currentpassword,
                  style: TextStyle(
                    color: const Color(0xFF8E8D8D),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5.h),
                _buildPasswordTextField(
                  _currentPasswordController,
                  TextInputType.visiblePassword,
                  AppLocalizations.of(context)!.entercurrentpassword,
                  _isCurrentPasswordHidden,
                  () {
                    setState(() {
                      _isCurrentPasswordHidden = !_isCurrentPasswordHidden;
                    });
                  },
                ),
                if (currentPasswordErrorText != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h),
                    child: Text(
                      currentPasswordErrorText ?? '',
                      style: CustomTextStyles.msgErrorText,
                    ),
                  ),
                SizedBox(height: 5.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigationPush(context, const ForgotPasswordScreen());
                      },
                      child: Text(
                        AppLocalizations.of(context)!.forgotyourpassword,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w300,
                          fontSize: 11.5.sp,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  AppLocalizations.of(context)!.newpassword,
                  style: TextStyle(
                    color: const Color(0xFF8E8D8D),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5.h),
                _buildPasswordTextField(
                  _newPasswordController,
                  TextInputType.visiblePassword,
                  AppLocalizations.of(context)!.enternewpassword,
                  _isNewPasswordHidden,
                  () {
                    setState(() {
                      _isNewPasswordHidden = !_isNewPasswordHidden;
                    });
                  },
                ),
                if (newPasswordErrorText != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h),
                    child: Text(
                      newPasswordErrorText ?? '',
                      style: CustomTextStyles.msgErrorText,
                    ),
                  ),
                SizedBox(height: 12.h),
                Text(
                  AppLocalizations.of(context)!.confirmpassword,
                  style: TextStyle(
                    color: const Color(0xFF8E8D8D),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5.h),
                _buildPasswordTextField(
                  _confirmPasswordController,
                  TextInputType.visiblePassword,
                  AppLocalizations.of(context)!.enterconfirmpassword,
                  _isConfirmPasswordHidden,
                  () {
                    setState(() {
                      _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
                    });
                  },
                ),
                if (confirmPasswordErrorText != null)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h),
                    child: Text(
                      confirmPasswordErrorText ?? '',
                      style: CustomTextStyles.msgErrorText,
                    ),
                  ),
                if (_showUpdatePasswordButton)
                  GestureDetector(
                    onTap: () {
                      if (_showUpdatePasswordButton) {
                        updatePassword();
                      }
                    },
                    child: Container(
                      height: 30.h,
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      child: Center(
                        child: _isSavePassword
                            ? Loader(color: Colors.white)
                            : Text(
                                AppLocalizations.of(context)!.savechanges,
                                style: CustomTextStyles.btnPrimaryText,
                              ),
                      ),
                    ),
                  ),
              ],
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
