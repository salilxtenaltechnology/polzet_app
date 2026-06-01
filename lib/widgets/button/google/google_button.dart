// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../core/themes/app_text_styles.dart';
import '../../../gen/assets.gen.dart';
import '../../loader.dart';

class GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const GoogleButton({super.key, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          side: BorderSide(
            color: isDarkMode
                ? Theme.of(context).colorScheme.outline
                : const Color(0xFFE5E7EB),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: Loader(color: Theme.of(context).colorScheme.onPrimary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    Assets.images.icGoogle.path,
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue With Google',
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 15,
                      color: isDarkMode
                          ? Theme.of(
                              context,
                            ).colorScheme.onBackground.withOpacity(0.9)
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
