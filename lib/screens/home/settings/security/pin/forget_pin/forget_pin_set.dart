// lib/screens/set_pin_screen.dart
// ignore_for_file: deprecated_member_use, unused_element, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../../../l10n/generated/app_localizations.dart';
import '../../../../../../widgets/custom_text_styles.dart';
import '../../../../home_imports.dart';
import '../pin_gate_screen.dart';
import '../pin_status.dart';

class ForgetPinSet extends StatefulWidget {
  final bool isSettingNewPin;

  const ForgetPinSet({super.key, required this.isSettingNewPin});

  @override
  _SetPinScreenState createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<ForgetPinSet> {
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
          _getScreenTitle(),
          style: CustomTextStyles.appBarTitleText(context),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  SizedBox(height: 40.h),
                  Text(
                    _getInstructionText(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40.h),
                  // PIN dots display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final currentPin = _getCurrentPin();
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 10.w),
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < currentPin.length
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.2),
                        ),
                      );
                    }),
                  ),

                  SizedBox(height: 50.h),
                  // Number pad
                  _buildNumberPad(),
                  SizedBox(height: 30.h),
                  // Show attempts info if available
                  // FutureBuilder<PinStatus>(
                  //   future: PinService.getPinStatus(),
                  //   builder: (context, snapshot) {
                  //     if (snapshot.hasData &&
                  //         snapshot.data!.attemptsCount > 0) {
                  //       final status = snapshot.data!;
                  //       return Text(
                  //         '${AppLocalizations.of(context)!.remainingattempts}${status.remainingAttempts}',
                  //         style: TextStyle(
                  //           fontSize: 12.sp,
                  //           color: Colors.orange,
                  //         ),
                  //       );
                  //     }
                  //     return const SizedBox.shrink();
                  //   },
                  // ),
                ],
              ),
            ),
    );
  }

  String _getScreenTitle() {
    if (_isEnteringOldPin) {
      return AppLocalizations.of(context)!.verifycurrentpin;
    }
    if (_isConfirmingPin) return AppLocalizations.of(context)!.confirmnewpin;
    return widget.isSettingNewPin
        ? 'Set New PIN'
        : AppLocalizations.of(context)!.enternewpin;
  }

  String _getInstructionText() {
    if (_isEnteringOldPin) return AppLocalizations.of(context)!.entercurrentpin;
    if (_isConfirmingPin) {
      return AppLocalizations.of(context)!.reenteryournewpin;
    }
    return 'Enter a New 4-digit PIN';
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

  Widget _buildNumberPad() {
    return Column(
      children: [
        // First row (1, 2, 3)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ],
        ),
        SizedBox(height: 20.h),

        // Second row (4, 5, 6)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ],
        ),
        SizedBox(height: 20.h),

        // Third row (7, 8, 9)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ],
        ),
        SizedBox(height: 20.h),

        // Fourth row (empty, 0, delete)
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

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearAllNumberButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 60.h,
        width: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
        child: Center(
          child: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.primary,
            size: 22.spMax,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 22.sp,
          ),
        ),
      ),
    );
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
          // Update PIN strength message
          _pinStrengthMessage = PinService.getPinStrength(_enteredPin);

          if (_enteredPin.length == 4) {
            // Check PIN strength before proceeding
            if (_pinStrengthMessage == 'Strong') {
              _moveToConfirmation();
            } else {
              // Show warning but allow user to continue
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
          // Update PIN strength message
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
        // Old PIN verified, move to new PIN entry
        setState(() {
          _isEnteringOldPin = false;
          _oldPin = '';
          _isLoading = false;
        });
      } else {
        showToast(message: authResult.message);
        setState(() {
          _oldPin = '';
          _isLoading = false;
        });

        // If locked, close screen
        if (authResult.isLocked) {
          Navigator.pop(context, false);
        }
      }
    } catch (e) {
      showToast(message: 'Error verifying PIN: $e');
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
        bool success;

        if (widget.isSettingNewPin) {
          // Setting new PIN
          success = await PinService.savePin(_enteredPin);
        } else {
          // This shouldn't happen as we verify old PIN first, but just in case
          success = await PinService.savePin(_enteredPin);
        }

        if (success) {
          // Return success
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const PinGateScreen(destination: HomeScreen(initialIndex: 0)),
            ),
          );
        } else {
          showToast(message: 'Failed to save PIN. Please try again.');
          setState(() => _isLoading = false);
        }
      } catch (e) {
        showToast(message: 'Error saving PIN: $e');

        setState(() => _isLoading = false);
      }
    } else {
      showToast(message: 'PINs do not match. Please try again.');
      setState(() {
        _enteredPin = '';
        _confirmPin = '';
        _isConfirmingPin = false;
        _pinStrengthMessage = '';
      });
    }
  }
}
