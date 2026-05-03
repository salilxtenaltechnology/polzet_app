// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class PrimaryBackButton extends StatelessWidget {
  const PrimaryBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: const Icon(
        Icons.arrow_back_ios,
        color:  Color(0xFF111111),
        size: 24,
      ),
    );
  }
}
