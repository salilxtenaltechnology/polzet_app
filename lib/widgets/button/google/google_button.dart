import 'package:flutter/material.dart';

import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';

class GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const GoogleButton({super.key, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(Assets.images.icGoogle.path, width: 22, height: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Continue With Google',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 15,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}