// lib/screens/set_pin_screen.dart
// ignore_for_file: deprecated_member_use, unused_element, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';

import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/themes/app_text_colors.dart';
import '../../../../../gen/assets.gen.dart';
import '../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../widgets/loader.dart';
import 'pin_status.dart';

class SetPinScreen extends StatefulWidget {
  final bool isSettingNewPin;

  const SetPinScreen({super.key, required this.isSettingNewPin});

  @override
  _SetPinScreenState createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _enteredPin = '';
  String _confirmPin = '';
  String _oldPin = '';
  bool _isConfirmingPin = false;
  bool _isEnteringOldPin = false;
  bool _isLoading = false;
  String _pinStrengthMessage = '';

  @override
  void initState() {
    super.initState();
    if (!widget.isSettingNewPin) {
      _isEnteringOldPin = true;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: CommonAppBar(title: _getScreenTitle()),
      body: _isLoading
          ? Center(
              child: Loader(color: Theme.of(context).colorScheme.onPrimary),
            )
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 28.h),

                    // ── Lock icon ──────────────────────────────────────────
                    Container(
                      width: 75,
                      height: 75,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.1),
                      ),
                      child: Image.asset(
                        Assets.images.icSecurity.path,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.7),
                      ),
                    ),

                    SizedBox(height: 18.h),

                    // ── Title ──────────────────────────────────────────────
                    Text(
                      _getInstructionText(),
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 8.h),

                    // ── Subtitle ───────────────────────────────────────────
                    Text(
                      'This PIN will be used to secure your account',
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: txt.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 32.h),

                    // ── PIN dots ───────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final currentPin = _getCurrentPin();
                        final isFilled = index < currentPin.length;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.symmetric(horizontal: 10.w),
                          width: 22.w,
                          height: 22.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            color: Colors.transparent,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onPrimary,
                              width: 1.5,
                            ),
                          ),
                          child: isFilled
                              ? Center(
                                  child: Container(
                                    width: 13.w,
                                    height: 13.w,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(100),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      }),
                    ),

                    const SizedBox(height: 60),

                    // ── Number pad ─────────────────────────────────────────
                    _buildNumberPad(),

                    const Spacer(),

                    // ── Set PIN button ─────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        child: Text(
                          _getScreenTitle(),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Number pad ─────────────────────────────────────────────────────────────

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildPadRow(['1', '2', '3']),
        SizedBox(height: 16.h),
        _buildPadRow(['4', '5', '6']),
        SizedBox(height: 16.h),
        _buildPadRow(['7', '8', '9']),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildDeleteButton(),
            _buildNumberButton('0'),
            _buildClearAllNumberButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildPadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map(_buildNumberButton).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: 65.w,
        height: 65.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: isDarkMode ? const Color(0xFF12141D) : Colors.white,
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: AppTextStyles.subSectionHeading.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.85),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _onDeletePressed,
      child: Container(
        width: 65.w,
        height: 65.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: isDarkMode ? const Color(0xFF12141D) : Colors.white,
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 22.sp,
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllNumberButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_isEnteringOldPin) {
            _oldPin = '';
          } else if (_isConfirmingPin) {
            _confirmPin = '';
          } else {
            _enteredPin = '';
            _pinStrengthMessage = '';
          }
        });
      },
      child: Container(
        width: 65.w,
        height: 65.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.09),
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 23.sp,
          ),
        ),
      ),
    );
  }

  // ── Logic (unchanged) ──────────────────────────────────────────────────────

  String _getScreenTitle() {
    if (_isEnteringOldPin) {
      return AppLocalizations.of(context)!.verifycurrentpin;
    }
    if (_isConfirmingPin) return AppLocalizations.of(context)!.confirmnewpin;
    return widget.isSettingNewPin
        ? AppLocalizations.of(context)!.setpin
        : AppLocalizations.of(context)!.enternewpin;
  }

  String _getInstructionText() {
    if (_isEnteringOldPin) return AppLocalizations.of(context)!.entercurrentpin;
    if (_isConfirmingPin) {
      return AppLocalizations.of(context)!.reenteryournewpin;
    }
    return AppLocalizations.of(context)!.enterfourdigitpin;
  }

  String _getCurrentPin() {
    if (_isEnteringOldPin) return _oldPin;
    if (_isConfirmingPin) return _confirmPin;
    return _enteredPin;
  }

  Color _getPinStrengthColor() {
    switch (_pinStrengthMessage) {
      case 'Strong':
        return Colors.green;
      case 'Too weak':
      case 'Too short':
      case 'Avoid sequential numbers':
      case 'Avoid repeated numbers':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_isEnteringOldPin) {
        if (_oldPin.length < 4) {
          _oldPin += number;
          if (_oldPin.length == 4) {
            _verifyOldPin();
          }
        }
      } else if (_isConfirmingPin) {
        if (_confirmPin.length < 4) {
          _confirmPin += number;
          if (_confirmPin.length == 4) {
            _validatePins();
          }
        }
      } else {
        if (_enteredPin.length < 4) {
          _enteredPin += number;
          _pinStrengthMessage = PinService.getPinStrength(_enteredPin);

          if (_enteredPin.length == 4) {
            if (_pinStrengthMessage == 'Strong') {
              _moveToConfirmation();
            } else {
              Future.delayed(const Duration(milliseconds: 500), () {
                _moveToConfirmation();
              });
            }
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (_isEnteringOldPin) {
        if (_oldPin.isNotEmpty) {
          _oldPin = _oldPin.substring(0, _oldPin.length - 1);
        }
      } else if (_isConfirmingPin) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
          _pinStrengthMessage = _enteredPin.isEmpty
              ? ''
              : PinService.getPinStrength(_enteredPin);
        }
      }
    });
  }

  void _verifyOldPin() async {
    setState(() => _isLoading = true);
    try {
      final authResult = await PinService.authenticateWithPin(_oldPin);
      if (authResult.success) {
        setState(() {
          _isEnteringOldPin = false;
          _oldPin = '';
          _isLoading = false;
        });
      } else {
        _showErrorSnackBar(authResult.message);
        setState(() {
          _oldPin = '';
          _isLoading = false;
        });
        if (authResult.isLocked) {
          Navigator.pop(context, false);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error verifying PIN: $e');
      setState(() {
        _oldPin = '';
        _isLoading = false;
      });
    }
  }

  void _moveToConfirmation() {
    setState(() {
      _isConfirmingPin = true;
      _confirmPin = '';
      _pinStrengthMessage = '';
    });
  }

  void _validatePins() async {
    if (_enteredPin == _confirmPin) {
      setState(() => _isLoading = true);
      try {
        final success = await PinService.savePin(_enteredPin);
        if (success) {
          Navigator.pop(context, true);
        } else {
          _showErrorSnackBar('Failed to save PIN. Please try again.');
          setState(() => _isLoading = false);
        }
      } catch (e) {
        _showErrorSnackBar('Error saving PIN: $e');
        setState(() => _isLoading = false);
      }
    } else {
      _showErrorSnackBar('PINs do not match. Please try again.');
      setState(() {
        _enteredPin = '';
        _confirmPin = '';
        _isConfirmingPin = false;
        _pinStrengthMessage = '';
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,style: const TextStyle(color: Colors.white),),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
