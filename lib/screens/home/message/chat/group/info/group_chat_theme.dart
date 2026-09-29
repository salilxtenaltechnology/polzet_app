// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:polzet_app/api/api_service.dart';
import 'package:polzet_app/models/chat/chat_theme_item.dart';
import 'package:polzet_app/provider/group_chat_provider.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import 'package:polzet_app/widgets/button/primary_button.dart';
import 'package:polzet_app/widgets/show_toast.dart';

import '../../../../../../languages/l10n/generated/app_localizations.dart';

export 'package:polzet_app/models/chat/chat_theme_item.dart';

class GroupChatTheme extends StatefulWidget {
  final dynamic chatId;
  final GroupChatProvider? groupChatProvider;
  final dynamic chatTheme;
  final Map<String, dynamic>? chat;
  final String? title;
  final String? description;
  final String? category;
  final String? privacy;

  const GroupChatTheme({
    super.key,
    this.chatId,
    this.groupChatProvider,
    this.chatTheme,
    this.chat,
    this.title,
    this.description,
    this.category,
    this.privacy,
  });

  @override
  State<GroupChatTheme> createState() => _GroupChatThemeState();
}

class _GroupChatThemeState extends State<GroupChatTheme> {
  int _selectedIndex = 0;
  int _initialIndex = 0;
  bool _initializedTheme = false;
  bool _isLoading = false;
  List<ChatThemeItem> get _themes => defaultChatThemes;

  bool get _hasChanged => _selectedIndex != _initialIndex;

  GroupChatProvider? get _provider {
    if (widget.groupChatProvider != null) return widget.groupChatProvider;
    try {
      return Provider.of<GroupChatProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initSelectedIndex();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedTheme) {
      _initSelectedIndex();
      _initializedTheme = true;
    }
  }

  void _initSelectedIndex() {
    final dynamic themeVal = widget.chatTheme ??
        widget.chat?['chat_theme'] ??
        widget.chat?['chatTheme'] ??
        widget.groupChatProvider?.currentTheme?.id ??
        _provider?.currentTheme?.id;

    if (themeVal != null) {
      final item = ChatThemeItem.fromIdOrName(themeVal);
      if (item != null) {
        final index = _themes.indexWhere((t) => t.id == item.id);
        if (index != -1) {
          _selectedIndex = index;
          _initialIndex = index;
          return;
        }
      }
    }
    _initialIndex = _selectedIndex;
  }

  Future<void> _applyTheme() async {
    final selectedTheme = _themes[_selectedIndex];
    final provider = _provider;
    final dynamic resolvedChatId = widget.chatId ??
        widget.chat?['id'] ??
        widget.chat?['chat_id'] ??
        widget.groupChatProvider?.chatId ??
        provider?.chatId;

    if (resolvedChatId != null &&
        resolvedChatId.toString().isNotEmpty &&
        resolvedChatId.toString() != '0') {
      setState(() => _isLoading = true);

      final String resolvedTitle = (widget.title?.trim().isNotEmpty == true)
          ? widget.title!.trim()
          : (widget.chat?['title']?.toString().trim().isNotEmpty == true
              ? widget.chat!['title'].toString().trim()
              : (widget.chat?['group_name']?.toString().trim().isNotEmpty == true
                  ? widget.chat!['group_name'].toString().trim()
                  : (provider?.groupName?.trim().isNotEmpty == true
                      ? provider!.groupName!.trim()
                      : 'Group Name')));

      final String resolvedDescription = widget.description ??
          widget.chat?['description']?.toString() ??
          provider?.chat?['description']?.toString() ??
          '';

      final String resolvedCategory = (widget.category?.trim().isNotEmpty == true)
          ? widget.category!.trim().toLowerCase()
          : (widget.chat?['category']?.toString().trim().isNotEmpty == true
              ? widget.chat!['category'].toString().trim().toLowerCase()
              : (widget.chat?['group_category']?.toString().trim().isNotEmpty == true
                  ? widget.chat!['group_category'].toString().trim().toLowerCase()
                  : (provider?.chat?['category']?.toString().trim().isNotEmpty == true
                      ? provider!.chat!['category'].toString().trim().toLowerCase()
                      : 'general')));

      final String resolvedPrivacy = (widget.privacy?.trim().isNotEmpty == true)
          ? widget.privacy!.trim().toLowerCase()
          : (widget.chat?['privacy']?.toString().trim().isNotEmpty == true
              ? widget.chat!['privacy'].toString().trim().toLowerCase()
              : (widget.chat?['group_privacy']?.toString().trim().isNotEmpty == true
                  ? widget.chat!['group_privacy'].toString().trim().toLowerCase()
                  : (provider?.chat?['privacy']?.toString().trim().isNotEmpty == true
                      ? provider!.chat!['privacy'].toString().trim().toLowerCase()
                      : 'public')));

      try {
        final response = await ApiService().updateGroupInfo(
          groupChatId: resolvedChatId.toString(),
          title: resolvedTitle,
          description: resolvedDescription,
          category: resolvedCategory,
          privacy: resolvedPrivacy,
          chatTheme: selectedTheme.id,
        );

        if (response['status'] == 'error') {
          final errorMsg = response['message']?.toString() ?? 'Validation failed';
          throw Exception(errorMsg);
        }

        provider?.setTheme(selectedTheme);
        if (widget.chat != null) {
          widget.chat!['chat_theme'] = selectedTheme.id;
        }
        if (provider?.chat != null) {
          provider!.chat!['chat_theme'] = selectedTheme.id;
        }
        if (mounted) {
          showToast(message: 'Theme changed!');
          Navigator.pop(context, selectedTheme);
        }
      } catch (e) {
        if (mounted) {
          showToast(message: e.toString().replaceAll('Exception: ', ''));
          setState(() => _isLoading = false);
        }
      }
    } else {
      provider?.setTheme(selectedTheme);
      if (widget.chat != null) {
        widget.chat!['chat_theme'] = selectedTheme.id;
      }
      if (provider?.chat != null) {
        provider!.chat!['chat_theme'] = selectedTheme.id;
      }
      Navigator.pop(context, selectedTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:  CommonAppBar(title: AppLocalizations.of(context)!.customizetheme),
      body: SafeArea(
        child: GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          physics: const BouncingScrollPhysics(),
          itemCount: _themes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14.w,
            mainAxisSpacing: 14.h,
            childAspectRatio: 1.5,
          ),
          itemBuilder: (context, index) {
            final theme = _themes[index];
            final isSelected = _selectedIndex == index;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: theme.getBgColor(isDarkMode),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onPrimary,
                          width: 1,
                        )
                      : Border.all(
                          color: theme.getUnselectedBorderColor(isDarkMode) ??
                              (isDarkMode
                                  ? Theme.of(context).colorScheme.outline
                                  : Colors.transparent),
                          width: 1,
                        ),
                ),
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Incoming message bubble (aligned left)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ClipPath(
                              clipper: const _IncomingBubbleClipper(),
                              child: Container(
                                width: 80.w,
                                height: 22.h,
                                color: theme.getIncomingColor(isDarkMode),
                              ),
                            ),
                          ),
                          SizedBox(height: 15.h),
                          // Outgoing message bubble (aligned right)
                          Align(
                            alignment: Alignment.centerRight,
                            child: ClipPath(
                              clipper: const _OutgoingBubbleClipper(),
                              child: Container(
                                width: 68.w,
                                height: 22.h,
                                color: theme.getOutgoingColor(isDarkMode),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: Container(
                          width: 18.w,
                          height: 18.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.onPrimary,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 8.5.w,
                            height: 8.5.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 25),
        height: 90,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.applytheme,
          onPressed: (_isLoading || !_hasChanged) ? null : _applyTheme,
          isLoading: _isLoading,
        ),
      ),
    );
  }
}

/// Custom clipper for incoming chat bubble (top-left tail)
class _IncomingBubbleClipper extends CustomClipper<Path> {
  const _IncomingBubbleClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const double radius = 7.0;
    const double tailWidth = 3.5;

    // Start near top-left after the tail
    path.moveTo(tailWidth + radius, 0);
    // Top line
    path.lineTo(size.width - radius, 0);
    // Top-right corner
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    // Right edge
    path.lineTo(size.width, size.height - radius);
    // Bottom-right corner
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - radius,
      size.height,
    );
    // Bottom edge
    path.lineTo(tailWidth + radius, size.height);
    // Bottom-left corner
    path.quadraticBezierTo(
      tailWidth,
      size.height,
      tailWidth,
      size.height - radius,
    );
    // Left edge going up towards tail
    path.lineTo(tailWidth, 6);
    // Tail curving to top-left tip
    path.quadraticBezierTo(tailWidth * 0.4, 2, 0, 0);
    // Tail top curve back to main top edge
    path.quadraticBezierTo(tailWidth * 0.7, 0, tailWidth + radius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom clipper for outgoing chat bubble (bottom-right tail)
class _OutgoingBubbleClipper extends CustomClipper<Path> {
  const _OutgoingBubbleClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    const double radius = 7.0;
    const double tailWidth = 3.5;

    // Top-left corner
    path.moveTo(radius, 0);
    // Top line
    path.lineTo(size.width - tailWidth - radius, 0);
    // Top-right corner
    path.quadraticBezierTo(
      size.width - tailWidth,
      0,
      size.width - tailWidth,
      radius,
    );
    // Right edge going down towards tail
    path.lineTo(size.width - tailWidth, size.height - 6);
    // Tail curving to bottom-right tip
    path.quadraticBezierTo(
      size.width - tailWidth * 0.4,
      size.height - 2,
      size.width,
      size.height,
    );
    // Tail bottom curve back to bottom edge
    path.quadraticBezierTo(
      size.width - tailWidth * 0.7,
      size.height,
      size.width - tailWidth - radius,
      size.height,
    );
    // Bottom edge
    path.lineTo(radius, size.height);
    // Bottom-left corner
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    // Left edge
    path.lineTo(0, radius);
    // Top-left corner back
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
