// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import '../../../api/api_config.dart';
import '../../../api/api_service.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../languages/l10n/generated/app_localizations.dart';
import '../../../mixin/utility_mixins.dart';
import '../../../provider/user_provider.dart';
import '../../../screens/home/message/chat/private/private_chat_screen.dart';
import '../../../widgets/base64/image_convert.dart';
import '../../../widgets/loader.dart';

class NewChatBottomSheet extends StatefulWidget {
  const NewChatBottomSheet({super.key});

  @override
  State<NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<NewChatBottomSheet>
    with UtilityMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final Set<String> _seenUserIds = {};

  bool _isLoading = false;
  int _chasePage = 1;
  int _rechasePage = 1;
  bool _chaseHasMore = true;
  bool _rechaseHasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchUsers(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        (_chaseHasMore || _rechaseHasMore)) {
      _fetchUsers();
    }
  }

  Future<void> _fetchUsers({bool isRefresh = false}) async {
    if (_isLoading) return;
    if (isRefresh) {
      _chasePage = 1;
      _rechasePage = 1;
      _chaseHasMore = true;
      _rechaseHasMore = true;
    } else {
      if (!_chaseHasMore && !_rechaseHasMore) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final myUserId = userProvider.userId ?? '';

      final futures = <Future<Map<String, dynamic>?>>[];

      if (_chaseHasMore) {
        futures.add(
          _apiService.fetchChaseList(targetUserId: myUserId, page: _chasePage),
        );
      } else {
        futures.add(Future.value(null));
      }

      if (_rechaseHasMore) {
        futures.add(
          _apiService.fetchRechaseList(
            targetUserId: myUserId,
            page: _rechasePage,
          ),
        );
      } else {
        futures.add(Future.value(null));
      }

      final results = await Future.wait(futures);
      final chaseResponse = results[0];
      final rechaseResponse = results[1];

      if (!mounted) return;

      final newUsers = <Map<String, dynamic>>[];

      void processItems(Map<String, dynamic>? response) {
        if (response != null) {
          final List<dynamic> rawList = response['results'] ?? [];
          for (final e in rawList) {
            final userId =
                e['id']?.toString() ?? e['user_id']?.toString() ?? '';
            if (userId.isNotEmpty && !_seenUserIds.contains(userId)) {
              _seenUserIds.add(userId);
              final rawStatus = e['follow_status'] ?? e['followStatus'];
              final followStatus = rawStatus != null
                  ? rawStatus.toString().toLowerCase()
                  : 'none';

              newUsers.add({
                'user_id': userId,
                'username': e['username'] ?? '',
                'first_name': e['first_name'] ?? '',
                'last_name': e['last_name'] ?? '',
                'avatar_url': e['profile_picture_url'] ?? e['avatar_url'],
                'is_online': false,
                'follow_status': followStatus,
                'is_private': e['is_private'] == true,
              });
            }
          }
        }
      }

      if (isRefresh) {
        _allUsers.clear();
        _seenUserIds.clear();
      }

      processItems(chaseResponse);
      processItems(rechaseResponse);

      setState(() {
        _allUsers.addAll(newUsers);

        if (chaseResponse != null) {
          _chaseHasMore = chaseResponse['next'] != null;
          if (_chaseHasMore) _chasePage++;
        }
        if (rechaseResponse != null) {
          _rechaseHasMore = rechaseResponse['next'] != null;
          if (_rechaseHasMore) _rechasePage++;
        }

        _filterUsers(_searchController.text);
      });
    } catch (e) {
      debugPrint('Error fetching users in NewChatBottomSheet: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();

      if (_searchQuery.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        _filteredUsers = _allUsers.where((user) {
          final username = (user['username'] as String?)?.toLowerCase() ?? '';
          final firstName =
              (user['first_name'] as String?)?.toLowerCase() ?? '';
          final lastName = (user['last_name'] as String?)?.toLowerCase() ?? '';
          final fullName = '$firstName $lastName'.trim();

          return username.contains(_searchQuery) ||
              firstName.contains(_searchQuery) ||
              lastName.contains(_searchQuery) ||
              fullName.contains(_searchQuery);
        }).toList();
      }
    });
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);

    final profilePic = user['avatar_url'] as String?;
    final firstName = user['first_name'] ?? '';
    final lastName = user['last_name'] ?? '';
    final username = user['username'] as String? ?? '';
    final firstLetter = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final userId = user['user_id']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(context);
        navigationPush(
          context,
          PrivateChatScreen(
            userId: userId,
            memberName: fullName.isNotEmpty ? fullName : username,
            username: username,
            profileUrl: profilePic,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              height: 40.h,
              width: 40.w,
              margin: EdgeInsets.only(right: 10.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.7,
                ),
                color: isDarkMode
                    ? const Color(0xFF252525)
                    : Theme.of(context).primaryColor.withOpacity(0.08),
              ),
              child: ClipOval(
                child: (() {
                  if (profilePic != null && profilePic.isNotEmpty) {
                    final bytes = getProfileImage(profilePic);
                    if (bytes != null) {
                      return Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            firstLetter,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.8),
                            ),
                          ),
                        ),
                      );
                    }
                    final imageUrl = profilePic.startsWith('http')
                        ? profilePic
                        : (profilePic.startsWith('/')
                              ? '${ApiConfig.baseUrlImage}$profilePic'
                              : '${ApiConfig.baseUrlImage}/$profilePic');
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          firstLetter,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.8),
                          ),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Text(
                      firstLetter,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                  );
                })(),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                   style: AppTextStyles.bodyText.copyWith(
                          color: txt.body,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (fullName.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      fullName,
                       style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12.5,
                            color: txt.muted,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              height: 30.h,
              width: 80.w,
              margin: EdgeInsets.only(left: 5.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Center(
                child: Text(
                 AppLocalizations.of(context)!.message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 0.8.sh,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Text(
              AppLocalizations.of(context)!.newchat,
                style: AppTextStyles.sectionHeading.copyWith(color: txt.title),
              ),
              const SizedBox(height: 8),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
                indent: 12,
                endIndent: 12,
                height: 1,
              ),
              // Search input
              Container(
                height: 43.h,
                width: double.infinity,
                margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1F1F23) : Colors.white,
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
                    hintText: l10n?.searchusers ?? 'Search users',
                    hintStyle: AppTextStyles.bodyText.copyWith(
                      color: const Color(0XFF898989),
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      FeatherIcons.search,
                      size: 17.spMax,
                      color: const Color(0XFF898989),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
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
                  onChanged: _filterUsers,
                ),
              ),
              // User List
              Expanded(
                child: _isLoading && _allUsers.isEmpty
                    ? Center(
                        child: Loader(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? (l10n?.nousersfound ?? 'No users found')
                              : (l10n?.nousersfound ?? 'No users found'),
                          style: AppTextStyles.bodyText.copyWith(
                            color: txt.muted,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchUsers(isRefresh: true),
                        color: Theme.of(context).colorScheme.primary,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount:
                              _filteredUsers.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredUsers.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                child: Center(
                                  child: Loader(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              );
                            }
                            return _buildUserListItem(_filteredUsers[index]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
