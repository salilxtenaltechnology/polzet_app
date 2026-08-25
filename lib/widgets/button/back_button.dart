// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class PrimaryBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const PrimaryBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Icon(
        Icons.arrow_back_ios,
        color: Theme.of(context).colorScheme.onBackground,
        size: 24,
      ),
    );
  }
}
