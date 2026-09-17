// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:polzet_app/api/api_config.dart';
import 'package:polzet_app/api/api_service.dart';
import 'package:polzet_app/api/services/share/share_service.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/gen/assets.gen.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';
import 'package:polzet_app/models/public/public_profile_model.dart';
import 'package:polzet_app/provider/private_chat_provider.dart';
import 'package:polzet_app/provider/user_provider.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import 'package:polzet_app/widgets/dialog/custom_diolog.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import '../../../../../../widgets/tabbar/indicatore_animation.dart';
import '../../../../home_imports.dart';
import '../../../message_list.dart';
import '../../../../profile/public/public_profile_screen.dart';
import '../../../../profile/widgets/profile_image_preview.dart';
import 'private_chat_theme.dart';
import 'private_user_mute_notification.dart';
import 'private_user_privacy_safety.dart';
import 'private_user_report.dart';

class PrivateUserInfo extends StatefulWidget {
  final dynamic userId;
  final dynamic chatId;
  final String? name;
  final String? username;
  final String? profileUrl;
  final Map<String, dynamic>? chat;
  final bool isUserBlock;
  final PrivateChatProvider? privateChatProvider;

  const PrivateUserInfo({
    super.key,
    this.userId,
    this.chatId,
    this.name,
    this.username,
    this.profileUrl,
    this.chat,
    this.isUserBlock = false,
    this.privateChatProvider,
  });

  @override
  State<PrivateUserInfo> createState() => _PrivateUserInfoState();
}

class _PrivateUserInfoState extends State<PrivateUserInfo>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final ApiService _apiService = ApiService();
  late final TabController _tabController;
  ProfileData? _profileData;
  late bool _isUserBlock;
  late bool _isMuted;

  bool _toBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val != 0;
    final str = val.toString().toLowerCase().trim();
    return str == 'true' || str == '1';
  }

  bool _parseIsMuted(dynamic val, Map<String, dynamic>? data) {
    if (data != null) {
      final muted = data['is_muted'] ?? data['is_mute'] ?? data['isMuted'];
      if (muted != null) return _toBool(muted);
    }
    return _toBool(val);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isUserBlock = widget.isUserBlock;
    if (!_isUserBlock && widget.chat != null) {
      _isUserBlock = _getIsBlockedFromChat(widget.chat);
    }
    _isMuted = _parseIsMuted(
      widget.privateChatProvider?.isMuteNotification,
      widget.chat,
    );
    _fetchUserInfo();
  }

  @override
  void didUpdateWidget(covariant PrivateUserInfo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat != widget.chat ||
        oldWidget.privateChatProvider != widget.privateChatProvider) {
      _isMuted = _parseIsMuted(
        widget.privateChatProvider?.isMuteNotification,
        widget.chat,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _getIsBlockedFromChat(Map<String, dynamic>? chat) {
    if (chat == null) return false;
    final members = chat['members'] as List?;
    if (members == null) return false;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();

      for (final m in members) {
        if (m is Map) {
          final user = m['user'] as Map?;
          final username = user?['username']?.toString().toLowerCase();
          final id = (user?['uuid'] ?? user?['id'])?.toString();
          if (id != currentUserId &&
              (currentUsername == null || username != currentUsername)) {
            return (m['is_block'] == true) ||
                (m['is_blocked'] == true) ||
                (user?['is_blocked'] == true) ||
                (user?['is_block'] == true);
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Map<String, dynamic>? _getOtherMemberUser() {
    if (widget.chat == null) return null;
    final members = widget.chat!['members'] as List?;
    if (members == null) return null;
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();

      for (final m in members) {
        if (m is Map) {
          final user =
              m['user'] as Map<String, dynamic>? ??
              (m is Map<String, dynamic> && m.containsKey('username')
                  ? m
                  : null);
          if (user != null) {
            final username = user['username']?.toString().toLowerCase();
            final id = (user['uuid'] ?? user['id'])?.toString();
            if (id != currentUserId &&
                (currentUsername == null || username != currentUsername)) {
              return user;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  dynamic _getTargetUserId() {
    if (widget.userId != null) return widget.userId;
    if (_profileData != null) {
      if (_profileData!.userId.isNotEmpty) return _profileData!.userId;
      if (_profileData!.id.isNotEmpty) return _profileData!.id;
    }
    final otherUser = _getOtherMemberUser();
    if (otherUser != null) {
      final id = otherUser['uuid'] ?? otherUser['id'];
      if (id != null) return id;
    }
    return null;
  }

  bool _isPolzetAiUsername(String? username) {
    if (username == null) return false;
    final u = username.trim().toLowerCase();
    return u == 'polzet_ai' ||
        u == 'polet_ai' ||
        u == 'polzet ai' ||
        u == 'polzet-ai';
  }

  bool _isPolzetAiChat() {
    if (_isPolzetAiUsername(widget.username)) return true;
    if (_isPolzetAiUsername(widget.name)) return true;
    if (widget.chat != null) {
      final title = widget.chat!['title']?.toString();
      if (_isPolzetAiUsername(title)) return true;
      final displayName = widget.chat!['display_name']?.toString();
      if (_isPolzetAiUsername(displayName)) return true;
    }
    return false;
  }

  Future<void> _fetchUserInfo() async {
    final otherUser = _getOtherMemberUser();
    final identifier =
        (widget.username != null && widget.username!.trim().isNotEmpty)
        ? widget.username!
        : (otherUser?['username']?.toString() ??
              widget.userId?.toString() ??
              _getTargetUserId()?.toString());
    if (identifier == null || identifier.trim().isEmpty) return;
    if (_isPolzetAiUsername(identifier) || _isPolzetAiUsername(widget.name)) {
      return;
    }

    try {
      final response = await ApiService.getUserPublicProfile(identifier);
      if (response.status == 'success' && mounted) {
        setState(() {
          _profileData = response.data;
          _isUserBlock = response.data.isBlocked;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user info in PrivateUserInfo: $e');
    }
  }

  Future<void> _showClearChatConfirmationDialog() async {
    showClearChatDiolog(context, () {
      Navigator.pop(context);
      _clearChatMessages();
    });
  }

  Future<void> _clearChatMessages() async {
    final chatId =
        widget.chatId?.toString() ??
        widget.chat?['id']?.toString() ??
        _profileData?.chatId?.toString();
    if (chatId == null || chatId.isEmpty) {
      showToast(message: 'Cannot clear a new chat');
      return;
    }

    // Instantly remove messages locally from provider & message list for immediate UI feedback
    PrivateChatProvider? provider =
        widget.privateChatProvider ?? _getPrivateProvider();
    provider?.clearLocalMessages();
    MessageListState.clearChatLocally(chatId);

    try {
      showToast(message: 'Clearing chat...');
      final response = await _apiService.clearChat(chatId: chatId);
      if (response['status'] == 'success' || response['success'] == true) {
        provider?.clearLocalMessages();
        MessageListState.clearChatLocally(chatId);
        showToast(message: 'Chat cleared');
      } else {
        showToast(
          message: response['message']?.toString() ?? 'Failed to clear chat',
        );
      }
    } catch (e) {
      showToast(message: 'Failed to clear chat: $e');
    }
  }

  Future<void> _showDeleteChatConfirmationDialog() async {
    showDeleteChatDiolog(context, () {
      Navigator.pop(context);
      _deleteChat();
    });
  }

  Future<void> _deleteChat() async {
    final chatId =
        widget.chatId?.toString() ??
        widget.chat?['id']?.toString() ??
        _profileData?.chatId?.toString();
    if (chatId == null || chatId.isEmpty) return;

    try {
      showToast(message: 'Deleting chat...');
      final response = await _apiService.deleteChat(chatId: chatId);
      if (response['status'] == 'success' || response['success'] == true) {
        MessageListState.removeChatLocally(chatId);
        showToast(message: 'Chat deleted');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeScreen(initialIndex: 1),
            ),
            (route) => false,
          );
        }
      } else {
        showToast(
          message: response['message']?.toString() ?? 'Failed to delete chat',
        );
      }
    } catch (e) {
      showToast(message: 'Failed to delete chat: $e');
    }
  }

  Future<void> _toggleBlockUser() async {
    showBlockUserDiolog(context, () async {
      final wasBlocked = _isUserBlock;
      Navigator.pop(context);
      if (mounted) setState(() => _isUserBlock = !wasBlocked);
      final targetId = _getTargetUserId();
      if (targetId == null) {
        showToast(message: 'User ID not found');
        return;
      }
      final result = wasBlocked
          ? await _apiService.unblockUser(targetId)
          : await _apiService.blockUser(targetId);
      if (mounted) {
        if (result['success'] == true || result['status'] == 'success') {
          showToast(message: wasBlocked ? 'User unblocked' : 'User blocked');
        } else {
          setState(() => _isUserBlock = wasBlocked);
          showToast(message: result['message']?.toString() ?? 'Action failed');
        }
      }
    }, _isUserBlock);
  }

  PrivateChatProvider? _getPrivateProvider() {
    try {
      return Provider.of<PrivateChatProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  String get _displayName {
    if (_profileData != null) {
      final fullName = '${_profileData!.firstName} ${_profileData!.lastName}'
          .trim();
      if (fullName.isNotEmpty) return fullName;
      if (_profileData!.username.isNotEmpty) return _profileData!.username;
    }
    final otherUser = _getOtherMemberUser();
    if (otherUser != null) {
      final name =
          otherUser['name']?.toString() ??
          (otherUser['first_name'] != null
              ? '${otherUser['first_name']} ${otherUser['last_name'] ?? ''}'
                    .trim()
              : null) ??
          otherUser['full_name']?.toString();
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    final privateProvider = _getPrivateProvider();
    if (widget.name != null &&
        widget.name!.trim().isNotEmpty &&
        widget.name != widget.username) {
      return widget.name!;
    }
    if (privateProvider?.memberName != null &&
        privateProvider!.memberName!.trim().isNotEmpty &&
        privateProvider.memberName != widget.username) {
      return privateProvider.memberName!;
    }
    final title =
        widget.chat?['title']?.toString() ??
        widget.chat?['display_name']?.toString();
    if (title != null && title.trim().isNotEmpty && title != widget.username) {
      return title;
    }
    if (widget.name != null && widget.name!.trim().isNotEmpty) {
      return widget.name!;
    }
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username!;
    }
    return 'User';
  }

  String get _displayUsername {
    if (_profileData != null && _profileData!.username.isNotEmpty) {
      return _profileData!.username;
    }
    final otherUser = _getOtherMemberUser();
    final memberUsername = otherUser?['username']?.toString();
    if (memberUsername != null && memberUsername.trim().isNotEmpty) {
      return memberUsername.trim();
    }
    if (widget.username != null && widget.username!.trim().isNotEmpty) {
      return widget.username!;
    }
    final u = widget.chat?['username']?.toString();
    if (u != null && u.trim().isNotEmpty) {
      return u;
    }
    return _displayName;
  }

  String? get _resolvedProfileUrl {
    if (_profileData != null) {
      final p = _profileData!.profilePictureUrl ?? _profileData!.profilePicture;
      if (p != null && p.trim().isNotEmpty && p != 'null') return p;
    }
    final otherUser = _getOtherMemberUser();
    if (otherUser != null) {
      final p =
          otherUser['avatar_url']?.toString() ??
          otherUser['profile_url']?.toString() ??
          otherUser['profile_picture']?.toString() ??
          otherUser['profile_picture_url']?.toString();
      if (p != null && p.trim().isNotEmpty && p != 'null') return p;
    }
    final privateProvider = _getPrivateProvider();
    final p =
        widget.profileUrl ??
        privateProvider?.profileUrl ??
        widget.chat?['profile_url']?.toString() ??
        widget.chat?['profile_picture']?.toString() ??
        widget.chat?['profile_picture_url']?.toString();
    if (p != null && p.trim().isNotEmpty && p != 'null') return p;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _isUserBlock);
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title: 'Chat Info',
          onBack: () => Navigator.pop(context, _isUserBlock),
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      SizedBox(height: 10.h),
                      // ── Profile Avatar ──────────────────────────────────
                      Center(child: _buildAvatar(isDarkMode: isDarkMode)),
                      SizedBox(height: 14.h),

                      // ── Full Name ───────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _displayName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.cardTitle.copyWith(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                            ),
                          ),
                          if (_isPolzetAiChat()) ...[
                            SizedBox(width: 4.w),
                            Image.asset(
                              Assets.images.icVerify.path,
                              height: 14.w,
                              width: 14.w,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),

                      // ── Username / Handle ───────────────────────────────
                      Text(
                        _displayUsername.startsWith('@')
                            ? _displayUsername
                            : '@$_displayUsername',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 12.sp,
                          color: txt.muted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 10.h),

                      // ── Actions Row (Profile, Search, Mute, More) ───────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Assets.images.icChatProfile.path,
                            label: 'Profile',
                            txt: txt,
                            onTap: () {
                              final targetUserId = _getTargetUserId();
                              if (targetUserId != null ||
                                  _displayUsername.isNotEmpty) {
                                navigationPush(
                                  context,
                                  PublicProfileScreen(
                                    userId: targetUserId?.toString(),
                                    username: _displayUsername,
                                  ),
                                );
                              }
                            },
                          ),
                          _buildActionButton(
                            icon: Assets.images.icSearch.path,
                            label: 'Search',
                            txt: txt,
                            onTap: () {},
                          ),
                          _buildActionButton(
                            icon: Assets.images.icMute.path,
                            label: 'Mute',
                            txt: txt,
                            onTap: () async {
                              final resolvedChatId =
                                  widget.chatId ??
                                  widget.chat?['id'] ??
                                  _profileData?.chatId;
                              final result = await navigationPush(
                                context,
                                PrivateUserMuteNotification(
                                  chatId: resolvedChatId,
                                  isMute: _isMuted,
                                  userData: widget.chat,
                                ),
                              );
                              if (result != null && mounted) {
                                final bool newMute = result == true;
                                setState(() {
                                  _isMuted = newMute;
                                });
                                widget.privateChatProvider
                                    ?.toggleMuteNotification(newMute);
                                if (resolvedChatId != null) {
                                  MessageListState.toggleMuteChatLocally(
                                    resolvedChatId,
                                    newMute,
                                  );
                                }
                              }
                            },
                          ),
                          Theme(
                            data: Theme.of(context).copyWith(
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: PopupMenuButton<String>(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              offset: const Offset(0, 45),
                              elevation: 2,
                              padding: EdgeInsets.zero,
                              onSelected: (value) {
                                if (value == 'share') {
                                  ShareService.shareProfile(
                                    username: _displayUsername,
                                    context: context,
                                    profileId:
                                        _getTargetUserId()?.toString() ?? '',
                                  );
                                } else if (value == 'report') {
                                  navigationPush(
                                    context,
                                    const PrivateUserReport(),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                return [
                                  PopupMenuItem<String>(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      0,
                                      10,
                                      0,
                                    ),
                                    height: 38,
                                    value: 'share',
                                    child: Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.shareprofile ??
                                          'Share Profile',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: txt.title,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      0,
                                      10,
                                      0,
                                    ),
                                    height: 38,
                                    value: 'report',
                                    child: Text(
                                      AppLocalizations.of(context)?.report ??
                                          'Report',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: const Color(0XFFE5484D),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ];
                              },
                              child: _buildActionButton(
                                icon: Assets.images.icMoreHorizontal.path,
                                label: 'More',
                                txt: txt,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),

                      // ── Options List Tiles ──────────────────────────────
                      Builder(
                        builder: (context) {
                          final privateProvider =
                              widget.privateChatProvider ?? _getPrivateProvider();
                          final currentTheme = privateProvider?.currentTheme ??
                              ChatThemeItem.fromIdOrName(widget.chat?['chat_theme']);
                          final themeColor = currentTheme != null
                              ? currentTheme.getOutgoingColor(isDarkMode)
                              : const Color(0xFF8B263E);

                          return _buildOptionTile(
                            iconWidget: Container(
                              width: 22.w,
                              height: 22.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: themeColor,
                              ),
                            ),
                            title: 'Customize Theme',
                            subtitle: 'Your can change color and theme of chat',
                            isDarkMode: isDarkMode,
                            txt: txt,
                            onTap: () async {
                              final provider =
                                  widget.privateChatProvider ?? _getPrivateProvider();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => provider != null
                                      ? ChangeNotifierProvider.value(
                                          value: provider,
                                          child: PrivateChatTheme(
                                            chatId: widget.chatId ??
                                                widget.chat?['id'] ??
                                                provider.chatId,
                                            privateChatProvider: provider,
                                            chatTheme: widget.chat?['chat_theme'],
                                            chat: widget.chat,
                                          ),
                                        )
                                      : PrivateChatTheme(
                                          chatId: widget.chatId ??
                                              widget.chat?['id'],
                                          chatTheme: widget.chat?['chat_theme'],
                                          chat: widget.chat,
                                        ),
                                ),
                              );
                              if (result is ChatThemeItem) {
                                provider?.setTheme(result);
                                if (widget.chat != null) {
                                  widget.chat!['chat_theme'] = result.id;
                                }
                              }
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      ),
                      _buildOptionTile(
                        iconWidget: Image.asset(
                          Assets.images.icSecurity.path,
                          color: Theme.of(context).colorScheme.onPrimary,
                          width: 17.w,
                          height: 17.w,
                        ),
                        title: 'Privacy & Safety',
                        subtitle: 'Anyone can discover and view this group',
                        isDarkMode: isDarkMode,
                        txt: txt,
                        onTap: () {
                          navigationPush(
                            context,
                            PrivateUserPrivacySafety(chatId: widget.chatId),
                          );
                        },
                      ),
                      _buildDestructiveAction(
                        icon: Assets.images.icClearChat.path,

                        title: 'Clear Chat',
                        onTap: _showClearChatConfirmationDialog,
                      ),
                      _buildDestructiveAction(
                        icon: Assets.images.icDelete.path,

                        title: 'Delete Chat',
                        onTap: _showDeleteChatConfirmationDialog,
                      ),
                      _buildDestructiveAction(
                        icon: Assets.images.icChatinfoBlock.path,

                        title: _isUserBlock
                            ? (AppLocalizations.of(context)?.unblock ??
                                  'Unblock')
                            : (AppLocalizations.of(context)?.block ?? 'Block'),
                        onTap: _toggleBlockUser,
                      ),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),

              // ── Sticky TabBar ───────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.onBackground,
                    labelStyle: AppTextStyles.bodyText.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    indicator: FadeUnderlineTabIndicator(),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onBackground.withOpacity(0.5),
                    tabs: const [
                      Tab(text: 'Media'),
                      Tab(text: 'Link'),
                      Tab(text: 'Documents'),
                    ],
                  ),
                  backgroundColor: Theme.of(context).colorScheme.background,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMediaTab(isDarkMode: isDarkMode),
              _buildLinkTab(txt: txt, isDarkMode: isDarkMode),
              _buildDocumentsTab(txt: txt, isDarkMode: isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfileImagePreview() {
    final String currentUsername = _displayUsername.trim().toLowerCase();
    if (_isPolzetAiChat() || _isPolzetAiUsername(currentUsername)) return;

    final String? originalImageSource = _resolvedProfileUrl;
    if (originalImageSource == null ||
        originalImageSource.trim().isEmpty ||
        originalImageSource == 'null' ||
        originalImageSource == Assets.images.icAvatar.path) {
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfileImagePreview(
            imageSource: originalImageSource,
            username: _displayUsername,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildAvatar({required bool isDarkMode}) {
    if (_isPolzetAiChat()) {
      return SizedBox(
        width: 95.w,
        height: 95.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 6,
                    bottom: 0,
                    left: 8,
                    right: 7,
                  ),
                  child: Image.asset(
                    Assets.images.icSplash.path,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                Assets.images.aiFrame.path,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      );
    }

    final avatar = _resolvedProfileUrl;
    final bool hasCustomImage =
        avatar != null &&
        avatar.trim().isNotEmpty &&
        avatar != 'null' &&
        avatar != Assets.images.icAvatar.path;

    final ImageProvider? avatarProvider = !hasCustomImage
        ? AssetImage(Assets.images.icAvatar.path)
        : (getProfileImage(avatar) != null
              ? MemoryImage(getProfileImage(avatar)!)
              : (resolveProfileImageUrl(avatar) != null &&
                        resolveProfileImageUrl(avatar)!.startsWith('http')
                    ? NetworkImage(resolveProfileImageUrl(avatar)!)
                    : (resolveProfileImageUrl(avatar) != null &&
                              resolveProfileImageUrl(
                                avatar,
                              )!.startsWith('assets/')
                          ? AssetImage(resolveProfileImageUrl(avatar)!)
                          : (avatar.startsWith('http')
                                ? NetworkImage(avatar)
                                : (avatar.startsWith('assets/')
                                      ? AssetImage(avatar)
                                      : NetworkImage(
                                          '${ApiConfig.baseUrlImage}/${avatar.startsWith('/') ? avatar.substring(1) : avatar}',
                                        ))))));

    return GestureDetector(
      onTap: hasCustomImage ? _openProfileImagePreview : null,
      child: Container(
        width: 95.w,
        height: 95.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: avatarProvider != null
              ? DecorationImage(image: avatarProvider, fit: BoxFit.cover)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required AppTextColors txt,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(icon, color: txt.title, width: 22.w, height: 22.w),
        SizedBox(height: 6.h),
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13,
            color: txt.muted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _buildOptionTile({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required AppTextColors txt,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
              ),
              child: Center(child: iconWidget),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: txt.title,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12.2,
                      color: txt.muted,
                      fontWeight: FontWeight.w400,
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

  Widget _buildDestructiveAction({
    required String icon,
    required String title,

    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: Row(
          children: [
            Image.asset(
              icon,
              height: 23,
              width: 25,
              color: const Color(0XFFE5484D),
            ),
            SizedBox(width: 20.w),
            Text(
              title,
              style: AppTextStyles.cardTitle.copyWith(
                color: const Color(0XFFE5484D),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Media Tab (3x3 Grid Placeholders) ───────────────────────────────────────
  Widget _buildMediaTab({required bool isDarkMode}) {
    return GridView.builder(
      padding: const EdgeInsets.all(5),
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5.w,
        mainAxisSpacing: 5.h,
        childAspectRatio: 1.0,
      ),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.06)
                : const Color.fromARGB(255, 246, 246, 246),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      },
    );
  }

  // ── Link Tab Placeholder ───────────────────────────────────────────────────
  Widget _buildLinkTab({required AppTextColors txt, required bool isDarkMode}) {
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      physics: const BouncingScrollPhysics(),
      itemCount: 1,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF161821)
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.link,
                  size: 18.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'https://polzet.com/group/link_$index',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Shared by member',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: txt.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Documents Tab Placeholder ──────────────────────────────────────────────
  Widget _buildDocumentsTab({
    required AppTextColors txt,
    required bool isDarkMode,
  }) {
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      physics: const BouncingScrollPhysics(),
      itemCount: 1,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF161821)
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 18.sp,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document_${index + 1}.pdf',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1.2 MB • PDF',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: txt.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sliver Persistent Header Delegate for Sticky TabBar ───────────────────────
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor});

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
