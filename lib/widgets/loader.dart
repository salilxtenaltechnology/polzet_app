// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';

class Loader extends StatelessWidget {
  Loader({super.key, required this.color});

  Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25,
      height: 25,
      child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
    );
  }
}
