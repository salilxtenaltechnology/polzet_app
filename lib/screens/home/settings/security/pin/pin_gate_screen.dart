// lib/screens/home/settings/security/pin/pin_gate_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../splash/splash_screen.dart';
import 'pin_status.dart';

class PinGateScreen extends StatefulWidget {
  const PinGateScreen({Key? key}) : super(key: key);

  @override
  _PinGateScreenState createState() => _PinGateScreenState();
}

class _PinGateScreenState extends State<PinGateScreen> {
  String _enteredPin = '';
  bool _isLoading = false;
  String _errorMessage = '';
  int _remainingAttempts = 3;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _loadPinStatus();
  }

  Future<void> _loadPinStatus() async {
    final status = await PinService.getPinStatus();
    setState(() {
      _remainingAttempts = status.remainingAttempts;
      _isLocked = status.isLocked;

      if (status.isLocked && status.lockoutEndTime != null) {
        final remainingTime = status.lockoutEndTime!.difference(DateTime.now());
        if (remainingTime.isNegative) {
          _isLocked = false;
        } else {
          _errorMessage =
              'Account locked. Try again in ${remainingTime.inMinutes} minutes.';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    SizedBox(height: 50.h),

                    Icon(
                      Icons.lock_outline,
                      size: 50.sp,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 30.h),
                    // Title
                    Text(
                      'Enter PIN',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Subtitle
                    Text(
                      'Enter your 4-digit PIN to continue',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Theme.of(context)
                            .colorScheme
                            .onBackground
                            .withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 35.h),
                    // PIN dots display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 10.w),
                          width: 20.w,
                          height: 20.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index < _enteredPin.length
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.2),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 10.h),
                    // Error message
                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12.sp,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                    // Remaining attempts indicator
                    if (!_isLocked && _remainingAttempts < 3) ...[
                      Text(
                        '${AppLocalizations.of(context)!.remainingattempts}$_remainingAttempts',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                    SizedBox(height: 30.h),
                    // Number pad
                    _buildNumberPad(),
                  ],
                ),
              ),
            ),
    );
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
            SizedBox(width: 60.w, height: 60.w), // Empty space
            _buildNumberButton('0'),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: _isLocked ? null : () => _onNumberPressed(number),
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isLocked
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: _isLocked
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
              color: _isLocked
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _isLocked ? null : _onDeletePressed,
      child: Container(
        width: 60.w,
        height: 60.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isLocked
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: _isLocked
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: _isLocked
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Theme.of(context).colorScheme.primary,
            size: 22.sp,
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _errorMessage = '';
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);

    try {
      final authResult = await PinService.authenticateWithPin(_enteredPin);

      if (!mounted) return;

      if (authResult.success) {
        // PIN verified successfully - navigate to main app
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SplashScreen(isLogged: true),
          ),
        );
      } else {
        // PIN verification failed
        setState(() {
          _errorMessage = authResult.message;
          _remainingAttempts = authResult.remainingAttempts;
          _isLocked = authResult.isLocked;
          _enteredPin = '';
          _isLoading = false;
        });

        // Reload status to update lockout timer
        if (authResult.isLocked) {
          await _loadPinStatus();
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Error verifying PIN. Please try again.';
        _enteredPin = '';
        _isLoading = false;
      });
    }
  }
}
