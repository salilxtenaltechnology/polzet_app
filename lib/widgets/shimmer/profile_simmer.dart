// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:shimmer/shimmer.dart';

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    //final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2);

    return ColoredBox(
      color: Colors.transparent,
      child: Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0),
        highlightColor: isDark
            ? const Color(0xFF3D3D3D)
            : const Color(0xFFF5F5F5),
        child: ListView(children: [_buildHeader()]),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 25,
          width: 250,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        //  const Text('Full name'),
        const SizedBox(height: 5),
        Container(
          height: 20,
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        const SizedBox(height: 20),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatCard(),
              const SizedBox(width: 15),
              _StatCard(),
              const SizedBox(width: 15),
              _StatCard(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 38,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 38,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          height: 40,
          width: double.infinity,
          decoration: const BoxDecoration(color: Colors.white),
        ),
        Container(
          height: 300,
          width: double.infinity,
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        Container(
          height: 300,
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
      ],
    );
  }
}

Widget _StatCard() {
  return Container(
    height: 75,
    width: 100,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.button),
    ),
  );
}
