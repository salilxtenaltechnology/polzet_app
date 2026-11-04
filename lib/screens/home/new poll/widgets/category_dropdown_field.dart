import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';

class CategoryDropdownField extends StatefulWidget {
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;

  const CategoryDropdownField({
    super.key,
    this.selectedCategory,
    this.onCategorySelected,
  });

  @override
  State<CategoryDropdownField> createState() => _CategoryDropdownFieldState();
}

class _CategoryDropdownFieldState extends State<CategoryDropdownField>
    with WidgetsBindingObserver {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  double _fieldWidth = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _categories = [
    'AI & Tech',
    'Current Affairs',
    'Education',
    'Fashion',
    'Finance',
    'Fitness',
    'Food',
    'Gaming',
    'Memes',
    'Movies',
    'Music',
    'Relationships',
    'Sports',
    'Technology',
    'Travel',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_isOpen) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeDropdown();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _closeDropdown() {
    _searchFocusNode.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  void _openDropdown() {
    if (_overlayEntry != null) return;
    _searchController.clear();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        List<String> currentFiltered = List.from(_categories);

        return StatefulBuilder(
          builder: (context, setOverlayState) {
            final mediaQuery = MediaQuery.of(context);
            final keyboardHeight = mediaQuery.viewInsets.bottom;
            final screenHeight = mediaQuery.size.height;
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            final txt = AppTextColors.of(context);

            final renderBox =
                _fieldKey.currentContext?.findRenderObject() as RenderBox?;
            final fieldOffset = renderBox?.localToGlobal(Offset.zero);
            final fieldTop = fieldOffset?.dy ?? 0;
            final fieldHeight = renderBox?.size.height ?? 48.0;
            final fieldBottom = fieldTop + fieldHeight;

            final spaceBelow = screenHeight - keyboardHeight - fieldBottom;
            final spaceAbove =
                fieldTop - mediaQuery.padding.top - kToolbarHeight;

            final bool showAbove =
                (keyboardHeight > 0 || spaceBelow < 250) &&
                (spaceAbove > spaceBelow);

            final double availableListHeight = showAbove
                ? (spaceAbove - 85).clamp(80.0, 220.0)
                : (spaceBelow - 85).clamp(80.0, 220.0);

            return Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    _closeDropdown();
                  },
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  width: _fieldWidth > 0
                      ? _fieldWidth
                      : (mediaQuery.size.width - 24.w),
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    targetAnchor: showAbove
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
                    followerAnchor: showAbove
                        ? Alignment.bottomLeft
                        : Alignment.topLeft,
                    offset: Offset(0, showAbove ? -6 : 6),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode
                          ? const Color(0xFF1F1F23)
                          : Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF1F1F23)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? const Color(0xFF2A2A2E)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 13.5,
                                    color: txt.title,
                                  ),
                                  onChanged: (q) {
                                    setOverlayState(() {
                                      if (q.trim().isEmpty) {
                                        currentFiltered = List.from(_categories);
                                      } else {
                                        final query = q.toLowerCase().trim();
                                        currentFiltered = _categories.where((c) {
                                          return c.toLowerCase().contains(query);
                                        }).toList();
                                      }
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!.searchcategory,
                                    hintStyle: AppTextStyles.bodyText.copyWith(
                                      fontSize: 13.5,
                                      color: const Color(0xFF898989),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 19,
                                      color: Color(0xFF898989),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 38,
                                      minHeight: 40,
                                    ),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 34,
                                              minHeight: 40,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: Color(0xFF898989),
                                            ),
                                            onPressed: () {
                                              _searchController.clear();
                                              setOverlayState(() {
                                                currentFiltered =
                                                    List.from(_categories);
                                              });
                                            },
                                          )
                                        : null,
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 40,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.only(right: 10),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, thickness: 0.5),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: availableListHeight,
                              ),
                              child: currentFiltered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Text(
                                        'No category found',
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 13,
                                          color: txt.muted,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: currentFiltered.length,
                                      itemBuilder: (context, index) {
                                        final category = currentFiltered[index];
                                        final isSelected =
                                            category.toLowerCase() ==
                                            (widget.selectedCategory ?? '')
                                                .toLowerCase();

                                        return InkWell(
                                          onTap: () {
                                            widget.onCategorySelected
                                                ?.call(category);
                                            _closeDropdown();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            color: isSelected
                                                ? (isDarkMode
                                                      ? const Color(0xFF2A2A2E)
                                                      : const Color(0xFFF0F0F0))
                                                : Colors.transparent,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    category,
                                                    style: AppTextStyles
                                                        .bodyText
                                                        .copyWith(
                                                          fontSize: 13.5,
                                                          fontWeight: isSelected
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                          color: txt.title,
                                                        ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _fieldKey,
      builder: (context, constraints) {
        _fieldWidth = constraints.maxWidth;

        return CompositedTransformTarget(
          link: _layerLink,
          child: InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              height: 48,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selectedCategory ?? AppLocalizations.of(context)!.selectacategory,
                      style: widget.selectedCategory != null
                          ? AppTextStyles.subText.copyWith(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w400,
                            )
                          : AppTextStyles.subText.copyWith(
                              fontSize: 14,
                              color: const Color(0XFF898989),
                              fontWeight: FontWeight.w400,
                            ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

