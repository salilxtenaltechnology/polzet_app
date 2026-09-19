// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/api_service.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import 'package:polzet_app/core/themes/app_text_colors.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/gen/assets.gen.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:polzet_app/mixin/utility_mixins.dart';
import 'package:polzet_app/provider/user_provider.dart';
import 'package:polzet_app/screens/home/profile/public/public_profile_screen.dart';
import 'package:polzet_app/widgets/appbar/common_appbar.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';
import 'package:polzet_app/widgets/button/primary_button.dart';
import 'package:polzet_app/widgets/bottomsheets/report/report_submitted_bottom_sheet.dart';
import 'package:polzet_app/widgets/custom_text_styles.dart';
import 'package:polzet_app/widgets/dialog/custom_diolog.dart';
import 'package:polzet_app/widgets/loader.dart';
import 'package:polzet_app/widgets/show_toast.dart';
import 'package:provider/provider.dart';

import '../../private/info/private_user_report.dart';
import 'group_add_members.dart';
import '../join/group_join_request_list.dart';

class GroupInfoMembers extends StatefulWidget {
  final dynamic chatId;
  final Map<String, dynamic>? groupData;

  const GroupInfoMembers({super.key, this.chatId, this.groupData});

  @override
  State<GroupInfoMembers> createState() => _GroupInfoMembersState();
}

class _GroupInfoMembersState extends State<GroupInfoMembers> with UtilityMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _groupData;
  bool _isLoading = false;
  bool _isLoadingRequests = false;
  List<Map<String, dynamic>> _joinRequests = [];

  @override
  void initState() {
    super.initState();
    _groupData = widget.groupData;
    if (_groupData == null) {
      _isLoading = true;
    }
    _fetchGroupInfo();
    _fetchJoinRequests();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {});
  }

  List<Map<String, dynamic>> _sortJoinRequests(
    List<Map<String, dynamic>> list,
  ) {
    final sorted = List<Map<String, dynamic>>.from(list);
    sorted.sort((a, b) {
      final aDateStr = (a['requested_at'] ?? a['created_at'] ?? a['timestamp'])
          ?.toString();
      final bDateStr = (b['requested_at'] ?? b['created_at'] ?? b['timestamp'])
          ?.toString();
      final aDate = aDateStr != null ? DateTime.tryParse(aDateStr) : null;
      final bDate = bDateStr != null ? DateTime.tryParse(bDateStr) : null;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate); // Recent first
    });
    return sorted;
  }

  Future<void> _fetchJoinRequests() async {
    final chatId = widget.chatId?.toString();
    if (chatId == null || chatId.isEmpty) return;

    if (_isLoadingRequests) return;
    _isLoadingRequests = true;

    try {
      final res = await _apiService.getGroupJoinRequestsList(chatId: chatId);
      List<Map<String, dynamic>> list = [];
      if (res['data'] is List) {
        list = List<Map<String, dynamic>>.from(res['data']);
      } else if (res['results'] is List) {
        list = List<Map<String, dynamic>>.from(res['results']);
      } else if (res['join_requests'] is List) {
        list = List<Map<String, dynamic>>.from(res['join_requests']);
      }

      if (mounted) {
        setState(() {
          _joinRequests = _sortJoinRequests(list);
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching join requests in GroupInfoMembers: $e');
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _fetchGroupInfo() async {
    if (widget.chatId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
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
      debugPrint('Error fetching group members info: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _rawMembers =>
      _groupData?['members'] as List<dynamic>? ?? [];

  List<dynamic> get _rawAdmins => _groupData?['admins'] as List<dynamic>? ?? [];

  Set<String> get _adminIdentifiers {
    final Set<String> set = {};
    for (final admin in _rawAdmins) {
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
        if (uuid != null && uuid.isNotEmpty) set.add(uuid);
        if (username != null && username.isNotEmpty) set.add(username);
      } else if (admin != null) {
        set.add(admin.toString().toLowerCase());
      }
    }
    return set;
  }

  bool get _isCurrentUserAdmin {
    if (_groupData?['is_admin'] == true) return true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();

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

      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          _adminIdentifiers.contains(currentUserId)) {
        return true;
      }
      if (currentUsername != null &&
          currentUsername.isNotEmpty &&
          _adminIdentifiers.contains(currentUsername)) {
        return true;
      }

      for (final m in _rawMembers) {
        if (m is Map) {
          final parsed = _parseMember(m);
          if (parsed['is_admin'] == true && _isCurrentUser(parsed)) {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  Map<String, dynamic> _parseMember(dynamic member) {
    if (member is! Map) return {};
    final userMap = (member['user'] is Map) ? member['user'] as Map : member;
    final uuid =
        (member['uuid'] ?? member['id'] ?? userMap['uuid'] ?? userMap['id'])
            ?.toString() ??
        '';
    final username =
        (userMap['username'] ??
                member['username'] ??
                userMap['name'] ??
                member['name'] ??
                'User Name')
            .toString();
    final fullName =
        (userMap['name'] ??
                member['name'] ??
                userMap['full_name'] ??
                member['full_name'] ??
                username)
            .toString();
    final profilePic =
        (userMap['profile_picture_url'] ??
                member['profile_picture_url'] ??
                userMap['avatar_url'] ??
                member['avatar_url'] ??
                userMap['profile_image'] ??
                member['profile_image'] ??
                userMap['avatar'] ??
                member['avatar'])
            ?.toString();
    final bool isAdminFlag =
        (member['is_admin'] == true) ||
        (member['role'] == 'admin') ||
        (uuid.isNotEmpty && _adminIdentifiers.contains(uuid)) ||
        (username.isNotEmpty &&
            _adminIdentifiers.contains(username.toLowerCase()));
    final bool isReported =
        (member['is_reported'] == true) || (userMap['is_reported'] == true);

    return {
      'uuid': uuid,
      'username': username,
      'name': fullName,
      'profile_picture_url': profilePic,
      'is_admin': isAdminFlag,
      'is_reported': isReported,
      'raw': member,
    };
  }

  List<Map<String, dynamic>> get _displayMembers {
    final List<Map<String, dynamic>> list = [];
    final Set<String> seen = {};

    for (final raw in _rawMembers) {
      final parsed = _parseMember(raw);
      final key = parsed['uuid'].isNotEmpty
          ? parsed['uuid']
          : parsed['username'];
      if (key.isNotEmpty && seen.contains(key)) continue;
      if (key.isNotEmpty) seen.add(key);
      list.add(parsed);
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return list;

    return list.where((m) {
      final username = (m['username'] as String?)?.toLowerCase() ?? '';
      final name = (m['name'] as String?)?.toLowerCase() ?? '';
      final raw = m['raw'];
      final rawMap = (raw is Map) ? raw : null;
      final userMap = (rawMap != null && rawMap['user'] is Map)
          ? rawMap['user'] as Map
          : rawMap;
      final firstName =
          (userMap?['first_name'] as String?)?.toLowerCase() ?? '';
      final lastName = (userMap?['last_name'] as String?)?.toLowerCase() ?? '';
      final fullName = '$firstName $lastName'.trim();

      return username.contains(query) ||
          name.contains(query) ||
          firstName.contains(query) ||
          lastName.contains(query) ||
          fullName.contains(query);
    }).toList();
  }

  bool _isCurrentUser(Map<String, dynamic> member) {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUserId = userProvider.userId?.toString();
      final currentUsername = userProvider.username?.toString().toLowerCase();

      final uuid = (member['uuid'] ?? '').toString();
      final username = (member['username'] ?? '').toString().toLowerCase();

      if (currentUserId != null &&
          currentUserId.isNotEmpty &&
          uuid.isNotEmpty &&
          uuid == currentUserId) {
        return true;
      }

      if (currentUsername != null &&
          currentUsername.isNotEmpty &&
          username.isNotEmpty &&
          username == currentUsername) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final String username = (member['username'] ?? 'User').toString();
    final String name = (member['name'] ?? username).toString();
    final String handle = username.startsWith('@') ? username : '@$username';
    final String uuid = (member['uuid'] ?? '').toString();
    final String? profilePic = member['profile_picture_url'] as String?;
    final bool isAdmin = member['is_admin'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4.h,
                  width: 38.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Row(
                  children: [
                    _buildMemberAvatar(
                      profilePic,
                      username,
                      isDarkMode,
                      size: 37,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name.isNotEmpty ? name : username,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    color: txt.title,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isPolzetAi(username)) ...[
                                SizedBox(width: 4.w),
                                Image.asset(
                                  Assets.images.icVerify.path,
                                  height: 13,
                                  width: 13,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            handle,
                            style: AppTextStyles.bodyText.copyWith(
                              color: txt.muted,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Divider(
                height: 1,
                thickness: 0.7,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              ),
              SizedBox(height: 6.h),
              _buildOptionRow(
                title: 'View Profile',
                onTap: () {
                  Navigator.pop(ctx);
                  navigationPush(
                    context,
                    PublicProfileScreen(userId: uuid, username: username),
                  );
                },
              ),
              if (!isAdmin) ...[
                _buildOptionRow(
                  title: 'Make Admin',
                  onTap: () {
                    Navigator.pop(ctx);
                    _makeAdmin(uuid, username);
                  },
                ),
              ],
              _buildOptionRow(
                title: 'Remove from Group',
                onTap: () {
                  Navigator.pop(ctx);
                  _removeMember(uuid, username);
                },
              ),
              _buildOptionRow(
                title: 'Report User',
                textColor: const Color(0XFFE5484D),
                onTap: () async {
                  Navigator.pop(ctx);
                  final bool isReported = member['is_reported'] == true;
                  if (isReported) {
                    showReportSubmittedBottomSheet(context);
                  } else {
                    final result = await navigationPush(
                      context,
                      PrivateUserReport(userId: uuid, isReported: false),
                    );
                    if (result == true && mounted) {
                      _updateMemberReportedStatusLocally(uuid, true);
                    }
                  }
                },
              ),
              _buildOptionRow(
                title: 'Block User',
                textColor: const Color(0XFFE5484D),
                onTap: () {
                  Navigator.pop(ctx);
                  showBlockUserDiolog(context, () async {
                    Navigator.pop(context);
                    if (uuid.isEmpty) {
                      showToast(message: 'User ID not found');
                      return;
                    }
                    try {
                      final res = await _apiService.blockUser(uuid);
                      if (res['success'] == false) {
                        showToast(
                          message: res['message'] ?? 'Failed to block user',
                        );
                      } else {
                        showToast(message: 'User blocked successfully');
                        _fetchGroupInfo();
                      }
                    } catch (e) {
                      showToast(message: 'Failed to block user');
                    }
                  }, false);
                },
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final txt = AppTextColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text(
          title,
          style: AppTextStyles.bodyText.copyWith(
            color: textColor ?? txt.body,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Future<void> _makeAdmin(String userId, String username) async {
    if (widget.chatId == null || userId.isEmpty) return;
    try {
      final res = await _apiService.makeAdmin(
        chatId: widget.chatId,
        userId: userId,
      );
      if (res['success'] == false ||
          res['message']?.toString().toLowerCase().contains('fail') == true) {
        showToast(message: res['message'] ?? 'Failed to make admin');
      } else {
        showToast(message: '$username is now an admin');
        _fetchGroupInfo();
      }
    } catch (e) {
      showToast(message: 'Failed to make $username admin');
    }
  }

  Future<void> _removeMember(String userId, String username) async {
    if (widget.chatId == null || userId.isEmpty) return;
    try {
      final res = await _apiService.removeMember(
        chatId: widget.chatId,
        userId: userId,
      );
      if (res['success'] == false ||
          res['message']?.toString().toLowerCase().contains('fail') == true) {
        showToast(message: res['message'] ?? 'Failed to remove member');
      } else {
        showToast(message: '$username removed from group');
        _fetchGroupInfo();
      }
    } catch (e) {
      showToast(message: 'Failed to remove $username');
    }
  }

  void _updateMemberReportedStatusLocally(String userId, bool isReported) {
    if (userId.isEmpty || _groupData == null) return;
    setState(() {
      final membersList = _groupData?['members'];
      if (membersList is List) {
        for (var m in membersList) {
          if (m is Map) {
            final mId =
                (m['uuid'] ?? m['id'] ?? m['user']?['uuid'] ?? m['user']?['id'])
                    ?.toString();
            if (mId == userId) {
              m['is_reported'] = isReported;
              if (m['user'] is Map) {
                m['user']['is_reported'] = isReported;
              }
            }
          }
        }
      }
      final adminsList = _groupData?['admins'];
      if (adminsList is List) {
        for (var a in adminsList) {
          if (a is Map) {
            final aId =
                (a['uuid'] ?? a['id'] ?? a['user']?['uuid'] ?? a['user']?['id'])
                    ?.toString();
            if (aId == userId) {
              a['is_reported'] = isReported;
              if (a['user'] is Map) {
                a['user']['is_reported'] = isReported;
              }
            }
          }
        }
      }
    });
  }

  bool _isPolzetAi(String? username) {
    if (username == null) return false;
    final u = username.trim().toLowerCase();
    return u == 'polzet_ai' || u == 'polet_ai';
  }

  Widget _buildMemberAvatar(
    String? profileUrl,
    String username,
    bool isDarkMode, {
    double? size,
  }) {
    final double effectiveSize = (size ?? 36).w;

    if (_isPolzetAi(username) || _isPolzetAi(profileUrl)) {
      return SizedBox(
        width: effectiveSize,
        height: effectiveSize,
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

    final resolved = resolveProfileImageUrl(profileUrl);
    final bytes = profileUrl != null ? getProfileImage(profileUrl) : null;
    final ImageProvider? provider = bytes != null
        ? MemoryImage(bytes)
        : (resolved != null && resolved.startsWith('http')
              ? NetworkImage(resolved)
              : (resolved != null && resolved.startsWith('assets/')
                    ? AssetImage(resolved)
                    : null));

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode
            ? const Color(0xFF252525)
            : Theme.of(context).primaryColor.withOpacity(0.08),
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : DecorationImage(
                image: AssetImage(Assets.images.icAvatar.path),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildJoinRequestsAvatarStack({
    required BuildContext context,
    required bool isDarkMode,
  }) {
    final List<String?> profileUrls = [];
    final sortedList = _sortJoinRequests(_joinRequests);

    for (final req in sortedList) {
      if (profileUrls.length >= 2) break;
      final user = (req['user'] is Map) ? req['user'] as Map : req;
      final String? profileUrl =
          (user['profile_picture'] ??
                  user['profile_picture_url'] ??
                  user['avatar_url'] ??
                  user['profile_image'] ??
                  user['profile_url'] ??
                  user['avatar'] ??
                  user['image'] ??
                  req['profile_picture'] ??
                  req['profile_picture_url'])
              ?.toString();
      profileUrls.add(profileUrl);
    }

    if (profileUrls.isEmpty) {
      return SizedBox(
        width: 42.w,
        height: 36.w,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _buildSingleJoinAvatar(
            profileUrl: null,
            size: 34.w,
            isDarkMode: isDarkMode,
            context: context,
            hasBorder: false,
          ),
        ),
      );
    }

    // If only one user in list, show single profile avatar
    if (profileUrls.length == 1) {
      return SizedBox(
        width: 42.w,
        height: 36.w,
        child: Align(
          alignment: Alignment.centerLeft,
          child: _buildSingleJoinAvatar(
            profileUrl: profileUrls[0],
            size: 34.w,
            isDarkMode: isDarkMode,
            context: context,
            hasBorder: false,
          ),
        ),
      );
    }

    // If 2, 3, etc. users in list, show stacked overlapping avatars
    const double circleSize = 32.0;

    return SizedBox(
      width: 46.w,
      height: 36.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 2,
            child: _buildSingleJoinAvatar(
              profileUrl: profileUrls[0],
              size: circleSize.w,
              isDarkMode: isDarkMode,
              context: context,
              hasBorder: false,
            ),
          ),
          Positioned(
            left: 12.w,
            top: 2,
            child: _buildSingleJoinAvatar(
              profileUrl: profileUrls[1],
              size: circleSize.w,
              isDarkMode: isDarkMode,
              context: context,
              hasBorder: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleJoinAvatar({
    required String? profileUrl,
    required double size,
    required bool isDarkMode,
    required BuildContext context,
    bool hasBorder = false,
  }) {
    final bytes = profileUrl != null ? getProfileImage(profileUrl) : null;
    final resolved = resolveProfileImageUrl(profileUrl);
    final ImageProvider? imageProvider = bytes != null
        ? MemoryImage(bytes)
        : (resolved != null && resolved.startsWith('http')
              ? NetworkImage(resolved)
              : (resolved != null && resolved.startsWith('assets/')
                    ? AssetImage(resolved)
                    : null));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDarkMode
            ? const Color(0xFF252525)
            : Theme.of(context).primaryColor.withOpacity(0.08),
        border: hasBorder
            ? Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              )
            : null,
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : DecorationImage(
                image: AssetImage(Assets.images.icAvatar.path),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildJoinRequestsTile({
    required BuildContext context,
    required AppTextColors txt,
    required bool isDarkMode,
  }) {
    final count = _joinRequests.length;
    final subtitle = count == 1
        ? '1 person waiting for approval'
        : '$count people waiting for approval';

    return InkWell(
      onTap: () async {
        await navigationPush(
          context,
          GroupJoinRequestList(
            chatId: widget.chatId,
            initialRequests: _joinRequests,
          ),
        );
        if (mounted) {
          _fetchJoinRequests();
          _fetchGroupInfo();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          _buildJoinRequestsAvatarStack(
            context: context,
            isDarkMode: isDarkMode,
          ),
          SizedBox(width: 5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Join Requests',
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.title,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyText.copyWith(
                    color: txt.muted,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: txt.muted, size: 24.sp),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final members = _displayMembers;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: const CommonAppBar(title: 'Group Members'),
      body: _isLoading && _groupData == null
          ? Center(child: Loader(color: Theme.of(context).colorScheme.primary))
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Column(
                children: [
                  Container(
                    height: 43,
                    margin: EdgeInsets.only(top: 5.h),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? const Color(0xFF1F1F23)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: TextField(
                      controller: _searchController,
                      cursorColor: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.8),
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(
                          right: 12.w,
                          left: 12.w,
                          top: 10.h,
                        ),
                        hintText:
                            AppLocalizations.of(context)?.searchusers ??
                            'Search users',
                        hintStyle: CustomTextStyles.lblPrimaryHintText(context),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          FeatherIcons.search,
                          size: 17.spMax,
                          color: const Color(0XFF898989),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                            width: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      style: AppTextStyles.bodyText.copyWith(
                        color: txt.title,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_isCurrentUserAdmin &&
                      _joinRequests.isNotEmpty &&
                      _searchController.text.trim().isEmpty) ...[
                    SizedBox(height: 12.h),
                    _buildJoinRequestsTile(
                      context: context,
                      txt: txt,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                  SizedBox(height: 15.h),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await Future.wait([
                          _fetchGroupInfo(),
                          _fetchJoinRequests(),
                        ]);
                      },
                      color: Theme.of(context).colorScheme.primary,
                      child: members.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Text(
                                  'No members found',
                                  style: AppTextStyles.bodyText.copyWith(
                                    color: txt.muted,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),

                              itemCount: members.length,
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final username = member['username'] as String;
                                final name = member['name'] as String;
                                final profilePic =
                                    member['profile_picture_url'] as String?;
                                final isAdmin = member['is_admin'] == true;
                                final isMe = _isCurrentUser(member);

                                return Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: Row(
                                    children: [
                                      // ── Member Avatar ─────────────────────────
                                      _buildMemberAvatar(
                                        profilePic,
                                        username,
                                        isDarkMode,
                                      ),
                                      SizedBox(width: 12.w),

                                      // ── Member Details ────────────────────────
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    username,
                                                    style: AppTextStyles
                                                        .bodyText
                                                        .copyWith(
                                                          color: txt.body,
                                                          fontSize: 14.5,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (_isPolzetAi(username)) ...[
                                                  SizedBox(width: 4.w),
                                                  Image.asset(
                                                    Assets.images.icVerify.path,
                                                    height: 13,
                                                    width: 13,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              name,
                                              style: AppTextStyles.bodyText
                                                  .copyWith(
                                                    fontSize: 12.5,
                                                    color: txt.muted,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // ── Admin Badge & 3-Dots Menu ─────────────
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isAdmin) ...[
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12.w,
                                                vertical: 3.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'Admin',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (!isMe) SizedBox(width: 4.w),
                                          ],

                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              if (!isMe) {
                                                _showMemberOptions(member);
                                              }
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.all(6.w),
                                              child: Icon(
                                                Icons.more_vert,
                                                color: isMe
                                                    ? Colors.transparent
                                                    : txt.muted,
                                                size: 20.sp,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _isCurrentUserAdmin
          ? BottomAppBar(
              padding: const EdgeInsets.only(bottom: 25),
              height: 90,
              color: Theme.of(context).colorScheme.background,
              child: PrimaryButton(
                title:
                    AppLocalizations.of(context)?.addmemberstogroup ??
                    'Add Members',
                onPressed: () async {
                  final alreadyInGroup = <String>{};
                  for (final m in _rawMembers) {
                    final parsed = _parseMember(m);
                    final uuid = parsed['uuid']?.toString() ?? '';
                    final username = parsed['username']?.toString() ?? '';
                    if (uuid.isNotEmpty) alreadyInGroup.add(uuid);
                    if (username.isNotEmpty) {
                      alreadyInGroup.add(username.toLowerCase());
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
                isLoading: false,
              ),
            )
          : null,
    );
  }
}
