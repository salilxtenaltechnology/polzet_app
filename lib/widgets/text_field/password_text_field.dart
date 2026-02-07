// ignore_for_file: deprecated_member_use

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';

import 'custom_text_field.dart';

class PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  const PasswordTextField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _isHidden = true;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      hintText: widget.hintText,
      keyboardType: TextInputType.visiblePassword,
      suffixIcon: IconButton(
        onPressed: () => setState(() => _isHidden = !_isHidden),
        icon: Icon(
          _isHidden ? FeatherIcons.eyeOff : FeatherIcons.eye,
          size: 20,
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.13),
        ),
      ),
    );
  }
}
