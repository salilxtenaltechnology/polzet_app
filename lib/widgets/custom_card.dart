// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/constants/app_radius.dart';

class CustomCard extends StatelessWidget {
  final Widget widget;
  const CustomCard({super.key, required this.widget});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10).w,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: AppRadius.cardRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            spreadRadius: 2,
          ),
        ],
      ),
      child: widget,
    );
  }
}
