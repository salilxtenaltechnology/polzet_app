// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../../../api/api_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart'
    hide FontAwesomeIcons;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/constants/app_radius.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../widgets/show_toast.dart';
import '../../../api/services/api_service.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../loader.dart';

class ShareBottomSheet extends StatefulWidget {
  final String shareLink;
  final String username;
  final String postId;
  final Function(int newCount)? onShareSuccess;

  const ShareBottomSheet({
    super.key,
    required this.shareLink,
    required this.username,
    this.postId = '',
    this.onShareSuccess,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final ApiService _apiServices = ApiService();
  final Set<dynamic> _selectedUserIds = {};
  final Set<dynamic> _selectedGroupIds = {};
  bool _isSending = false;

  static List<Map<String, dynamic>> _cachedTargets = [];
  static bool _hasLoadedOnce = false;

  List<Map<String, dynamic>> _allUsers = _cachedTargets;
  List<Map<String, dynamic>> _filteredUsers = _cachedTargets;
  bool _isLoadingUsers = !_hasLoadedOnce;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_onSearch);
  }

  Future<void> _fetchUsers() async {
    try {
      final results = await Future.wait([
        _apiServices.getFollowersList(),
        _apiServices.getFollowingList(),
        _apiServices.getChatList(),
      ]);

      final followers = results[0];
      final following = results[1];
      final chats = results[2];

      final seen = <dynamic>{};
      final merged = <Map<String, dynamic>>[];

      // Add group chats first
      for (final chat in chats) {
        if (chat['chat_type']?.toString() == 'group') {
          final id = chat['id'];
          if (id != null && seen.add('group_$id')) {
            merged.add({...chat, 'is_group': true});
          }
        }
      }

      // Add followers/following users
      for (final user in [...followers, ...following]) {
        final id = user['id'];
        if (id != null && seen.add('user_$id')) {
          merged.add(user);
        }
      }

      _cachedTargets = merged;
      _hasLoadedOnce = true;

      if (mounted) {
        setState(() {
          _allUsers = merged;
          final query = _searchController.text.trim().toLowerCase();
          _filteredUsers = query.isEmpty
              ? merged
              : merged
                    .where((u) => _userName(u).toLowerCase().contains(query))
                    .toList();
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = query.isEmpty
          ? _allUsers
          : _allUsers
                .where((u) => _userName(u).toLowerCase().contains(query))
                .toList();
    });
  }

  String _userName(Map<String, dynamic> item) {
    if (item['is_group'] == true) {
      return (item['title'] ?? item['name'] ?? 'Unnamed Group').toString();
    }
    return (item['name'] ?? item['username'] ?? item['full_name'] ?? 'Unknown')
        .toString();
  }

  String? _resolveProfileUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    if (!url.startsWith('http') && !url.startsWith('data:image')) {
      if (url.startsWith('/')) {
        return '${ApiConfig.baseUrlImage}$url';
      } else {
        return '${ApiConfig.baseUrlImage}/$url';
      }
    }
    return url;
  }

  String? _userAvatar(Map<String, dynamic> item) {
    final String? avatar;
    if (item['is_group'] == true) {
      avatar =
          (item['profile_url'] ?? item['group_picture_url'] ?? item['avatar'])
              ?.toString();
    } else {
      avatar = (item['avatar'] ?? item['profile_picture_url'] ?? item['image'])
          ?.toString();
    }
    return _resolveProfileUrl(avatar);
  }

  Future<void> _shareToWhatsApp() async {
    final text = Uri.encodeComponent(widget.shareLink);

    // Try deep link first (opens WhatsApp directly)
    final whatsappUri = Uri.parse('whatsapp://send?text=$text');
    // Fallback universal link
    final fallbackUri = Uri.parse('https://wa.me/?text=$text');

    try {
      bool launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );

      if (!launched) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Deep link failed, try universal link
      try {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        showToast(message: 'Could not open WhatsApp');
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareToInstagram() async {
    final url = Uri.parse('instagram://');
    final fallbackUrl = Uri.parse('https://www.instagram.com/');

    try {
      await Clipboard.setData(ClipboardData(text: widget.shareLink));

      bool launched = false;
      try {
        launched = await launchUrl(
          url,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (_) {
        // Ignored, will try fallback below
      }

      if (!launched) {
        try {
          launched = await launchUrl(
            fallbackUrl,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          launched = false;
        }
      }

      if (!launched) {
        showToast(message: 'Instagram is not installed');
      } else {
        showToast(message: 'Link copied! Paste it in Instagram.');
      }
    } catch (_) {
      showToast(message: 'Instagram is not installed');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _shareToGmail() async {
    final subject = widget.postId.isEmpty
        ? 'Polzet Profile of @${widget.username}'
        : 'Post from @${widget.username}';
    final url = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(widget.shareLink)}',
    );
    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        showToast(message: 'Could not open email app');
      }
    } catch (_) {
      showToast(message: 'Could not open email app');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.shareLink));
    showToast(message: 'Link copied');
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendToSelectedUsers() async {
    if (_selectedUserIds.isEmpty && _selectedGroupIds.isEmpty) return;
    setState(() => _isSending = true);

    try {
      final text = _messageController.text.trim();
      final msg = text.isEmpty ? 'Check out this post!' : text;

      bool anySuccess = false;
      for (final userId in _selectedUserIds) {
        final chatResponse = await _apiServices.createPrivateChatId(
          withUserId: userId.toString(),
        );

        final chatId = int.tryParse(chatResponse['id']?.toString() ?? '');
        if (chatId != null) {
          if (widget.postId.isEmpty) {
            // Sharing profile: send message with shareLink
            await _apiServices.sendMessage(
              chatId: chatId,
              text: text.isEmpty
                  ? widget.shareLink
                  : '$text\n${widget.shareLink}',
            );
            anySuccess = true;
          } else {
            // Sharing post
            final shareResponse = await _apiServices.sharePostMessage(
              chatId: chatId,
              sharedPostId: widget.postId,
              message: msg,
            );

            if (shareResponse['status'] == 'success') {
              anySuccess = true;
              final newCount = await _apiServices.addShareCount(
                postId: widget.postId,
              );
              if (newCount != null && widget.onShareSuccess != null) {
                widget.onShareSuccess!(newCount);
              }
            }
          }
        }
      }

      for (final groupId in _selectedGroupIds) {
        final chatId = int.tryParse(groupId.toString());
        if (chatId != null) {
          if (widget.postId.isEmpty) {
            // Sharing profile: send message with shareLink
            await _apiServices.sendMessage(
              chatId: chatId,
              text: text.isEmpty
                  ? widget.shareLink
                  : '$text\n${widget.shareLink}',
            );
            anySuccess = true;
          } else {
            // Sharing post
            final shareResponse = await _apiServices.sharePostMessage(
              chatId: chatId,
              sharedPostId: widget.postId,
              message: msg,
            );

            if (shareResponse['status'] == 'success') {
              anySuccess = true;
              final newCount = await _apiServices.addShareCount(
                postId: widget.postId,
              );
              if (newCount != null && widget.onShareSuccess != null) {
                widget.onShareSuccess!(newCount);
              }
            }
          }
        }
      }

      if (anySuccess) {
        showToast(
          message: widget.postId.isEmpty ? 'Profile shared' : 'Post sent',
        );
      } else {
        showToast(
          message: widget.postId.isEmpty
              ? 'Failed to share profile'
              : 'Failed to share post',
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      showToast(
        message: widget.postId.isEmpty
            ? 'Failed to share profile'
            : 'Failed to share post',
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: 0.8.sh,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.modal),
            topRight: Radius.circular(AppRadius.modal),
          ),
        ),
        child: Column(
          children: [
            // Drag Handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0XFF767676),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchusers,
                    hintStyle: AppTextStyles.bodyText.copyWith(
                      color: const Color(0XFF898989),
                      fontSize: 14.5,
                    ),
                    prefixIcon: const Icon(
                      FeatherIcons.search,
                      size: 18,
                      color: Color(0XFF898989),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(top: 10, bottom: 10),
                  ),
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Users Grid
            Expanded(
              child: _isLoadingUsers
                  ? Center(
                      child: Loader(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : _filteredUsers.isEmpty
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.nousersfound,
                        style: AppTextStyles.bodyText.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final item = _filteredUsers[index];
                        final avatarUrl = _userAvatar(item);
                        final name = _userName(item);
                        final isGroup = item['is_group'] == true;

                        final isSelected = isGroup
                            ? _selectedGroupIds.contains(item['id'])
                            : _selectedUserIds.contains(item['id']);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              final id = item['id'];
                              if (isGroup) {
                                if (isSelected) {
                                  _selectedGroupIds.remove(id);
                                } else {
                                  _selectedGroupIds.add(id);
                                }
                              } else {
                                if (isSelected) {
                                  _selectedUserIds.remove(id);
                                } else {
                                  _selectedUserIds.add(id);
                                }
                              }
                            });
                          },
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  if (isGroup &&
                                      (avatarUrl == null ||
                                          avatarUrl.trim().isEmpty))
                                    _buildGroupAvatarStack(
                                      members: item['members'] as List?,
                                      size: 60,
                                      isDarkMode: isDarkMode,
                                      context: context,
                                    )
                                  else
                                    Builder(
                                      builder: (_) {
                                        final imageBytes = avatarUrl != null
                                            ? getProfileImage(avatarUrl)
                                            : null;
                                        final hasNetworkImage =
                                            imageBytes == null &&
                                            avatarUrl != null &&
                                            avatarUrl.trim().isNotEmpty &&
                                            avatarUrl.startsWith('http');
                                        final initial = name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?';

                                        return Container(
                                          height: 60,
                                          width: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                (imageBytes == null &&
                                                    !hasNetworkImage)
                                                ? (isDarkMode
                                                      ? const Color(0xFF343434)
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withOpacity(0.1))
                                                : null,
                                            image: imageBytes != null
                                                ? DecorationImage(
                                                    image: MemoryImage(
                                                      imageBytes,
                                                    ),
                                                    fit: BoxFit.cover,
                                                  )
                                                : (hasNetworkImage
                                                      ? DecorationImage(
                                                          image: NetworkImage(
                                                            avatarUrl,
                                                          ),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.05),
                                            ),
                                          ),
                                          child:
                                              (imageBytes == null &&
                                                  !hasNetworkImage)
                                              ? Center(
                                                  child: Text(
                                                    initial,
                                                    style: TextStyle(
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onPrimary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                  if (isGroup &&
                                      !(avatarUrl == null ||
                                          avatarUrl.trim().isEmpty))
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.background,
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.group,
                                          color: Colors.white,
                                          size: 10,
                                        ),
                                      ),
                                    ),
                                  if (isSelected)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.background,
                                            width: 1.5,
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: txt.title,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Divider
            Divider(
              color: Theme.of(context).colorScheme.outlineVariant,
              height: 1,
            ),

            if (_selectedUserIds.isEmpty && _selectedGroupIds.isEmpty)
              // Share Options
              Padding(
                padding: EdgeInsets.only(
                  top: 5.h,
                  bottom: 15.h,
                  left: 20,
                  right: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShareOption(
                      iconWidget: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF25D366),
                        size: 32,
                      ),
                      label: 'Whatsapp',
                      onTap: _shareToWhatsApp,
                    ),
                    _buildShareOption(
                      iconWidget: const FaIcon(
                        FontAwesomeIcons.instagram,
                        color: Color(0xFFE1306C),
                        size: 32,
                      ),
                      label: 'Instagram',
                      onTap: _shareToInstagram,
                    ),
                    _buildShareOption(
                      iconWidget: Image.asset(
                        'assets/images/ic_google.png',
                        height: 30,
                        width: 30,
                      ),
                      label: 'Gmail',
                      onTap: _shareToGmail,
                    ),
                    _buildShareOption(
                      iconWidget: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF343434)
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          FeatherIcons.link,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                      label: 'Copy link',
                      onTap: _copyLink,
                    ),
                  ],
                ),
              )
            else
              // Send Message Area
              Padding(
                padding: EdgeInsets.only(
                  top: 15.h,
                  bottom: 30.h,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Write a message.....',
                        hintStyle: AppTextStyles.bodyText.copyWith(
                          color: const Color(0XFF898989),
                          fontSize: 14.5,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.outline
                                : const Color(0XFFE5E5E5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? Theme.of(context).colorScheme.outline
                                : const Color(0XFFE5E5E5),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendToSelectedUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Send',
                                style: AppTextStyles.bodyText.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    final txt = AppTextColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: iconWidget),
          ),
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: txt.title,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupAvatarStack({
    required List<dynamic>? members,
    required double size,
    required bool isDarkMode,
    required BuildContext context,
  }) {
    final List<String?> profileUrls = [];
    final List<String> initials = [];

    if (members != null) {
      for (final member in members) {
        if (profileUrls.length >= 2) break;
        final user = member is Map ? member['user'] as Map? : null;
        if (user != null) {
          final profileUrl =
              (user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['avatar'])
                  ?.toString();
          final name = (user['name'] ?? user['username'] ?? 'Unknown')
              .toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
        }
      }
    }

    if (profileUrls.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode
              ? const Color(0xFF343434)
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
        child: Center(
          child: Icon(
            Icons.group,
            size: size * 0.5,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    final double circleSize = size * 0.75;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _buildSingleAvatarCircle(
              profileUrl: profileUrls[0],
              initial: initials[0],
              size: circleSize,
              isDarkMode: isDarkMode,
              context: context,
            ),
          ),
          if (profileUrls.length > 1)
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildSingleAvatarCircle(
                profileUrl: profileUrls[1],
                initial: initials[1],
                size: circleSize,
                isDarkMode: isDarkMode,
                context: context,
                hasBorder: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleAvatarCircle({
    required String? profileUrl,
    required String initial,
    required double size,
    required bool isDarkMode,
    required BuildContext context,
    bool hasBorder = false,
  }) {
    final resolvedUrl = _resolveProfileUrl(profileUrl);
    final imageBytes = resolvedUrl != null
        ? getProfileImage(resolvedUrl)
        : null;
    final hasNetworkImage =
        imageBytes == null &&
        resolvedUrl != null &&
        resolvedUrl.isNotEmpty &&
        resolvedUrl.startsWith('http');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (imageBytes == null && !hasNetworkImage)
            ? (isDarkMode
                  ? const Color(0xFF343434)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1))
            : null,
        border: hasBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                width: 1.5,
              )
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.05),
                width: 1,
              ),
        image: imageBytes != null
            ? DecorationImage(image: MemoryImage(imageBytes), fit: BoxFit.cover)
            : (hasNetworkImage
                  ? DecorationImage(
                      image: NetworkImage(resolvedUrl),
                      fit: BoxFit.cover,
                    )
                  : null),
      ),
      child: (imageBytes == null && !hasNetworkImage)
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: size * 0.4,
                ),
              ),
            )
          : null,
    );
  }
}
