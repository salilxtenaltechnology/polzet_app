// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../widgets/appbar/common_appbar.dart';

class ReorderImage extends StatefulWidget {
  final List<File> images;

  const ReorderImage({super.key, required this.images});

  @override
  State<ReorderImage> createState() => _ReorderImageState();
}

class _ReorderItem {
  final Key key = UniqueKey();
  final File file;

  _ReorderItem(this.file);
}

class _ReorderImageState extends State<ReorderImage> {
  late List<_ReorderItem> _orderedItems;
  bool _hasReordered = false;

  @override
  void initState() {
    super.initState();
    _orderedItems = widget.images.map((f) => _ReorderItem(f)).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      if (oldIndex == newIndex) return;
      final item = _orderedItems.removeAt(oldIndex);
      _orderedItems.insert(newIndex, item);
      _hasReordered = true;
    });
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        elevation: 0,
        child: child,
      ),
    );
  }

  Widget _buildImageCard(File file, int index) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Image.file(
              file,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(context),
            ),
          ),
        ),

        // ── Rank badge (number) ──────────────────────────────
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyles.subText.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          size: 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:  CommonAppBar(title: AppLocalizations.of(context)!.reorderimages, showBackButton: true),
      body: Stack(
        children: [
          ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 95.h),
            proxyDecorator: _proxyDecorator,
            onReorder: _onReorder,
            header: Padding(
              padding: EdgeInsets.only(top: 8.h, bottom: 12.h, left: 2.w),
              child: Text(
             AppLocalizations.of(context)!.dragdroptochangeorder,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 14,
                  color: txt.body,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            itemCount: _orderedItems.length,
            itemBuilder: (context, index) {
              final item = _orderedItems[index];
              return KeyedSubtree(
                key: item.key,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildImageCard(item.file, index),
                ),
              );
            },
          ),
          if (_hasReordered)
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 25.h,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _orderedItems.map((e) => e.file).toList(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                     AppLocalizations.of(context)!.done,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
