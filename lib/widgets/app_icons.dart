// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppIcons extends StatelessWidget {
  AppIcons({super.key, this.onTap, required this.icon});

  VoidCallback? onTap;
  IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 21.spMax,
        color: Theme.of(context).colorScheme.onBackground
      ),
    );
  }
}
