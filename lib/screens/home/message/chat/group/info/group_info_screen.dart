// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_colors.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:provider/provider.dart';

import '../../../../../../api/api_config.dart';
import '../../../../../../api/api_service.dart';
import '../../../../../../api/services/share/share_service.dart';
import '../../../../../../gen/assets.gen.dart';
import '../../../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../../../mixin/utility_mixins.dart';
import '../../../../../../provider/group_chat_provider.dart';
import '../../../../../../provider/user_provider.dart';
import '../../../../../../widgets/appbar/common_appbar.dart';
import '../../../../../../widgets/base64/image_convert.dart';
import '../../../../../../widgets/dialog/custom_diolog.dart';
import '../../../../../../widgets/loader.dart';
import '../../../../../../widgets/show_toast.dart';
import '../../../../../../widgets/tabbar/indicatore_animation.dart';
import '../../../../../../widgets/bottomsheets/report/report_submitted_bottom_sheet.dart';
import '../../../../home_imports.dart';
import '../../../message_list.dart';
import 'group_add_members.dart';
import 'group_chat_theme.dart';
import 'group_details.dart';
import 'group_info_link.dart';
import 'group_info_members.dart';
import 'group_mute_notification.dart';
import 'group_privacy_safety.dart';
import 'group_report.dart';

class GroupInfoScreen extends StatefulWidget {
  final dynamic chatId;
  final String? groupName;
  final String? groupImage;
  final int memberCount;
  final GroupChatProvider? groupChatProvider;

  const GroupInfoScreen({
    super.key,
    this.chatId,
    this.groupName = 'Group Name',
    this.groupImage,
    this.memberCount = 0,
    this.groupChatProvider,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen>
    with SingleTickerProviderStateMixin, UtilityMixin {
  final _apiService = ApiService();
  late final TabController _tabController;

  Map<String, dynamic>? _groupData;
  String? _localGroupImageUrl;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchGroupInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroupInfo({bool showLoading = true}) async {
    if (widget.chatId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (showLoading && _groupData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _apiService.getGroupChatInfo(chatId: widget.chatId);
      if (mounted) {
        setState(() {
          _groupData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching group chat info: $e');
      if (mounted) {
        setState(() {
          if (_groupData == null) {
            _errorMessage = 'Failed to load group information';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showClearChatConfirmationDialog() async {
    showClearChatDiolog(context, () {
      Navigator.pop(context);
      _clearChatMessages();
    });
  }

  Future<void> _clearChatMessages() async {
    final chatId = widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) {
      showToast(message: 'Cannot clear a new chat');
      return;
    }

    // Instantly remove messages locally from group chat provider & message list
    GroupChatProvider? provider = widget.groupChatProvider;
    if (provider == null) {
      try {
        provider = Provider.of<GroupChatProvider>(context, listen: false);
      } catch (_) {}
    }
    provider?.clearLocalMessages();
    MessageListState.clearChatLocally(chatId);

    try {
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

  Future<void> _deleteGroup() async {
    final chatId = widget.chatId;
    if (chatId == null) return;
    try {
      final result = await _apiService.deleteGroup(chatId: chatId);
      if (mounted) {
        Navigator.pop(context);
        if (result['message'] == 'Group deleted successfully') {
          MessageListState.removeChatLocally(chatId);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const HomeScreen(initialIndex: 1), // ← Messages tab
            ),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete group'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
      }
    }
  }

  Future<void> _leaveGroup() async {
    final chatId = widget.chatId;
    if (chatId == null) return;
    try {
      final result = await _apiService.leaveGroup(chatId: chatId);
      if (mounted) {
        Navigator.pop(context);
        if (result['message'] == 'You have left the group.') {
          MessageListState.removeChatLocally(chatId);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const HomeScreen(initialIndex: 1), // ← Messages tab
            ),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to leave group'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to leave group: $e')));
      }
    }
  }

  bool get _isCurrentUserAdmin {
    if (_groupData == null) return false;
    if (_groupData?['is_admin'] == true) return true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();

      // Check created_by / creator_id / admin_id
      final createdBy = _groupData?['created_by']?.toString();
      final creatorId = _groupData?['creator_id']?.toString();
      final adminId = _groupData?['admin_id']?.toString();

      if (currentUserId != null && currentUserId.isNotEmpty) {
        if (createdBy == currentUserId ||
            creatorId == currentUserId ||
            adminId == currentUserId) {
          return true;
        }
      }

      // Check admins list
      final admins = _groupData?['admins'] as List<dynamic>? ?? [];
      for (final admin in admins) {
        if (admin is Map) {
          final uuid =
              (admin['uuid'] ??
                      admin['id'] ??
                      admin['user']?['id'] ??
                      admin['user']?['uuid'])
                  ?.toString();
          final username = (admin['username'] ?? admin['user']?['username'])
              ?.toString()
              .toLowerCase();
          if (currentUserId != null &&
              currentUserId.isNotEmpty &&
              uuid != null &&
              uuid == currentUserId) {
            return true;
          }
          if (currentUsername != null &&
              currentUsername.isNotEmpty &&
              username != null &&
              username == currentUsername) {
            return true;
          }
        } else if (admin != null) {
          final adminStr = admin.toString().toLowerCase();
          if (currentUserId != null &&
              adminStr == currentUserId.toLowerCase()) {
            return true;
          }
          if (currentUsername != null && adminStr == currentUsername) {
            return true;
          }
        }
      }

      // Check members list
      final members = _groupData?['members'] as List<dynamic>? ?? [];
      for (final member in members) {
        if (member is Map) {
          final bool isAdmin =
              (member['is_admin'] == true) || (member['role'] == 'admin');
          if (isAdmin) {
            final userMap = (member['user'] is Map)
                ? member['user'] as Map
                : member;
            final uuid =
                (member['uuid'] ??
                        member['id'] ??
                        userMap['uuid'] ??
                        userMap['id'])
                    ?.toString();
            final username = (userMap['username'] ?? member['username'])
                ?.toString()
                .toLowerCase();

            if (currentUserId != null &&
                currentUserId.isNotEmpty &&
                uuid != null &&
                uuid == currentUserId) {
              return true;
            }
            if (currentUsername != null &&
                currentUsername.isNotEmpty &&
                username != null &&
                username == currentUsername) {
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking isCurrentUserAdmin: $e');
    }

    return false;
  }

  String get _title =>
      _groupData?['title']?.toString() ?? widget.groupName ?? 'Group Name';

  String? get _avatarUrl {
    if (_localGroupImageUrl != null && _localGroupImageUrl!.trim().isNotEmpty) {
      final str = _localGroupImageUrl!.trim();
      if (!str.startsWith('http') && !str.startsWith('data:image')) {
        if (str.startsWith('/')) {
          return '${ApiConfig.baseUrlImage}$str';
        } else {
          return '${ApiConfig.baseUrlImage}/$str';
        }
      }
      return str;
    }
    final provider = widget.groupChatProvider;
    if (provider?.groupImageUrl != null &&
        provider!.groupImageUrl!.trim().isNotEmpty) {
      final str = provider.groupImageUrl!.trim();
      if (!str.startsWith('http') && !str.startsWith('data:image')) {
        if (str.startsWith('/')) {
          return '${ApiConfig.baseUrlImage}$str';
        } else {
          return '${ApiConfig.baseUrlImage}/$str';
        }
      }
      return str;
    }
    dynamic url;
    if (_groupData != null) {
      url =
          _groupData?['group_picture_url'] ??
          _groupData?['profile_url'] ??
          _groupData?['picture_url'] ??
          _groupData?['profile_picture_url'] ??
          _groupData?['avatar_url'] ??
          _groupData?['cover_picture_url'];
    } else {
      url = widget.groupImage;
    }
    if (url == null) return null;
    final str = url.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    if (!str.startsWith('http') && !str.startsWith('data:image')) {
      if (str.startsWith('/')) {
        return '${ApiConfig.baseUrlImage}$str';
      } else {
        return '${ApiConfig.baseUrlImage}/$str';
      }
    }
    return str;
  }

  List<dynamic> get _members => _groupData?['members'] as List<dynamic>? ?? [];

  String get _membersSubtitle {
    if (_members.isNotEmpty) {
      final names = _members
          .map((m) {
            if (m is Map) {
              return m['username']?.toString() ??
                  m['user']?['username']?.toString() ??
                  m['name']?.toString() ??
                  '';
            }
            return '';
          })
          .where((n) => n.isNotEmpty)
          .toList();

      if (names.length == 1) {
        return names.first;
      } else if (names.length == 2) {
        return '${names[0]}, ${names[1]}';
      } else if (names.length > 2) {
        return '${names[0]}, ${names[1]} and ${_members.length - 2} others';
      }
    }
    if (widget.memberCount > 0) {
      return '${widget.memberCount} members';
    }
    return 'No members yet';
  }

  String get _inviteLinkSubtitle {
    final slug = _groupData?['slug']?.toString() ?? '';
    if (slug.isNotEmpty) {
      return 'http://www.polzet.com/g/$slug';
    }
    return 'Url link.............';
  }

  String get _privacySubtitle {
    final privacy =
        _groupData?['privacy']?.toString().toLowerCase() ?? 'public';
    if (privacy == 'private') {
      return AppLocalizations.of(
        context,
      )!.onlymemberscanseeandparticipateinthisgroup;
    } else if (privacy == 'invite_only') {
      return AppLocalizations.of(context)!.onlypeopleyouinvitecanjoingroup;
    }
    return AppLocalizations.of(context)!.anyonecandiscoverandviewthisgroup;
  }

  Map<String, dynamic> _buildReturnData() {
    return {'groupImageUrl': _avatarUrl, 'groupName': _title};
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(title: AppLocalizations.of(context)!.groupinfo),
        body: Center(
          child: Loader(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_errorMessage != null && _groupData == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(title: AppLocalizations.of(context)!.groupinfo),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyText.copyWith(
                  color: txt.muted,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: _fetchGroupInfo,
                child: Text(
                  AppLocalizations.of(context)!.retry,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.primaryColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _buildReturnData());
        return false;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: CommonAppBar(
          title: AppLocalizations.of(context)!.groupinfo,
          onBack: () => Navigator.pop(context, _buildReturnData()),
        ),
        body: RefreshIndicator(
          onRefresh: _fetchGroupInfo,
          color: Theme.of(context).colorScheme.primary,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        SizedBox(height: 10.h),
                        // ── Group Avatar ──────────────────────────────────
                        Center(
                          child: GestureDetector(
                            onTap: _isCurrentUserAdmin
                                ? _navigateToGroupDetails
                                : null,
                            child: _buildGroupAvatar(isDarkMode: isDarkMode),
                          ),
                        ),
                        SizedBox(height: 14.h),

                        // ── Group Name ────────────────────────────────────
                        GestureDetector(
                          onTap: _isCurrentUserAdmin
                              ? _navigateToGroupDetails
                              : null,
                          child: Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ),
                        SizedBox(height: 22.h),

                        // ── Actions Row (Add, Search, Mute, More) ─────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (_isCurrentUserAdmin)
                              _buildActionButton(
                                icon: Assets.images.icAddUser.path,
                                label: AppLocalizations.of(context)!.add,
                                txt: txt,
                                onTap: () async {
                                  final alreadyInGroup = <String>{};
                                  final members =
                                      _groupData?['members']
                                          as List<dynamic>? ??
                                      [];
                                  for (final m in members) {
                                    if (m is Map) {
                                      final userMap = (m['user'] is Map)
                                          ? m['user'] as Map
                                          : m;
                                      final uuid =
                                          (m['uuid'] ??
                                                  m['id'] ??
                                                  userMap['uuid'] ??
                                                  userMap['id'])
                                              ?.toString();
                                      final username =
                                          (userMap['username'] ?? m['username'])
                                              ?.toString();
                                      if (uuid != null && uuid.isNotEmpty) {
                                        alreadyInGroup.add(uuid);
                                      }
                                      if (username != null &&
                                          username.isNotEmpty) {
                                        alreadyInGroup.add(
                                          username.toLowerCase(),
                                        );
                                      }
                                    }
                                  }
                                  final result = await navigationPush(
                                    context,
                                    GroupAddMembers(
                                      groupId: widget.chatId?.toString(),
                                      alreadySelected: alreadyInGroup,
                                    ),
                                  );
                                  if (result == true && mounted) {
                                    _fetchGroupInfo();
                                  }
                                },
                              ),
                            _buildActionButton(
                              icon: Assets.images.icSearch.path,
                              label: AppLocalizations.of(context)!.search,
                              txt: txt,
                              onTap: () {},
                            ),
                            _buildActionButton(
                              icon: Assets.images.icMute.path,
                              label: AppLocalizations.of(context)!.mute,
                              txt: txt,
                              onTap: () async {
                                final result = await navigationPush(
                                  context,
                                  GroupMuteNotification(
                                    chatId: widget.chatId,
                                    isMute:
                                        _groupData?['is_muted'] ??
                                        _groupData?['is_mute'] ??
                                        false,
                                    groupData: _groupData,
                                  ),
                                );
                                if (result != null && mounted) {
                                  _fetchGroupInfo();
                                }
                              },
                            ),
                            Theme(
                              data: Theme.of(context).copyWith(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                focusColor: Colors.transparent,
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
                                onSelected: (value) async {
                                  if (value == 'share') {
                                    final slug =
                                        _groupData?['slug']?.toString() ?? '';
                                    ShareService.shareGroup(
                                      slug: slug,
                                      context: context,
                                      groupName: _title,
                                      groupId: widget.chatId?.toString() ?? '',
                                    );
                                  } else if (value == 'report') {
                                    final bool isReported =
                                        _groupData?['is_reported'] == true;
                                    if (isReported) {
                                      showReportSubmittedBottomSheet(context);
                                    } else {
                                      final result = await navigationPush(
                                        context,
                                        ReportGroup(
                                          groupId: widget.chatId?.toString(),
                                        ),
                                      );
                                      if (result == true && mounted) {
                                        setState(() {
                                          if (_groupData != null) {
                                            _groupData!['is_reported'] = true;
                                          }
                                        });
                                      }
                                    }
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
                                        AppLocalizations.of(context)!.share,
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
                                        AppLocalizations.of(context)!.report,
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
                                  label: AppLocalizations.of(context)!.more,
                                  txt: txt,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),

                        // ── Options List Tiles ────────────────────────────
                        _buildOptionTile(
                          iconWidget: Image.asset(
                            Assets.images.icGroup.path,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.7),
                            width: 20.w,
                            height: 20.w,
                          ),
                          title: AppLocalizations.of(context)!.members,
                          subtitle: _membersSubtitle,
                          isDarkMode: isDarkMode,
                          txt: txt,
                          onTap: () async {
                            await navigationPush(
                              context,
                              GroupInfoMembers(
                                chatId: widget.chatId,
                                groupData: _groupData,
                              ),
                            );
                            if (mounted) {
                              _fetchGroupInfo(showLoading: false);
                            }
                          },
                        ),
                        _buildOptionTile(
                          iconWidget: Icon(
                            FeatherIcons.link,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.7),
                            size: 22,
                          ),
                          title: AppLocalizations.of(context)!.invitelink,
                          subtitle: _inviteLinkSubtitle,
                          isDarkMode: isDarkMode,
                          txt: txt,
                          onTap: () {
                            navigationPush(
                              context,
                              GroupInfoLink(
                                slug: _groupData?['slug']?.toString(),
                                groupName: _title,
                                groupId: widget.chatId?.toString(),
                              ),
                            );
                          },
                        ),
                        _buildOptionTile(
                          iconWidget: Image.asset(
                            Assets.images.icSecurity.path,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.7),
                            width: 17.w,
                            height: 17.w,
                          ),
                          title: AppLocalizations.of(context)!.privacysafety,
                          subtitle: _privacySubtitle,
                          isDarkMode: isDarkMode,
                          txt: txt,
                          onTap: () async {
                            final result = await navigationPush(
                              context,
                              GroupPrivacySafety(
                                chatId: widget.chatId,
                                groupData: _groupData,
                                isAdmin: _isCurrentUserAdmin,
                              ),
                            );
                            if (result != null && mounted) {
                              _fetchGroupInfo();
                            }
                          },
                        ),
                        Builder(
                          builder: (context) {
                            GroupChatProvider? provider =
                                widget.groupChatProvider;
                            if (provider == null) {
                              try {
                                provider = Provider.of<GroupChatProvider>(
                                  context,
                                  listen: false,
                                );
                              } catch (_) {}
                            }
                            final currentTheme =
                                provider?.currentTheme ??
                                ChatThemeItem.fromIdOrName(
                                  provider?.chat?['chat_theme'],
                                );
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
                              title: AppLocalizations.of(
                                context,
                              )!.customizetheme,
                              subtitle: AppLocalizations.of(
                                context,
                              )!.yourcanchangecolorandthemeofchat,
                              isDarkMode: isDarkMode,
                              txt: txt,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => provider != null
                                        ? ChangeNotifierProvider.value(
                                            value: provider,
                                            child: GroupChatTheme(
                                              chatId:
                                                  widget.chatId ??
                                                  provider.chatId ??
                                                  provider.chat?['id'] ??
                                                  _groupData?['id'],
                                              groupChatProvider: provider,
                                              chatTheme:
                                                  provider
                                                      .chat?['chat_theme'] ??
                                                  _groupData?['chat_theme'],
                                              chat: provider.chat ?? _groupData,
                                              title:
                                                  _groupData?['title']
                                                      ?.toString() ??
                                                  widget.groupName ??
                                                  provider.groupName,
                                              description:
                                                  _groupData?['description']
                                                      ?.toString(),
                                              category:
                                                  _groupData?['category']
                                                      ?.toString() ??
                                                  _groupData?['group_category']
                                                      ?.toString(),
                                              privacy:
                                                  _groupData?['privacy']
                                                      ?.toString() ??
                                                  _groupData?['group_privacy']
                                                      ?.toString(),
                                            ),
                                          )
                                        : GroupChatTheme(
                                            chatId:
                                                widget.chatId ??
                                                _groupData?['id'],
                                            chatTheme:
                                                provider?.chat?['chat_theme'] ??
                                                _groupData?['chat_theme'],
                                            chat: provider?.chat ?? _groupData,
                                            title:
                                                _groupData?['title']
                                                    ?.toString() ??
                                                widget.groupName,
                                            description:
                                                _groupData?['description']
                                                    ?.toString(),
                                            category:
                                                _groupData?['category']
                                                    ?.toString() ??
                                                _groupData?['group_category']
                                                    ?.toString(),
                                            privacy:
                                                _groupData?['privacy']
                                                    ?.toString() ??
                                                _groupData?['group_privacy']
                                                    ?.toString(),
                                          ),
                                  ),
                                );
                                if (result is ChatThemeItem) {
                                  provider?.setTheme(result);
                                  if (provider?.chat != null) {
                                    provider!.chat!['chat_theme'] = result.id;
                                  }
                                }
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                        _buildDestructiveAction(
                          icon: Assets.images.icClearChat.path,

                          title: AppLocalizations.of(context)!.clearchat,
                          onTap: _showClearChatConfirmationDialog,
                        ),
                        if (_isCurrentUserAdmin)
                          _buildDestructiveAction(
                            icon: Assets.images.icDelete.path,
                            title: AppLocalizations.of(context)!.deletegroup,
                            onTap: () {
                              showDeleteGroupDiolog(context, () {
                                _deleteGroup();
                              });
                            },
                          ),
                        if (!_isCurrentUserAdmin)
                          _buildLeaveGroupAction(
                            icon: Assets.images.icLeave.path,
                            title: AppLocalizations.of(context)!.leavegroup,
                            onTap: () {
                              showLeaveGroupDiolog(context, () {
                                _leaveGroup();
                              });
                            },
                          ),
                        SizedBox(height: 12.h),
                      ],
                    ),
                  ),
                ),

                // ── Sticky TabBar ─────────────────────────────────────────
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
                      tabs: [
                        Tab(text: AppLocalizations.of(context)!.media),
                        Tab(text: AppLocalizations.of(context)!.link),
                        Tab(text: AppLocalizations.of(context)!.document),
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
      ),
    );
  }

  Future<void> _navigateToGroupDetails() async {
    if (!_isCurrentUserAdmin) return;
    GroupChatProvider? provider = widget.groupChatProvider;
    if (provider == null) {
      try {
        provider = Provider.of<GroupChatProvider>(context, listen: false);
      } catch (_) {}
    }

    final result = await navigationPush(
      context,
      GroupDetails(
        chatId: widget.chatId,
        groupName: _title,
        groupDescription: _groupData?['description']?.toString(),
        groupCategory:
            _groupData?['category']?.toString() ??
            _groupData?['group_category']?.toString(),
        groupPrivacy: _groupData?['privacy']?.toString(),
        groupImageUrl: _avatarUrl,
        members: _members,
        groupChatProvider: provider,
        onGroupImageUpdated: (newImageUrl) {
          if (mounted) {
            setState(() {
              _localGroupImageUrl = newImageUrl;
              if (_groupData != null) {
                _groupData!['group_picture_url'] = newImageUrl;
                _groupData!['profile_url'] = newImageUrl;
                _groupData!['picture_url'] = newImageUrl;
              } else {
                _groupData = {
                  'group_picture_url': newImageUrl,
                  'profile_url': newImageUrl,
                };
              }
            });
            provider?.updateGroupPicture(newImageUrl);
            try {
              Provider.of<GroupChatProvider>(
                context,
                listen: false,
              ).updateGroupPicture(newImageUrl);
            } catch (_) {}
            if (widget.chatId != null) {
              MessageListState.updateGroupChatAvatarLocally(
                widget.chatId,
                newImageUrl,
              );
            }
          }
        },
        onGroupDetailsUpdated: (data) {
          if (mounted) {
            final newImageUrl = data['groupImageUrl']?.toString();
            final newName = data['groupName']?.toString();
            final newDesc = data['groupDescription']?.toString();
            final newCat = data['groupCategory']?.toString();
            final newPrivacy = (data['groupPrivacy'] ?? data['privacy'])
                ?.toString();
            setState(() {
              if (newImageUrl != null && newImageUrl.isNotEmpty) {
                _localGroupImageUrl = newImageUrl;
              }
              if (_groupData != null) {
                if (newImageUrl != null && newImageUrl.isNotEmpty) {
                  _groupData!['group_picture_url'] = newImageUrl;
                  _groupData!['profile_url'] = newImageUrl;
                  _groupData!['picture_url'] = newImageUrl;
                }
                if (newName != null && newName.isNotEmpty) {
                  _groupData!['title'] = newName;
                }
                if (newDesc != null) {
                  _groupData!['description'] = newDesc;
                }
                if (newCat != null) {
                  _groupData!['category'] = newCat;
                  _groupData!['group_category'] = newCat;
                }
                if (newPrivacy != null && newPrivacy.isNotEmpty) {
                  _groupData!['privacy'] = newPrivacy;
                }
              }
            });
            if (newImageUrl != null && newImageUrl.isNotEmpty) {
              provider?.updateGroupPicture(newImageUrl);
              try {
                Provider.of<GroupChatProvider>(
                  context,
                  listen: false,
                ).updateGroupPicture(newImageUrl);
              } catch (_) {}
              if (widget.chatId != null) {
                MessageListState.updateGroupChatAvatarLocally(
                  widget.chatId,
                  newImageUrl,
                );
              }
            }
            if (newName != null && newName.isNotEmpty) {
              provider?.updateGroupNameLocally(newName);
              try {
                Provider.of<GroupChatProvider>(
                  context,
                  listen: false,
                ).updateGroupNameLocally(newName);
              } catch (_) {}
              if (widget.chatId != null) {
                MessageListState.updateGroupChatTitleLocally(
                  widget.chatId,
                  newName,
                );
              }
            }
          }
        },
      ),
    );

    if (result is Map && mounted) {
      final newImageUrl = result['groupImageUrl']?.toString();
      final newName = result['groupName']?.toString();
      final newDesc = result['groupDescription']?.toString();
      final newCat = result['groupCategory']?.toString();
      final newPrivacy = (result['groupPrivacy'] ?? result['privacy'])
          ?.toString();

      setState(() {
        if (newImageUrl != null && newImageUrl.isNotEmpty) {
          _localGroupImageUrl = newImageUrl;
        }
        if (_groupData != null) {
          if (newImageUrl != null && newImageUrl.isNotEmpty) {
            _groupData!['group_picture_url'] = newImageUrl;
            _groupData!['profile_url'] = newImageUrl;
            _groupData!['picture_url'] = newImageUrl;
          }
          if (newName != null && newName.isNotEmpty) {
            _groupData!['title'] = newName;
          }
          if (newDesc != null) {
            _groupData!['description'] = newDesc;
          }
          if (newCat != null) {
            _groupData!['category'] = newCat;
            _groupData!['group_category'] = newCat;
          }
          if (newPrivacy != null && newPrivacy.isNotEmpty) {
            _groupData!['privacy'] = newPrivacy;
          }
        }
      });
      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        provider?.updateGroupPicture(newImageUrl);
        try {
          Provider.of<GroupChatProvider>(
            context,
            listen: false,
          ).updateGroupPicture(newImageUrl);
        } catch (_) {}
        if (widget.chatId != null) {
          MessageListState.updateGroupChatAvatarLocally(
            widget.chatId,
            newImageUrl,
          );
        }
      }
      if (newName != null && newName.isNotEmpty) {
        provider?.updateGroupNameLocally(newName);
        try {
          Provider.of<GroupChatProvider>(
            context,
            listen: false,
          ).updateGroupNameLocally(newName);
        } catch (_) {}
        if (widget.chatId != null) {
          MessageListState.updateGroupChatTitleLocally(widget.chatId, newName);
        }
      }
      _fetchGroupInfo(showLoading: false);
    } else if (mounted) {
      _fetchGroupInfo(showLoading: false);
    }
  }

  Widget _buildGroupAvatar({required bool isDarkMode}) {
    final avatar = _avatarUrl;
    if (avatar != null && avatar.trim().isNotEmpty && avatar != 'null') {
      final imageBytes = getProfileImage(avatar);
      final resolvedUrl = resolveProfileImageUrl(avatar);
      final hasNetworkImage =
          imageBytes == null &&
          resolvedUrl != null &&
          resolvedUrl.startsWith('http');

      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: imageBytes != null
              ? DecorationImage(
                  image: MemoryImage(imageBytes),
                  fit: BoxFit.cover,
                )
              : (hasNetworkImage
                    ? DecorationImage(
                        image: NetworkImage(resolvedUrl),
                        fit: BoxFit.cover,
                      )
                    : null),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    }

    return _buildGroupAvatarStack(
      members: _members,
      size: 100,
      isDarkMode: isDarkMode,
      context: context,
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
        final user = member is Map
            ? (member['user'] is Map ? member['user'] as Map : member)
            : null;
        if (user != null) {
          String? profileUrl =
              (user['avatar_url'] ??
                      user['profile_image'] ??
                      user['profile_picture_url'] ??
                      user['avatar'])
                  ?.toString();
          final username = user['username']?.toString();
          if (profileUrl != null &&
              profileUrl.trim().isNotEmpty &&
              profileUrl != 'null') {
            if (!profileUrl.startsWith('http') &&
                !profileUrl.startsWith('data:image')) {
              final separator = profileUrl.startsWith('/') ? '' : '/';
              profileUrl = '${ApiConfig.baseUrlImage}$separator$profileUrl';
            }
          } else {
            profileUrl = Assets.images.icAvatar.path;
          }
          final name = (user['name'] ?? username ?? 'Unknown').toString();
          profileUrls.add(profileUrl);
          initials.add(name.isNotEmpty ? name[0].toUpperCase() : '?');
        }
      }
    }

    while (profileUrls.length < 2) {
      profileUrls.add(Assets.images.icAvatar.path);
      initials.add('?');
    }

    final double circleSize = size * 0.70;

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
              bottom: 2,
              right: 3,
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
    final ImageProvider? avatarProvider =
        (profileUrl == null ||
            profileUrl.trim().isEmpty ||
            profileUrl == 'null' ||
            profileUrl == Assets.images.icAvatar.path)
        ? AssetImage(Assets.images.icAvatar.path)
        : (getProfileImage(profileUrl) != null
              ? MemoryImage(getProfileImage(profileUrl)!)
              : (resolveProfileImageUrl(profileUrl) != null &&
                        resolveProfileImageUrl(profileUrl)!.startsWith('http')
                    ? NetworkImage(resolveProfileImageUrl(profileUrl)!)
                    : (resolveProfileImageUrl(profileUrl) != null &&
                              resolveProfileImageUrl(
                                profileUrl,
                              )!.startsWith('assets/')
                          ? AssetImage(resolveProfileImageUrl(profileUrl)!)
                          : AssetImage(Assets.images.icAvatar.path))));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.background,
                width: 2,
              )
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.05),
                width: 1,
              ),
        image: avatarProvider != null
            ? DecorationImage(image: avatarProvider, fit: BoxFit.cover)
            : null,
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required AppTextColors txt,
    VoidCallback? onTap,
  }) {
    final txt = AppTextColors.of(context);
    final content = Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icon, color: txt.title, width: 22, height: 22),
          SizedBox(height: 5.h),
          Text(
            label,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13,
              color: txt.muted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }

  Widget _buildOptionTile({
    required Widget iconWidget,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required AppTextColors txt,
    required VoidCallback onTap,
  }) {
    final txt = AppTextColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Container(
              height: 47,
              width: 47,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(child: iconWidget),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: txt.title,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: txt.muted,
                      fontSize: 12.5,
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
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              icon,
              height: 23,
              width: 25,
              color: const Color(0XFFE5484D),
            ),
          ),
          const SizedBox(width: 18.5),
          Text(
            title,
            style: AppTextStyles.cardTitle.copyWith(
              color: const Color(0XFFE5484D),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveGroupAction({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            margin: EdgeInsets.only(left: 2.w),
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              icon,
              height: 21.5,
              width: 21.5,
              color: const Color(0XFFE5484D),
            ),
          ),
          SizedBox(width: 15.w),
          Text(
            title,
            style: AppTextStyles.cardTitle.copyWith(
              color: const Color(0XFFE5484D),
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
